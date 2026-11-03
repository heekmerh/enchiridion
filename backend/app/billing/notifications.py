"""Queued billing and offer emails; delivery is retried from the outbox rather than blocking payment handling."""

import html
import logging
import os
from datetime import datetime

from psycopg.types.json import Jsonb

from .. import mailer
from . import catalog, copy

logger = logging.getLogger(__name__)

MAX_ATTEMPTS = 5
FEEDBACK_DIGEST_KIND = "feedback_digest"
FEEDBACK_CATEGORY_LABELS = {"complaint": "Complaint", "feature_request": "Feature request", "other": "Other"}
MARKETING_KINDS = frozenset({"premium_offer"})
TRANSACTIONAL_SUBJECTS = {
    "purchase_verified": ("Your Enchiridion Premium subscription is active", copy.PURCHASE_VERIFIED),
    "renewal_verified": ("Your Enchiridion Premium subscription has renewed", copy.RENEWAL_VERIFIED),
    "payment_failed": ("We couldn't complete your Enchiridion payment", copy.PAYMENT_FAILED),
    "cancellation": ("Your Enchiridion subscription won't renew", copy.CANCELLATION),
    "expiry": ("Your Enchiridion Premium subscription has expired", copy.EXPIRY),
}


async def enqueue(db, *, user_id, kind: str, dedupe_key: str, payload: dict | None = None):
    await db.execute(
        """INSERT INTO email_outbox(user_id, kind, recipient, dedupe_key, payload)
           SELECT u.id, %s, lower(u.email), %s, %s FROM auth.users u WHERE u.id = %s AND u.email IS NOT NULL
           ON CONFLICT (dedupe_key) DO NOTHING""",
        (kind, dedupe_key, Jsonb(payload or {}), user_id),
    )


async def enqueue_for_subscription(db, subscription: dict, kind: str, dedupe_suffix: str):
    if not subscription.get("user_id"):
        return
    access_until = subscription.get("access_expires_at")
    await enqueue(db, user_id=subscription["user_id"], kind=kind,
                  dedupe_key=f"{kind}:{subscription['id']}:{dedupe_suffix}",
                  payload={"provider": subscription["provider"], "plan_id": subscription["plan_id"],
                           "access_until": access_until.isoformat() if isinstance(access_until, datetime) else None})


def paragraph(text: str) -> str:
    return f"<p>{html.escape(text)}</p>"


def button(label: str, url: str) -> str:
    return (f'<p><a href="{html.escape(url)}" style="background:#d1282f;color:#fff;padding:12px 20px;'
            f'border-radius:8px;text-decoration:none;font-weight:600">{html.escape(label)}</a></p>')


def unsubscribe_url(token) -> str:
    return f"{mailer.frontend_url()}/unsubscribe?token={token}"


async def render_offer(db, row: dict) -> tuple[str, str, dict]:
    plans = catalog.serialize_plans(await catalog.active_plans(db))
    lines = []
    for plan in plans:
        label = "Monthly" if plan["interval"] == "month" else "Annual"
        detail = "Flexible monthly billing." if plan["interval"] == "month" else plan["description"]
        lines.append(f"<p><strong>{label}: {html.escape(plan['price']['display'])}</strong> — {html.escape(detail)}</p>")
    link = unsubscribe_url(row["unsubscribe_token"])
    body = "".join([
        paragraph("Welcome aboard!"),
        paragraph("Your Enchiridion account is verified and ready to use. "
                  "You can get started with your free account or explore Premium."),
        *lines,
        paragraph("Both plans include the same Premium access. Applicable taxes and Enchiridion's "
                  "payment-processing charges are already included in the displayed price."),
        button("Explore Subscription Plans", mailer.frontend_url() + "/premium"),
        paragraph("You can manage your website subscription and cancel future renewals from your account. "
                  "Already subscribed? Sign in to access your benefits."),
        paragraph("The Enchiridion Team"),
        f'<p style="font-size:12px;color:#64748b">You received this because you asked for Enchiridion offers. '
        f'<a href="{html.escape(link)}">Unsubscribe</a>.</p>',
    ])
    return "Your Enchiridion account is ready. Explore Premium.", body, {"List-Unsubscribe": f"<{link}>"}


def render_transactional(row: dict) -> tuple[str, str, dict]:
    subject, message = TRANSACTIONAL_SUBJECTS[row["kind"]]
    payload = row["payload"] or {}
    parts = [paragraph("Hello,"), paragraph(message)]
    access_until = payload.get("access_until")
    if access_until and row["kind"] in ("purchase_verified", "renewal_verified", "cancellation"):
        parts.append(paragraph(f"Premium access is paid through {datetime.fromisoformat(access_until):%d %B %Y}."))
    if payload.get("provider") == "google_play":
        parts.append(paragraph(copy.GOOGLE_PLAY_MANAGEMENT))
    else:
        parts.append(button("Manage subscription", mailer.frontend_url() + "/account/subscription"))
    parts.append(paragraph("The Enchiridion Team"))
    return subject, "".join(parts), {}


def admin_email() -> str:
    return (os.getenv("ADMIN_EMAIL") or os.getenv("MAIL_FROM") or os.getenv("MAIL_USERNAME") or "").strip().lower()


async def enqueue_feedback_digest(db) -> bool:
    recipient = admin_email()
    if not recipient:
        logger.warning("Feedback digest skipped: no admin email is configured")
        return False
    # Vercel can deliver a cron event twice, so concurrent runs must not queue two digests.
    await db.execute("SELECT pg_advisory_xact_lock(hashtext(%s))", (FEEDBACK_DIGEST_KIND,))
    window = await (await db.execute(
        """SELECT (SELECT max((payload->>'through')::timestamptz) FROM email_outbox
                   WHERE kind = %s AND status = 'sent') AS since,
                  -- A message still committing at now() would otherwise fall behind the next digest's start.
                  now() - interval '1 minute' AS through""",
        (FEEDBACK_DIGEST_KIND,),
    )).fetchone()
    since, through = window["since"], window["through"]
    waiting = await (await db.execute(
        """SELECT count(*) AS total FROM public.app_feedback
           WHERE created_at <= %s AND (%s::timestamptz IS NULL OR created_at > %s::timestamptz)""",
        (through, since, since),
    )).fetchone()
    if not waiting["total"]:
        return False
    payload = Jsonb({"since": since.isoformat() if since else None, "through": through.isoformat()})
    # An undelivered digest grows to cover the new window, so a mail outage cannot drop or split messages.
    updated = await db.execute(
        """UPDATE email_outbox SET payload = %s, recipient = %s, attempts = 0
           WHERE kind = %s AND status = 'pending'""",
        (payload, recipient, FEEDBACK_DIGEST_KIND),
    )
    if not updated.rowcount:
        await db.execute(
            "INSERT INTO email_outbox(kind, recipient, dedupe_key, payload) VALUES (%s, %s, %s, %s)",
            (FEEDBACK_DIGEST_KIND, recipient, f"{FEEDBACK_DIGEST_KIND}:{through.isoformat()}", payload),
        )
    return True


async def render_feedback_digest(db, row: dict) -> tuple[str, str, dict] | None:
    since, through = row["payload"].get("since"), row["payload"]["through"]
    messages = await (await db.execute(
        """SELECT f.category, f.message, f.platform, coalesce(u.email, 'no email on account') AS email,
                  to_char(f.created_at AT TIME ZONE 'Africa/Lagos', 'DD Mon YYYY, HH24:MI') AS sent_at
           FROM public.app_feedback f JOIN auth.users u ON u.id = f.user_id
           WHERE f.created_at <= %s::timestamptz AND (%s::timestamptz IS NULL OR f.created_at > %s::timestamptz)
           ORDER BY f.created_at""",
        (through, since, since),
    )).fetchall()
    if not messages:
        return None
    noun = "message" if len(messages) == 1 else "messages"
    parts = [paragraph(f"{len(messages)} new feedback {noun} from Enchiridion users.")]
    for item in messages:
        label = FEEDBACK_CATEGORY_LABELS.get(item["category"], item["category"])
        details = " · ".join(filter(None, [f"{item['sent_at']} WAT", item["email"], item["platform"]]))
        text = html.escape(item["message"]).replace("\n", "<br>")
        parts.append(f"<hr><p><strong>{html.escape(label)}</strong><br>"
                     f'<span style="font-size:12px;color:#64748b">{html.escape(details)}</span></p><p>{text}</p>')
    return f"Enchiridion feedback: {len(messages)} new {noun}", "".join(parts), {}


async def skip(db, row_id, reason: str):
    await db.execute("UPDATE email_outbox SET status = 'skipped', last_error = %s WHERE id = %s", (reason, row_id))


async def dispatch(db, *, user_id=None, kind: str | None = None, limit: int = 25) -> dict:
    counts = {"sent": 0, "skipped": 0, "failed": 0}
    if not mailer.is_configured():
        return counts
    rows = await (await db.execute(
        """SELECT o.*, c.marketing_opt_in, c.marketing_unsubscribed_at, c.transactional_email_enabled,
                  c.unsubscribe_token
           FROM email_outbox o LEFT JOIN public.communication_preferences c ON c.user_id = o.user_id
           WHERE o.status = 'pending' AND (%s::uuid IS NULL OR o.user_id = %s::uuid)
             AND (%s::text IS NULL OR o.kind = %s::text)
           ORDER BY o.created_at LIMIT %s
           FOR UPDATE OF o SKIP LOCKED""",
        (user_id, user_id, kind, kind, limit),
    )).fetchall()
    for row in rows:
        if row["kind"] in MARKETING_KINDS:
            if not row["marketing_opt_in"] or row["marketing_unsubscribed_at"] is not None:
                await skip(db, row["id"], "No current marketing consent")
                counts["skipped"] += 1
                continue
            premium = await (await db.execute("SELECT billing.has_entitlement(%s) AS premium", (row["user_id"],))).fetchone()
            if premium["premium"]:
                await skip(db, row["id"], "Already Premium")
                counts["skipped"] += 1
                continue
            subject, body, headers = await render_offer(db, row)
        elif row["kind"] in TRANSACTIONAL_SUBJECTS:
            if row["transactional_email_enabled"] is False:
                await skip(db, row["id"], "Transactional email disabled")
                counts["skipped"] += 1
                continue
            subject, body, headers = render_transactional(row)
        elif row["kind"] == FEEDBACK_DIGEST_KIND:
            rendered = await render_feedback_digest(db, row)
            if rendered is None:
                await skip(db, row["id"], "No feedback left to report")
                counts["skipped"] += 1
                continue
            subject, body, headers = rendered
        else:
            await skip(db, row["id"], "Unknown email kind")
            counts["skipped"] += 1
            continue
        if await mailer.send_email(row["recipient"], subject, body, headers):
            await db.execute("UPDATE email_outbox SET status = 'sent', sent_at = now(), attempts = attempts + 1 WHERE id = %s",
                             (row["id"],))
            counts["sent"] += 1
        else:
            await db.execute(
                """UPDATE email_outbox SET attempts = attempts + 1, last_error = 'Delivery failed',
                          status = CASE WHEN attempts + 1 >= %s THEN 'failed' ELSE 'pending' END
                   WHERE id = %s""",
                (MAX_ATTEMPTS, row["id"]),
            )
            counts["failed"] += 1
    return counts
