"""Scheduled reconciliation: missed webhooks, lapsed periods, unacknowledged purchases and queued email."""

import logging
from functools import partial

from fastapi import HTTPException

from .. import flutterwave
from . import events, flutterwave_billing, google_play, lifecycle, notifications

logger = logging.getLogger(__name__)

BATCH_SIZE = 25
# Flutterwave retries a failed renewal for a short while before cancelling; allow that before ending access for good.
RENEWAL_CONFIRMATION_GRACE = "3 days"


async def isolated(db, label: str, operation) -> bool:
    try:
        async with db.transaction():
            await operation()
        return True
    except Exception as exc:
        detail = exc.detail if isinstance(exc, HTTPException) else type(exc).__name__
        logger.warning("Reconciliation step %s failed: %s", label, detail)
        return False


async def reconcile_pending_checkouts(db) -> dict:
    counts = {"checked": 0, "abandoned": 0}
    rows = await (await db.execute(
        """SELECT reference, expires_at < now() AS expired FROM billing.checkout_sessions
           WHERE status = 'pending' AND created_at < now() - interval '10 minutes'
           ORDER BY created_at LIMIT %s FOR UPDATE SKIP LOCKED""",
        (BATCH_SIZE,),
    )).fetchall()
    for row in rows:
        async def reconcile(reference=row["reference"], expired=row["expired"]):
            tx = await flutterwave.fetch_transaction_by_reference(reference)
            if tx:
                await flutterwave_billing.apply_transaction(db, tx, "reconciliation")
            elif expired:
                await db.execute("UPDATE billing.checkout_sessions SET status = 'abandoned' WHERE reference = %s", (reference,))
                counts["abandoned"] += 1
        if await isolated(db, f"checkout {row['reference']}", reconcile):
            counts["checked"] += 1
    return counts


async def retry_failed_events(db) -> dict:
    counts = {"retried": 0}
    rows = await (await db.execute(
        """SELECT * FROM billing.payment_events
           WHERE authentication = 'verified' AND processing_status IN ('received', 'failed')
             AND attempts < %s AND received_at < now() - interval '5 minutes'
           ORDER BY received_at LIMIT %s FOR UPDATE SKIP LOCKED""",
        (events.MAX_ATTEMPTS, BATCH_SIZE),
    )).fetchall()
    for event in rows:
        payload = event["payload"]
        if event["provider"] == "flutterwave":
            data = payload.get("data") if isinstance(payload.get("data"), dict) else {}
            handler = partial(flutterwave_billing.dispatch_event, db, event["event_type"], data, "reconciliation")
        else:
            handler = partial(google_play.process_notification, db, payload, "reconciliation")
        await events.process(db, event, handler)
        counts["retried"] += 1
    return counts


async def refresh_google_subscriptions(db) -> dict:
    counts = {"refreshed": 0}
    rows = await (await db.execute(
        """SELECT provider_reference FROM billing.subscriptions
           WHERE provider = 'google_play' AND superseded_by IS NULL
             AND ((internal_state NOT IN ('EXPIRED', 'REFUNDED')
                   AND (access_expires_at IS NULL OR access_expires_at < now() + interval '1 day'))
                  OR (acknowledged_at IS NULL AND user_id IS NOT NULL AND internal_state IN ('ACTIVE', 'GRACE_PERIOD')))
           ORDER BY updated_at LIMIT %s FOR UPDATE SKIP LOCKED""",
        (BATCH_SIZE,),
    )).fetchall()
    for row in rows:
        refresh = partial(google_play.sync_purchase, db, row["provider_reference"], actor="reconciliation")
        if await isolated(db, "google refresh", refresh):
            counts["refreshed"] += 1
    return counts


async def expire_lapsed_flutterwave(db) -> dict:
    await lifecycle.set_transition_context(db, "Paid period ended without a verified renewal", "reconciliation")
    rows = await (await db.execute(
        f"""UPDATE billing.subscriptions SET internal_state = 'EXPIRED', auto_renewing = false,
                   ended_at = now(), updated_at = now()
            WHERE provider = 'flutterwave' AND superseded_by IS NULL
              AND ((internal_state IN ('CANCELLED') AND access_expires_at < now())
                   OR (internal_state IN ('ACTIVE', 'GRACE_PERIOD') AND NOT auto_renewing AND access_expires_at < now())
                   OR (internal_state IN ('ACTIVE', 'GRACE_PERIOD', 'PAYMENT_FAILED')
                       AND access_expires_at < now() - interval '{RENEWAL_CONFIRMATION_GRACE}'))
            RETURNING *""",
    )).fetchall()
    for subscription in rows:
        await notifications.enqueue_for_subscription(db, subscription, "expiry", subscription["access_expires_at"].isoformat())
    return {"expired": len(rows)}


async def run_all(db) -> dict:
    return {
        "checkouts": await reconcile_pending_checkouts(db),
        "events": await retry_failed_events(db),
        "google": await refresh_google_subscriptions(db),
        "flutterwave": await expire_lapsed_flutterwave(db),
        "emails": await notifications.dispatch(db, limit=50),
    }
