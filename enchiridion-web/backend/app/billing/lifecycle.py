"""Subscription state rules shared by every payment provider."""

import calendar
import logging
import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from urllib.parse import urlencode

from fastapi import HTTPException

from .. import mailer
from . import copy

logger = logging.getLogger(__name__)

ENTITLING_STATES = frozenset({"ACTIVE", "GRACE_PERIOD", "CANCELLED"})
RECURRING_LIVE_STATES = frozenset({"ACTIVE", "GRACE_PERIOD", "PAYMENT_FAILED", "PAUSED"})
# A non-renewing plan may be bought again this close to its expiry; the new period starts when the old one ends.
MANUAL_RENEWAL_WINDOW = timedelta(days=7)
PREMIUM_FEATURE = "premium"


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def add_billing_interval(start: datetime, interval: str, count: int = 1) -> datetime:
    months = count * (12 if interval == "year" else 1)
    month_index = start.month - 1 + months
    year = start.year + month_index // 12
    month = month_index % 12 + 1
    day = min(start.day, calendar.monthrange(year, month)[1])
    return start.replace(year=year, month=month, day=day)


async def set_transition_context(db, reason: str, actor: str):
    await db.execute(
        "SELECT set_config('billing.transition_reason', %s, true), set_config('billing.transition_actor', %s, true)",
        (reason, actor),
    )


async def lock_user_billing(db, user_id):
    await db.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s, 7))", (f"billing:{user_id}",))


async def live_subscriptions(db, user_id) -> list[dict]:
    return await (await db.execute(
        """SELECT * FROM billing.subscriptions
           WHERE user_id = %s AND superseded_by IS NULL
             AND (internal_state = ANY(%s) OR (internal_state = ANY(%s) AND access_expires_at > now()))""",
        (user_id, list(RECURRING_LIVE_STATES), list(ENTITLING_STATES)),
    )).fetchall()


def blocks_new_purchase(subscription: dict, now: datetime) -> bool:
    if subscription["auto_renewing"] and subscription["internal_state"] in RECURRING_LIVE_STATES:
        return True
    expiry = subscription["access_expires_at"]
    return (subscription["internal_state"] in ENTITLING_STATES and expiry is not None
            and expiry - now > MANUAL_RENEWAL_WINDOW)


async def assert_can_purchase(db, user_id):
    now = utcnow()
    if any(blocks_new_purchase(row, now) for row in await live_subscriptions(db, user_id)):
        raise HTTPException(409, {"code": "subscription_exists", "message": copy.EXISTING_SUBSCRIPTION})


async def next_period_start(db, user_id) -> tuple[datetime, bool]:
    now = utcnow()
    start = now
    overlapping = False
    for row in await live_subscriptions(db, user_id):
        overlapping = overlapping or blocks_new_purchase(row, now)
        expiry = row["access_expires_at"]
        if row["internal_state"] in ENTITLING_STATES and expiry and expiry > start:
            start = expiry
    return start, overlapping


async def active_entitlements(db, user_id) -> list[dict]:
    return await (await db.execute(
        "SELECT feature, expires_at, source FROM billing.active_entitlements(%s) ORDER BY feature", (user_id,),
    )).fetchall()


async def current_subscription(db, user_id) -> dict | None:
    return await (await db.execute(
        """SELECT s.*, p.name AS plan_name, p.billing_interval
           FROM billing.subscriptions s JOIN billing.plans p ON p.id = s.plan_id
           WHERE s.user_id = %s AND s.superseded_by IS NULL AND s.internal_state <> 'PENDING'
           ORDER BY billing.is_entitling_state(s.internal_state) AND coalesce(s.access_expires_at > now(), false) DESC,
                    s.auto_renewing DESC, s.access_expires_at DESC NULLS LAST
           LIMIT 1""",
        (user_id,),
    )).fetchone()


def google_play_management_url(product_id: str | None) -> str:
    params = {"package": os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "")}
    if product_id:
        params["sku"] = product_id
    return "https://play.google.com/store/account/subscriptions?" + urlencode(params)


def management_for(subscription: dict) -> dict:
    if subscription["provider"] == "google_play":
        return {"method": "google_play", "url": google_play_management_url(subscription["provider_product_id"]),
                "instructions": copy.GOOGLE_PLAY_MANAGEMENT, "can_cancel_here": False}
    return {"method": "website", "url": mailer.frontend_url() + "/account/subscription",
            "instructions": copy.WEBSITE_MANAGEMENT,
            "can_cancel_here": subscription["auto_renewing"] and subscription["internal_state"] in RECURRING_LIVE_STATES}


def iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def status_message(subscription: dict) -> str:
    state = subscription["internal_state"]
    if state in ("PAYMENT_FAILED", "PAUSED"):
        return copy.PAYMENT_FAILED
    if state == "CANCELLED":
        return copy.CANCELLATION
    if state in ("EXPIRED", "REFUNDED"):
        return copy.EXPIRY
    return copy.PURCHASE_VERIFIED


def serialize_subscription(subscription: dict | None) -> dict | None:
    if not subscription:
        return None
    return {
        "id": str(subscription["id"]),
        "plan_id": subscription["plan_id"],
        "plan_name": subscription.get("plan_name"),
        "provider": subscription["provider"],
        "state": subscription["internal_state"],
        "provider_state": subscription["provider_state"],
        "auto_renewing": subscription["auto_renewing"],
        "current_period_end": iso(subscription["current_period_end"]),
        "access_expires_at": iso(subscription["access_expires_at"]),
        "cancelled_at": iso(subscription["cancelled_at"]),
        "message": status_message(subscription),
        "management": management_for(subscription),
    }


def serialize_entitlements(rows: list[dict]) -> dict:
    return {
        "premium": any(row["feature"] == PREMIUM_FEATURE for row in rows),
        "entitlements": [{"feature": row["feature"], "expires_at": iso(row["expires_at"]), "source": row["source"]}
                         for row in rows],
    }


def to_decimal(value) -> Decimal:
    return Decimal(str(value if value is not None else 0))


async def record_settlement_estimate(db, payment_id, provider: str, gross: Decimal, currency: str,
                                     provider_fee: Decimal | None = None, notes: str = ""):
    assumptions = await (await db.execute(
        "SELECT * FROM billing.settlement_assumptions WHERE provider = %s", (provider,),
    )).fetchone()
    if not assumptions:
        return
    customer_tax = (gross * assumptions["customer_tax_rate"] / (1 + assumptions["customer_tax_rate"])).quantize(Decimal("0.01"))
    net_sale = gross - customer_tax
    fee = provider_fee if provider_fee is not None else (net_sale * assumptions["commission_rate"]).quantize(Decimal("0.01"))
    fee_tax = (fee * assumptions["commission_tax_rate"]).quantize(Decimal("0.01"))
    await db.execute(
        """INSERT INTO billing.settlements(payment_id, provider, source, gross_amount, customer_tax, provider_fee,
                                           provider_fee_tax, settlement_currency, net_amount, notes)
           VALUES (%s, %s, 'estimate', %s, %s, %s, %s, %s, %s, %s)
           ON CONFLICT (payment_id, source) DO NOTHING""",
        (payment_id, provider, gross, customer_tax, fee, fee_tax, currency, gross - customer_tax - fee - fee_tax, notes),
    )
