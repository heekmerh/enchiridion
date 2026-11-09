"""Google Play Billing verification, acknowledgement and Real-time Developer Notifications."""

import base64
import binascii
import json
import logging
import os
import time
import uuid
from datetime import datetime
from decimal import Decimal
from functools import lru_cache

import httpx
import jwt
from fastapi import HTTPException
from psycopg.types.json import Jsonb

from . import events, lifecycle, notifications

logger = logging.getLogger(__name__)

PROVIDER = "google_play"
PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
PUBLISHER_API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = frozenset({"https://accounts.google.com", "accounts.google.com"})
SUBSCRIPTION_PRODUCT_TYPE = 1
FULL_REFUND_TYPE = 1
GOOGLE_STATES = {
    "SUBSCRIPTION_STATE_PENDING": "PENDING",
    "SUBSCRIPTION_STATE_ACTIVE": "ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": "GRACE_PERIOD",
    "SUBSCRIPTION_STATE_ON_HOLD": "PAYMENT_FAILED",
    "SUBSCRIPTION_STATE_PAUSED": "PAUSED",
    "SUBSCRIPTION_STATE_CANCELED": "CANCELLED",
    "SUBSCRIPTION_STATE_EXPIRED": "EXPIRED",
    "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED": "EXPIRED",
}
ACKNOWLEDGEABLE_STATES = frozenset({"ACTIVE", "GRACE_PERIOD"})

_token_cache: dict = {"value": None, "expires_at": 0.0}


def package_name() -> str:
    value = os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "")
    if not value:
        raise HTTPException(503, "Google Play verification is not configured")
    return value


def service_account() -> dict:
    raw = os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw:
        raise HTTPException(503, "Google Play verification is not configured")
    try:
        if not raw.startswith("{"):
            raw = base64.b64decode(raw).decode()
        info = json.loads(raw)
        return {"client_email": info["client_email"], "private_key": info["private_key"],
                "token_uri": info.get("token_uri", "https://oauth2.googleapis.com/token"),
                "private_key_id": info.get("private_key_id")}
    except (ValueError, KeyError, binascii.Error) as exc:
        raise HTTPException(503, "Google Play service account credentials are invalid") from exc


async def access_token() -> str:
    now = time.time()
    if _token_cache["value"] and _token_cache["expires_at"] - 60 > now:
        return _token_cache["value"]
    account = service_account()
    assertion = jwt.encode(
        {"iss": account["client_email"], "scope": PUBLISHER_SCOPE, "aud": account["token_uri"],
         "iat": int(now), "exp": int(now) + 3600},
        account["private_key"], algorithm="RS256",
        headers={"kid": account["private_key_id"]} if account["private_key_id"] else None,
    )
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(account["token_uri"], data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion,
            })
            response.raise_for_status()
            payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(502, "Google authorization is temporarily unavailable") from exc
    _token_cache["value"] = payload["access_token"]
    _token_cache["expires_at"] = now + int(payload.get("expires_in", 3600))
    return _token_cache["value"]


async def publisher_call(method: str, path: str, *, json_body: dict | None = None) -> dict:
    url = f"{PUBLISHER_API}/{package_name()}{path}"
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.request(method, url, json=json_body,
                                            headers={"Authorization": f"Bearer {await access_token()}"})
    except httpx.HTTPError as exc:
        raise HTTPException(502, "Google Play is temporarily unavailable") from exc
    if response.status_code in (400, 404, 410):
        raise HTTPException(404, "Google Play does not recognise this purchase")
    if response.status_code >= 400:
        raise HTTPException(502, "Google Play is temporarily unavailable")
    return response.json() if response.content else {}


async def fetch_subscription(purchase_token: str) -> dict:
    return await publisher_call("GET", f"/purchases/subscriptionsv2/tokens/{purchase_token}")


async def acknowledge(product_id: str, purchase_token: str):
    await publisher_call("POST", f"/purchases/subscriptions/{product_id}/tokens/{purchase_token}:acknowledge", json_body={})


def parse_time(value) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))


def recurring_price(line: dict) -> tuple[Decimal, str]:
    price = (line.get("autoRenewingPlan") or {}).get("recurringPrice") or {}
    units = Decimal(str(price.get("units") or 0))
    nanos = Decimal(int(price.get("nanos") or 0)) / Decimal(1_000_000_000)
    return (units + nanos).quantize(Decimal("0.01")), str(price.get("currencyCode") or "")


def cancellation_time(purchase: dict) -> datetime | None:
    context = purchase.get("canceledStateContext") or {}
    user_cancel = context.get("userInitiatedCancellation") or {}
    return parse_time(user_cancel.get("cancelTime"))


def as_user_id(value) -> uuid.UUID | None:
    try:
        return uuid.UUID(str(value))
    except (TypeError, ValueError):
        return None


async def existing_user(db, user_id: uuid.UUID | None) -> uuid.UUID | None:
    if not user_id:
        return None
    row = await (await db.execute("SELECT id FROM auth.users WHERE id = %s", (user_id,))).fetchone()
    return row["id"] if row else None


async def resolve_owner(db, existing: dict | None, purchase: dict, claiming_user) -> uuid.UUID | None:
    account_id = (purchase.get("externalAccountIdentifiers") or {}).get("obfuscatedExternalAccountId")
    owner = existing["user_id"] if existing else None
    if claiming_user:
        foreign_owner = owner is not None and owner != claiming_user
        foreign_account = account_id is not None and as_user_id(account_id) != claiming_user
        if foreign_owner or foreign_account:
            raise HTTPException(409, "This Google Play purchase is linked to another Enchiridion account.")
        return claiming_user
    if owner:
        return owner
    owner = await existing_user(db, as_user_id(account_id))
    if owner:
        return owner
    linked_token = purchase.get("linkedPurchaseToken")
    if linked_token:
        linked = await (await db.execute(
            "SELECT user_id FROM billing.subscriptions WHERE provider = 'google_play' AND provider_reference = %s",
            (linked_token,),
        )).fetchone()
        return linked["user_id"] if linked else None
    return None


async def plan_for_line(db, line: dict) -> str:
    base_plan_id = (line.get("offerDetails") or {}).get("basePlanId")
    mapping = await (await db.execute(
        """SELECT plan_id FROM billing.provider_plan_mappings
           WHERE provider = 'google_play' AND product_id = %s AND base_plan_id = %s AND is_active""",
        (line.get("productId"), base_plan_id),
    )).fetchone()
    if not mapping:
        raise HTTPException(422, "This Google Play product is not an Enchiridion subscription plan")
    return mapping["plan_id"]


async def record_order(db, subscription: dict, line: dict, purchase: dict):
    order_id = line.get("latestSuccessfulOrderId") or purchase.get("latestOrderId")
    if not order_id or subscription["internal_state"] not in lifecycle.ENTITLING_STATES:
        return
    previous = await (await db.execute(
        "SELECT count(*) AS count FROM billing.payments WHERE subscription_id = %s AND verification_status <> 'failed'",
        (subscription["id"],),
    )).fetchone()
    amount, currency = recurring_price(line)
    kind = "renewal" if previous["count"] else "initial"
    payment = await (await db.execute(
        """INSERT INTO billing.payments(subscription_id, user_id, provider, reference, kind, amount, currency,
                                        verification_status, verified_at, period_end, provider_details)
           VALUES (%s, %s, 'google_play', %s, %s, %s, %s, 'verified', now(), %s, %s)
           ON CONFLICT (provider, reference) DO NOTHING RETURNING *""",
        (subscription["id"], subscription["user_id"], order_id, kind, amount, currency or "UNKNOWN",
         subscription["access_expires_at"], Jsonb({"region": purchase.get("regionCode"), "test": "testPurchase" in purchase})),
    )).fetchone()
    if not payment:
        return
    await lifecycle.record_settlement_estimate(db, payment["id"], PROVIDER, amount, currency or "UNKNOWN",
                                               notes="Illustrative Play fee model; reconcile with payout reports")
    await notifications.enqueue_for_subscription(
        db, subscription, "purchase_verified" if kind == "initial" else "renewal_verified", order_id)


async def notify_transition(db, previous_state: str | None, subscription: dict):
    state = subscription["internal_state"]
    if previous_state == state:
        return
    expiry = subscription["access_expires_at"].isoformat() if subscription["access_expires_at"] else "none"
    if state in ("PAYMENT_FAILED", "GRACE_PERIOD") and previous_state in lifecycle.ENTITLING_STATES:
        await notifications.enqueue_for_subscription(db, subscription, "payment_failed", expiry)
    elif state == "CANCELLED":
        await notifications.enqueue_for_subscription(db, subscription, "cancellation", expiry)
    elif state == "EXPIRED" and previous_state in lifecycle.ENTITLING_STATES and not subscription["superseded_by"]:
        await notifications.enqueue_for_subscription(db, subscription, "expiry", expiry)


async def sync_purchase(db, purchase_token: str, *, actor: str, claiming_user=None,
                        expected_product_id: str | None = None) -> dict:
    purchase = await fetch_subscription(purchase_token)
    line = (purchase.get("lineItems") or [None])[0]
    if not line:
        raise HTTPException(422, "The Google Play purchase has no subscription item")
    if expected_product_id and line.get("productId") != expected_product_id:
        raise HTTPException(422, "The Google Play purchase does not match the requested product")
    plan_id = await plan_for_line(db, line)
    existing = await (await db.execute(
        "SELECT * FROM billing.subscriptions WHERE provider = 'google_play' AND provider_reference = %s FOR UPDATE",
        (purchase_token,),
    )).fetchone()
    user_id = await resolve_owner(db, existing, purchase, claiming_user)
    if user_id:
        await lifecycle.lock_user_billing(db, user_id)
    raw_state = str(purchase.get("subscriptionState") or "")
    state = GOOGLE_STATES.get(raw_state, "PENDING")
    if existing and existing["internal_state"] == "REFUNDED" and state not in ("ACTIVE", "GRACE_PERIOD"):
        state = "REFUNDED"
    values = {
        "user_id": user_id, "plan_id": plan_id, "provider_product_id": line.get("productId"),
        "provider_plan_id": (line.get("offerDetails") or {}).get("basePlanId"), "provider_state": raw_state,
        "internal_state": state,
        "auto_renewing": bool((line.get("autoRenewingPlan") or {}).get("autoRenewEnabled")),
        "current_period_start": parse_time(purchase.get("startTime")),
        "current_period_end": parse_time(line.get("expiryTime")),
        "access_expires_at": parse_time(line.get("expiryTime")),
        "cancelled_at": cancellation_time(purchase) or (lifecycle.utcnow() if state == "CANCELLED" else None),
        "linked_provider_reference": purchase.get("linkedPurchaseToken"),
        "is_test": "testPurchase" in purchase,
    }
    await lifecycle.set_transition_context(db, f"Google Play {raw_state or 'state'}", actor)
    if existing:
        subscription = await (await db.execute(
            """UPDATE billing.subscriptions
               SET user_id = %(user_id)s, plan_id = %(plan_id)s, provider_product_id = %(provider_product_id)s,
                   provider_plan_id = %(provider_plan_id)s, provider_state = %(provider_state)s,
                   internal_state = %(internal_state)s, auto_renewing = %(auto_renewing)s,
                   current_period_start = %(current_period_start)s, current_period_end = %(current_period_end)s,
                   access_expires_at = %(access_expires_at)s,
                   cancelled_at = CASE WHEN %(auto_renewing)s THEN NULL ELSE coalesce(cancelled_at, %(cancelled_at)s) END,
                   linked_provider_reference = %(linked_provider_reference)s, is_test = %(is_test)s, updated_at = now()
               WHERE id = %(id)s RETURNING *""",
            {**values, "id": existing["id"]},
        )).fetchone()
    else:
        subscription = await (await db.execute(
            """INSERT INTO billing.subscriptions(user_id, plan_id, provider, provider_reference, provider_product_id,
                   provider_plan_id, provider_state, internal_state, auto_renewing, current_period_start,
                   current_period_end, access_expires_at, cancelled_at, linked_provider_reference, is_test)
               VALUES (%(user_id)s, %(plan_id)s, 'google_play', %(token)s, %(provider_product_id)s,
                   %(provider_plan_id)s, %(provider_state)s, %(internal_state)s, %(auto_renewing)s,
                   %(current_period_start)s, %(current_period_end)s, %(access_expires_at)s, %(cancelled_at)s,
                   %(linked_provider_reference)s, %(is_test)s)
               RETURNING *""",
            {**values, "token": purchase_token},
        )).fetchone()
    if values["linked_provider_reference"]:
        await lifecycle.set_transition_context(db, "Replaced by a newer Google Play purchase", actor)
        await db.execute(
            """UPDATE billing.subscriptions
               SET superseded_by = %s, auto_renewing = false, updated_at = now(),
                   internal_state = CASE WHEN internal_state = 'REFUNDED' THEN internal_state ELSE 'EXPIRED' END
               WHERE provider = 'google_play' AND provider_reference = %s AND id <> %s AND superseded_by IS NULL""",
            (subscription["id"], values["linked_provider_reference"], subscription["id"]),
        )
    if subscription["user_id"]:
        await record_order(db, subscription, line, purchase)
        await notify_transition(db, existing["internal_state"] if existing else None, subscription)
    needs_acknowledgement = (purchase.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_PENDING"
                             and not subscription["acknowledged_at"])
    if needs_acknowledgement and subscription["user_id"] and state in ACKNOWLEDGEABLE_STATES:
        try:
            await acknowledge(line["productId"], purchase_token)
            subscription = await (await db.execute(
                "UPDATE billing.subscriptions SET acknowledged_at = now() WHERE id = %s RETURNING *", (subscription["id"],),
            )).fetchone()
        except HTTPException:
            logger.warning("Acknowledgement of subscription %s will be retried", subscription["id"])
    elif not needs_acknowledgement and not subscription["acknowledged_at"] and state in ACKNOWLEDGEABLE_STATES:
        subscription = await (await db.execute(
            "UPDATE billing.subscriptions SET acknowledged_at = now() WHERE id = %s RETURNING *", (subscription["id"],),
        )).fetchone()
    return subscription


async def process_voided(db, voided: dict, actor: str) -> str:
    if int(voided.get("productType") or 0) != SUBSCRIPTION_PRODUCT_TYPE:
        return "ignored"
    token, order_id = voided.get("purchaseToken"), voided.get("orderId")
    await db.execute(
        """UPDATE billing.payments SET verification_status = 'refunded', refunded_at = now(), updated_at = now()
           WHERE provider = 'google_play' AND reference = %s""",
        (order_id,),
    )
    subscription = await (await db.execute(
        "SELECT * FROM billing.subscriptions WHERE provider = 'google_play' AND provider_reference = %s FOR UPDATE",
        (token,),
    )).fetchone()
    if not subscription:
        return "processed"
    try:
        subscription = await sync_purchase(db, token, actor=actor)
    except HTTPException as exc:
        if exc.status_code != 404:
            raise
    if int(voided.get("refundType") or 0) == FULL_REFUND_TYPE and subscription["internal_state"] not in ("ACTIVE", "GRACE_PERIOD"):
        await lifecycle.set_transition_context(db, "Google Play purchase refunded", actor)
        await db.execute(
            "UPDATE billing.subscriptions SET internal_state = 'REFUNDED', auto_renewing = false, updated_at = now() WHERE id = %s",
            (subscription["id"],),
        )
    return "processed"


def decode_message(message: dict) -> dict:
    try:
        return json.loads(base64.b64decode(message["data"]))
    except (KeyError, TypeError, ValueError, binascii.Error) as exc:
        raise HTTPException(400, "Invalid Pub/Sub message") from exc


async def process_notification(db, notification: dict, actor: str) -> str:
    if notification.get("packageName") != package_name() or "testNotification" in notification:
        return "ignored"
    subscription_notification = notification.get("subscriptionNotification")
    if subscription_notification:
        await sync_purchase(db, subscription_notification["purchaseToken"], actor=actor)
        return "processed"
    voided = notification.get("voidedPurchaseNotification")
    if voided:
        return await process_voided(db, voided, actor)
    return "ignored"


@lru_cache(maxsize=1)
def google_jwks() -> jwt.PyJWKClient:
    return jwt.PyJWKClient(GOOGLE_CERTS_URL, cache_keys=True, lifespan=3600)


def push_request_is_authentic(authorization: str) -> bool:
    audience = os.getenv("GOOGLE_RTDN_AUDIENCE", "")
    service_account_email = os.getenv("GOOGLE_RTDN_SERVICE_ACCOUNT", "")
    if not audience or not service_account_email:
        raise HTTPException(503, "Google Play notifications are not configured")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return False
    try:
        key = google_jwks().get_signing_key_from_jwt(token).key
        claims = jwt.decode(token, key, algorithms=["RS256"], audience=audience, options={"verify_iss": False})
    except jwt.PyJWTError:
        return False
    return (claims.get("iss") in GOOGLE_ISSUERS and claims.get("email") == service_account_email
            and claims.get("email_verified") is True)


async def handle_push(db, body: dict) -> tuple[int, dict]:
    message = body.get("message") if isinstance(body.get("message"), dict) else {}
    message_id = str(message.get("messageId") or message.get("message_id") or "")
    if not message_id:
        raise HTTPException(400, "Missing Pub/Sub message id")
    notification = decode_message(message)
    notification_type = "subscription" if "subscriptionNotification" in notification else (
        "voided" if "voidedPurchaseNotification" in notification else "other")
    event = await events.record_verified(db, PROVIDER, message_id, notification_type, notification)
    return await events.process(db, event, lambda: process_notification(db, notification, "google_rtdn"))
