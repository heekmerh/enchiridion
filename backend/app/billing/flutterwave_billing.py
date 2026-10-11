"""Website subscriptions through Flutterwave hosted checkout and payment plans."""

import logging
import uuid
from decimal import Decimal

from fastapi import HTTPException
from psycopg.types.json import Jsonb

from .. import flutterwave, mailer
from ..rewards import process_payment
from . import catalog, events, lifecycle, notifications

logger = logging.getLogger(__name__)

PROVIDER = "flutterwave"
CHECKOUT_PREFIX = "ENCH-SUB-"
FLUTTERWAVE_INTERVALS = {"month": "monthly", "year": "yearly"}
AUTO_RENEW_PAYMENT_OPTIONS = "card"
MANUAL_PAYMENT_OPTIONS = "card,banktransfer,ussd"
RECORDED_TRANSACTION_FIELDS = ("tx_ref", "flw_ref", "status", "amount", "charged_amount", "app_fee", "merchant_fee",
                               "amount_settled", "currency", "payment_type", "payment_plan", "created_at")


def provider_amount(amount: Decimal):
    return int(amount) if amount == amount.to_integral_value() else float(amount)


def transaction_details(tx: dict) -> dict:
    details = {key: tx.get(key) for key in RECORDED_TRANSACTION_FIELDS if tx.get(key) is not None}
    details["customer_email"] = customer_email(tx)
    charged = tx.get("charged_amount")
    if charged is not None and lifecycle.to_decimal(charged) > lifecycle.to_decimal(tx.get("amount")):
        details["customer_charged_fees"] = True
        logger.warning("Flutterwave charged fees to the customer on %s; set fees to be merchant-borne", tx.get("id"))
    return details


def customer_email(tx: dict) -> str:
    return str((tx.get("customer") or {}).get("email") or "").strip().lower()


async def ensure_payment_plan(db, plan: dict) -> str:
    await db.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s, 7))", (f"flutterwave-plan:{plan['price_id']}",))
    mapping = await (await db.execute(
        """SELECT provider_plan_id FROM billing.provider_plan_mappings
           WHERE provider = 'flutterwave' AND plan_price_id = %s AND is_active""",
        (plan["price_id"],),
    )).fetchone()
    if mapping:
        return mapping["provider_plan_id"]
    payload = await flutterwave.call("POST", "/payment-plans", json={
        "amount": provider_amount(plan["amount"]),
        "name": f"Enchiridion {plan['name']} ({catalog.format_amount(plan['amount'], plan['currency'])})",
        "interval": FLUTTERWAVE_INTERVALS[plan["billing_interval"]],
        "currency": plan["currency"],
    })
    provider_plan_id = str(payload["data"]["id"])
    await db.execute(
        """INSERT INTO billing.provider_plan_mappings(plan_id, provider, provider_plan_id, plan_price_id)
           VALUES (%s, 'flutterwave', %s, %s)""",
        (plan["id"], provider_plan_id, plan["price_id"]),
    )
    return provider_plan_id


async def create_checkout(db, user, plan_id: str, auto_renew: bool) -> dict:
    if not user.is_verified:
        raise HTTPException(403, "Verify your email address before subscribing.")
    plan = await catalog.plan_or_404(db, plan_id)
    await lifecycle.lock_user_billing(db, user.id)
    await lifecycle.assert_can_purchase(db, user.id)
    reference = CHECKOUT_PREFIX + uuid.uuid4().hex
    provider_plan_id = await ensure_payment_plan(db, plan) if auto_renew else None
    await db.execute(
        """INSERT INTO billing.checkout_sessions(reference, user_id, plan_id, plan_price_id, amount, currency,
                                                 customer_email, auto_renew, provider_plan_id)
           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)""",
        (reference, user.id, plan["id"], plan["price_id"], plan["amount"], plan["currency"], user.email,
         auto_renew, provider_plan_id),
    )
    request = {
        "tx_ref": reference,
        "amount": provider_amount(plan["amount"]),
        "currency": plan["currency"],
        "redirect_url": f"{mailer.frontend_url()}/premium/processing?reference={reference}",
        "payment_options": AUTO_RENEW_PAYMENT_OPTIONS if auto_renew else MANUAL_PAYMENT_OPTIONS,
        "customer": {"email": user.email, "name": user.name or user.email},
        "customizations": {"title": "Enchiridion Premium", "description": plan["name"]},
        "meta": {"user_id": str(user.id), "plan_id": plan["id"], "checkout_reference": reference},
    }
    if provider_plan_id:
        request["payment_plan"] = provider_plan_id
    payload = await flutterwave.call("POST", "/payments", json=request)
    checkout_url = (payload.get("data") or {}).get("link")
    if not checkout_url:
        raise HTTPException(502, "Flutterwave did not return a checkout link")
    await db.execute("UPDATE billing.checkout_sessions SET checkout_url = %s WHERE reference = %s", (checkout_url, reference))
    return {"reference": reference, "checkout_url": checkout_url, "amount": float(plan["amount"]),
            "currency": plan["currency"], "auto_renew": auto_renew}


async def payment_for_transaction(db, transaction_id: str) -> dict | None:
    return await (await db.execute(
        "SELECT * FROM billing.payments WHERE provider = 'flutterwave' AND provider_transaction_id = %s",
        (transaction_id,),
    )).fetchone()


async def insert_payment(db, *, subscription, user_id, tx: dict, kind: str, status: str,
                         checkout_reference=None, period_start=None, period_end=None, extra: dict | None = None) -> dict:
    transaction_id = str(tx["id"])
    details = {**transaction_details(tx), **(extra or {})}
    return await (await db.execute(
        """INSERT INTO billing.payments(subscription_id, user_id, provider, reference, provider_transaction_id,
                                        checkout_reference, kind, amount, currency, verification_status, verified_at,
                                        period_start, period_end, provider_details)
           VALUES (%s, %s, 'flutterwave', %s, %s, %s, %s, %s, %s, %s,
                   CASE WHEN %s = 'verified' THEN now() END, %s, %s, %s)
           ON CONFLICT (provider, reference) DO NOTHING
           RETURNING *""",
        (subscription["id"] if subscription else None, user_id, transaction_id, transaction_id, checkout_reference,
         kind, lifecycle.to_decimal(tx.get("amount")), str(tx.get("currency") or ""), status, status,
         period_start, period_end, Jsonb(details)),
    )).fetchone()


async def record_verified_settlement(db, payment: dict, tx: dict):
    fee = tx.get("app_fee")
    await lifecycle.record_settlement_estimate(
        db, payment["id"], PROVIDER, payment["amount"], payment["currency"],
        provider_fee=lifecycle.to_decimal(fee) if fee is not None else None,
        notes=f"Flutterwave amount_settled={tx.get('amount_settled')}",
    )


def mismatch_reason(tx: dict, amount: Decimal, currency: str) -> str | None:
    if str(tx.get("currency") or "") != currency:
        return "Currency does not match the checkout"
    if lifecycle.to_decimal(tx.get("amount")) != amount:
        return "Amount does not match the checkout"
    return None


async def apply_checkout_payment(db, checkout: dict, tx: dict, actor: str) -> dict:
    transaction_id = str(tx["id"])
    if await payment_for_transaction(db, transaction_id):
        return {"status": "already_processed", "reference": checkout["reference"]}
    if tx.get("status") != "successful":
        if checkout["status"] == "pending" and tx.get("status") == "failed":
            await db.execute("UPDATE billing.checkout_sessions SET status = 'failed', failure_reason = %s WHERE reference = %s",
                             ("Payment failed at Flutterwave", checkout["reference"]))
        return {"status": "not_successful", "reference": checkout["reference"]}
    reason = mismatch_reason(tx, checkout["amount"], checkout["currency"])
    if reason:
        await db.execute("UPDATE billing.checkout_sessions SET status = 'failed', failure_reason = %s WHERE reference = %s",
                         (reason, checkout["reference"]))
        await insert_payment(db, subscription=None, user_id=checkout["user_id"], tx=tx, kind="initial", status="failed",
                             checkout_reference=checkout["reference"], extra={"rejection": reason})
        logger.warning("Rejected Flutterwave transaction %s: %s", transaction_id, reason)
        return {"status": "rejected", "reason": reason}

    await lifecycle.lock_user_billing(db, checkout["user_id"])
    plan = await (await db.execute("SELECT billing_interval, interval_count FROM billing.plans WHERE id = %s",
                                   (checkout["plan_id"],))).fetchone()
    start, overlapping = await lifecycle.next_period_start(db, checkout["user_id"])
    end = lifecycle.add_billing_interval(start, plan["billing_interval"], plan["interval_count"])
    await lifecycle.set_transition_context(db, "Flutterwave payment verified", actor)
    subscription = await (await db.execute(
        """INSERT INTO billing.subscriptions(user_id, plan_id, provider, provider_reference, provider_plan_id,
                                             provider_state, internal_state, auto_renewing, customer_email,
                                             current_period_start, current_period_end, access_expires_at, metadata)
           VALUES (%s, %s, 'flutterwave', %s, %s, 'successful', 'ACTIVE', %s, %s, %s, %s, %s, %s)
           ON CONFLICT (provider, provider_reference) DO NOTHING
           RETURNING *""",
        (checkout["user_id"], checkout["plan_id"], checkout["reference"], checkout["provider_plan_id"],
         checkout["auto_renew"], customer_email(tx) or checkout["customer_email"], start, end, end,
         Jsonb({"overlapping_purchase": overlapping})),
    )).fetchone()
    if not subscription:
        existing = await (await db.execute(
            "SELECT * FROM billing.subscriptions WHERE provider = 'flutterwave' AND provider_reference = %s",
            (checkout["reference"],),
        )).fetchone()
        await insert_payment(db, subscription=existing, user_id=checkout["user_id"], tx=tx, kind="initial",
                             status="verified", checkout_reference=checkout["reference"],
                             extra={"duplicate_charge": True})
        logger.warning("Duplicate Flutterwave charge %s for checkout %s needs a refund review", transaction_id, checkout["reference"])
        return {"status": "duplicate_charge", "reference": checkout["reference"]}
    if overlapping:
        logger.warning("Overlapping purchase recorded for user %s on %s", checkout["user_id"], checkout["reference"])
    payment = await insert_payment(db, subscription=subscription, user_id=checkout["user_id"], tx=tx, kind="initial",
                                   status="verified", checkout_reference=checkout["reference"],
                                   period_start=start, period_end=end)
    await record_verified_settlement(db, payment, tx)
    await db.execute("UPDATE billing.checkout_sessions SET status = 'paid', completed_at = now() WHERE reference = %s",
                     (checkout["reference"],))
    await notifications.enqueue_for_subscription(db, subscription, "purchase_verified", transaction_id)
    return {"status": "granted", "reference": checkout["reference"], "subscription_id": str(subscription["id"])}


async def find_subscription_for_charge(db, tx: dict) -> dict | None:
    checkout_reference = (tx.get("meta") or {}).get("checkout_reference") if isinstance(tx.get("meta"), dict) else None
    if checkout_reference:
        row = await (await db.execute(
            "SELECT * FROM billing.subscriptions WHERE provider = 'flutterwave' AND provider_reference = %s FOR UPDATE",
            (checkout_reference,),
        )).fetchone()
        if row:
            return row
    plan_id, email = tx.get("payment_plan"), customer_email(tx)
    if not plan_id or not email:
        return None
    return await (await db.execute(
        """SELECT * FROM billing.subscriptions
           WHERE provider = 'flutterwave' AND provider_plan_id = %s AND lower(customer_email) = %s
             AND superseded_by IS NULL
           ORDER BY created_at DESC LIMIT 1 FOR UPDATE""",
        (str(plan_id), email),
    )).fetchone()


async def apply_renewal_payment(db, tx: dict, actor: str) -> dict:
    transaction_id = str(tx["id"])
    if await payment_for_transaction(db, transaction_id):
        return {"status": "already_processed"}
    subscription = await find_subscription_for_charge(db, tx)
    if not subscription:
        raise events.UnmatchedEvent(f"No subscription matches Flutterwave transaction {transaction_id}")

    if tx.get("status") != "successful":
        if tx.get("status") == "failed":
            await insert_payment(db, subscription=subscription, user_id=subscription["user_id"], tx=tx, kind="renewal",
                                 status="failed")
            if subscription["internal_state"] in ("ACTIVE", "GRACE_PERIOD"):
                await lifecycle.set_transition_context(db, "Flutterwave renewal charge failed", actor)
                await db.execute(
                    "UPDATE billing.subscriptions SET internal_state = 'PAYMENT_FAILED', provider_state = 'failed', updated_at = now() WHERE id = %s",
                    (subscription["id"],),
                )
            await notifications.enqueue_for_subscription(db, subscription, "payment_failed", transaction_id)
        return {"status": "not_successful"}

    price = await (await db.execute(
        """SELECT pr.amount, pr.currency FROM billing.provider_plan_mappings m
           JOIN billing.plan_prices pr ON pr.id = m.plan_price_id
           WHERE m.provider = 'flutterwave' AND m.provider_plan_id = %s""",
        (subscription["provider_plan_id"],),
    )).fetchone()
    reason = mismatch_reason(tx, price["amount"], price["currency"]) if price else "Unknown Flutterwave payment plan"
    if reason:
        await insert_payment(db, subscription=subscription, user_id=subscription["user_id"], tx=tx, kind="renewal",
                             status="failed", extra={"rejection": reason})
        logger.warning("Rejected Flutterwave renewal %s: %s", transaction_id, reason)
        return {"status": "rejected", "reason": reason}

    plan = await (await db.execute("SELECT billing_interval, interval_count FROM billing.plans WHERE id = %s",
                                   (subscription["plan_id"],))).fetchone()
    start = max(lifecycle.utcnow(), subscription["current_period_end"] or lifecycle.utcnow())
    end = lifecycle.add_billing_interval(start, plan["billing_interval"], plan["interval_count"])
    await lifecycle.set_transition_context(db, "Flutterwave renewal verified", actor)
    updated = await (await db.execute(
        """UPDATE billing.subscriptions
           SET internal_state = 'ACTIVE', provider_state = 'successful', current_period_start = %s,
               current_period_end = %s, access_expires_at = %s, updated_at = now()
           WHERE id = %s RETURNING *""",
        (start, end, end, subscription["id"]),
    )).fetchone()
    payment = await insert_payment(db, subscription=updated, user_id=updated["user_id"], tx=tx, kind="renewal",
                                   status="verified", period_start=start, period_end=end)
    await record_verified_settlement(db, payment, tx)
    await notifications.enqueue_for_subscription(db, updated, "renewal_verified", transaction_id)
    return {"status": "renewed", "subscription_id": str(updated["id"])}


async def apply_transaction(db, tx: dict, actor: str) -> dict:
    reference = str(tx.get("tx_ref") or "")
    checkout = await (await db.execute(
        "SELECT * FROM billing.checkout_sessions WHERE reference = %s FOR UPDATE", (reference,),
    )).fetchone()
    if checkout:
        return await apply_checkout_payment(db, checkout, tx, actor)
    return await apply_renewal_payment(db, tx, actor)


async def is_book_order(db, reference: str) -> bool:
    row = await (await db.execute("SELECT 1 FROM purchase_orders WHERE tx_ref = %s", (reference,))).fetchone()
    return row is not None


async def process_charge(db, transaction_id, actor: str) -> str:
    tx = await flutterwave.fetch_transaction(transaction_id)
    if await is_book_order(db, str(tx.get("tx_ref") or "")):
        if tx.get("status") != "successful":
            return "ignored"
        await process_payment(db, tx)
        return "processed"
    result = await apply_transaction(db, tx, actor)
    return "ignored" if result["status"] in ("not_successful", "already_processed") else "processed"


def cancellation_email(data: dict) -> str:
    customer = data.get("customer")
    if isinstance(customer, dict):
        return str(customer.get("email") or "").strip().lower()
    return str(customer or "").strip().lower()


async def mark_cancelled(db, subscription: dict, actor: str, reason: str, provider_subscription_id=None) -> dict:
    await lifecycle.set_transition_context(db, reason, actor)
    updated = await (await db.execute(
        """UPDATE billing.subscriptions
           SET internal_state = CASE WHEN internal_state IN ('EXPIRED', 'REFUNDED') THEN internal_state ELSE 'CANCELLED' END,
               auto_renewing = false, provider_state = 'cancelled', cancelled_at = coalesce(cancelled_at, now()),
               provider_subscription_id = coalesce(%s, provider_subscription_id), updated_at = now()
           WHERE id = %s RETURNING *""",
        (provider_subscription_id, subscription["id"]),
    )).fetchone()
    if subscription["auto_renewing"]:
        await notifications.enqueue_for_subscription(db, updated, "cancellation", "cancelled")
    return updated


def cancellation_plan_id(data: dict) -> str | None:
    plan = data.get("plan")
    return str(plan.get("id") if isinstance(plan, dict) else plan or "") or None


async def find_cancelled_subscription(db, data: dict) -> dict | None:
    provider_subscription_id = str(data.get("id") or "") or None
    if provider_subscription_id:
        subscription = await (await db.execute(
            """SELECT * FROM billing.subscriptions
               WHERE provider = 'flutterwave' AND provider_subscription_id = %s FOR UPDATE""",
            (provider_subscription_id,),
        )).fetchone()
        if subscription:
            return subscription
    email = cancellation_email(data)
    if not email:
        return None
    plan_id = cancellation_plan_id(data)
    return await (await db.execute(
        """SELECT * FROM billing.subscriptions
           WHERE provider = 'flutterwave' AND lower(customer_email) = %s
             AND (%s::text IS NULL OR provider_plan_id = %s::text) AND superseded_by IS NULL
           ORDER BY auto_renewing DESC, created_at DESC LIMIT 1 FOR UPDATE""",
        (email, plan_id, plan_id),
    )).fetchone()


async def process_subscription_cancelled(db, data: dict, actor: str) -> str:
    subscription = await find_cancelled_subscription(db, data)
    if not subscription:
        raise events.UnmatchedEvent("No subscription matches this Flutterwave cancellation")
    await mark_cancelled(db, subscription, actor, "Cancelled at Flutterwave", str(data.get("id") or "") or None)
    return "processed"


async def flutterwave_subscription_id(subscription: dict) -> str | None:
    if subscription["provider_subscription_id"]:
        return subscription["provider_subscription_id"]
    payload = await flutterwave.call("GET", "/subscriptions", params={
        "email": subscription["customer_email"], "plan": subscription["provider_plan_id"], "status": "active",
    })
    candidates = payload.get("data") or []
    return str(candidates[0]["id"]) if candidates else None


async def cancel(db, subscription: dict, actor: str) -> dict:
    if not subscription["auto_renewing"]:
        raise HTTPException(409, "This subscription does not renew automatically.")
    provider_subscription_id = await flutterwave_subscription_id(subscription)
    if not provider_subscription_id:
        raise HTTPException(502, "We could not locate this subscription at Flutterwave. Please contact support.")
    await flutterwave.call("PUT", f"/subscriptions/{provider_subscription_id}/cancel")
    return await mark_cancelled(db, subscription, actor, "Cancelled by the customer", provider_subscription_id)


async def handle_webhook(db, payload: dict) -> tuple[int, dict]:
    event_type = str(payload.get("event") or "")
    data = payload.get("data") if isinstance(payload.get("data"), dict) else {}
    if event_type == "charge.completed" and data.get("id"):
        event_id = f"charge.completed:{data['id']}:{data.get('status', '')}"
    elif event_type == "subscription.cancelled":
        # Flutterwave's cancellation payload carries no subscription id, so the matched subscription keys the event.
        subscription = await find_cancelled_subscription(db, data)
        target = subscription["id"] if subscription else f"{cancellation_email(data)}:{cancellation_plan_id(data)}"
        event_id = f"subscription.cancelled:{target}"
    else:
        return 200, {"status": "ignored"}
    event = await events.record_verified(db, PROVIDER, event_id, event_type, payload)
    return await events.process(db, event, lambda: dispatch_event(db, event_type, data, "flutterwave_webhook"))


async def dispatch_event(db, event_type: str, data: dict, actor: str) -> str:
    if event_type == "charge.completed":
        try:
            transaction_id = int(data["id"])
        except (KeyError, TypeError, ValueError) as exc:
            raise HTTPException(400, "Invalid charge event") from exc
        return await process_charge(db, transaction_id, actor)
    if event_type == "subscription.cancelled":
        return await process_subscription_cancelled(db, data, actor)
    return "ignored"
