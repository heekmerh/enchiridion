"""Versioned subscription and payment API shared by the website and the Android app."""

import hmac
import json
import logging
import os
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from .. import flutterwave
from ..auth import CurrentUser, current_active_superuser, current_active_user
from ..billing import catalog, copy, events, flutterwave_billing, google_play, jobs, lifecycle
from ..database import get_db

logger = logging.getLogger(__name__)

router = APIRouter()
DB = Depends(get_db, scope="function")
USER = Depends(current_active_user)
ADMIN = Depends(current_active_superuser)


@router.get("/subscription/plans")
async def plans(db=DB):
    return {
        "currency": catalog.CATALOG_CURRENCY,
        "plans": catalog.serialize_plans(await catalog.active_plans(db)),
        "price_notice": copy.PRICE_INCLUSION,
        "renewal_terms": {"automatic": copy.AUTOMATIC_RENEWAL_TERMS, "manual": copy.MANUAL_RENEWAL_TERMS},
    }


@router.get("/subscription/current")
async def current(user: CurrentUser = USER, db=DB):
    subscription = await lifecycle.current_subscription(db, user.id)
    return {
        "subscription": lifecycle.serialize_subscription(subscription),
        **lifecycle.serialize_entitlements(await lifecycle.active_entitlements(db, user.id)),
    }


@router.get("/subscription/entitlements")
async def entitlements(user: CurrentUser = USER, db=DB):
    return lifecycle.serialize_entitlements(await lifecycle.active_entitlements(db, user.id))


@router.post("/subscription/cancel")
async def cancel(user: CurrentUser = USER, db=DB):
    await lifecycle.lock_user_billing(db, user.id)
    subscription = await lifecycle.current_subscription(db, user.id)
    if not subscription or not subscription["auto_renewing"]:
        raise HTTPException(409, "There is no renewing subscription to cancel.")
    if subscription["provider"] == "google_play":
        management = lifecycle.management_for(subscription)
        raise HTTPException(409, {"code": "manage_with_google_play", "message": management["instructions"],
                                  "url": management["url"]})
    updated = await flutterwave_billing.cancel(db, subscription, f"user:{user.id}")
    updated = {**updated, "plan_name": subscription["plan_name"]}
    return {"subscription": lifecycle.serialize_subscription(updated), "message": copy.CANCELLATION}


class CheckoutRequest(BaseModel):
    plan_id: str = Field(pattern=r"^[a-z0-9_]{1,64}$")
    auto_renew: bool = True


@router.post("/payments/flutterwave/checkout")
async def flutterwave_checkout(body: CheckoutRequest, user: CurrentUser = USER, db=DB):
    return await flutterwave_billing.create_checkout(db, user, body.plan_id, body.auto_renew)


async def owned_checkout(db, reference: str, user: CurrentUser) -> dict:
    checkout = await (await db.execute(
        "SELECT * FROM billing.checkout_sessions WHERE reference = %s AND user_id = %s", (reference, user.id),
    )).fetchone()
    if not checkout:
        raise HTTPException(404, "Checkout not found")
    return checkout


async def checkout_status(db, checkout: dict) -> dict:
    subscription = await (await db.execute(
        """SELECT s.*, p.name AS plan_name FROM billing.subscriptions s JOIN billing.plans p ON p.id = s.plan_id
           WHERE s.provider = 'flutterwave' AND s.provider_reference = %s""",
        (checkout["reference"],),
    )).fetchone()
    messages = {"pending": copy.PAYMENT_PROCESSING, "paid": copy.PURCHASE_VERIFIED, "failed": copy.PAYMENT_FAILED,
                "abandoned": copy.PAYMENT_FAILED}
    return {"reference": checkout["reference"], "status": checkout["status"], "message": messages[checkout["status"]],
            "subscription": lifecycle.serialize_subscription(subscription)}


@router.get("/payments/flutterwave/checkout/{reference}")
async def flutterwave_checkout_status(reference: str, user: CurrentUser = USER, db=DB):
    return await checkout_status(db, await owned_checkout(db, reference, user))


class ConfirmRequest(BaseModel):
    reference: str = Field(min_length=1, max_length=200)
    transaction_id: int | None = Field(default=None, gt=0)


@router.post("/payments/flutterwave/confirm")
async def flutterwave_confirm(body: ConfirmRequest, user: CurrentUser = USER, db=DB):
    checkout = await owned_checkout(db, body.reference, user)
    if checkout["status"] == "pending":
        if body.transaction_id:
            tx = await flutterwave.fetch_transaction(body.transaction_id)
        else:
            tx = await flutterwave.fetch_transaction_by_reference(body.reference)
        if tx and tx.get("tx_ref") == body.reference:
            await flutterwave_billing.apply_transaction(db, tx, f"user:{user.id}")
        checkout = await owned_checkout(db, body.reference, user)
    return await checkout_status(db, checkout)


@router.post("/payments/flutterwave/webhook")
async def flutterwave_webhook(request: Request, db=DB):
    raw = await request.body()
    if not flutterwave.webhook_is_authentic(raw, request.headers):
        await events.record_rejected(db, "flutterwave")
        return JSONResponse({"detail": "Invalid webhook signature"}, status_code=401)
    try:
        payload = json.loads(raw)
    except ValueError:
        return JSONResponse({"detail": "Invalid webhook payload"}, status_code=400)
    if not isinstance(payload, dict):
        return JSONResponse({"detail": "Invalid webhook payload"}, status_code=400)
    status, body = await flutterwave_billing.handle_webhook(db, payload)
    return JSONResponse(body, status_code=status)


class GoogleVerifyRequest(BaseModel):
    purchase_token: str = Field(min_length=10, max_length=4096)
    product_id: str = Field(min_length=1, max_length=200)


@router.post("/payments/google/verify")
async def google_verify(body: GoogleVerifyRequest, user: CurrentUser = USER, db=DB):
    subscription = await google_play.sync_purchase(
        db, body.purchase_token, actor=f"user:{user.id}", claiming_user=user.id, expected_product_id=body.product_id,
    )
    entitlement = lifecycle.serialize_entitlements(await lifecycle.active_entitlements(db, user.id))
    pending = subscription["internal_state"] == "PENDING"
    plan = await (await db.execute("SELECT name FROM billing.plans WHERE id = %s", (subscription["plan_id"],))).fetchone()
    return {
        "status": "pending" if pending else subscription["internal_state"].lower(),
        "message": copy.PAYMENT_PROCESSING if pending else lifecycle.status_message(subscription),
        "acknowledged": subscription["acknowledged_at"] is not None,
        "subscription": lifecycle.serialize_subscription({**subscription, "plan_name": plan["name"]}),
        **entitlement,
    }


@router.post("/payments/google/notifications")
async def google_notifications(request: Request, db=DB):
    if not google_play.push_request_is_authentic(request.headers.get("authorization", "")):
        await events.record_rejected(db, "google_play")
        return JSONResponse({"detail": "Invalid push authentication"}, status_code=401)
    try:
        body = await request.json()
    except ValueError:
        return JSONResponse({"detail": "Invalid push payload"}, status_code=400)
    status, response = await google_play.handle_push(db, body if isinstance(body, dict) else {})
    return JSONResponse(response, status_code=status)


class RefundRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=500)


@router.post("/admin/subscriptions/{subscription_id}/refunded")
async def record_refund(subscription_id: uuid.UUID, body: RefundRequest, user: CurrentUser = ADMIN, db=DB):
    await lifecycle.set_transition_context(db, f"Refund recorded: {body.reason}", f"admin:{user.id}")
    subscription = await (await db.execute(
        """UPDATE billing.subscriptions SET internal_state = 'REFUNDED', auto_renewing = false, updated_at = now()
           WHERE id = %s RETURNING *""",
        (subscription_id,),
    )).fetchone()
    if not subscription:
        raise HTTPException(404, "Subscription not found")
    await db.execute(
        """UPDATE billing.payments SET verification_status = 'refunded', refunded_at = now(), updated_at = now()
           WHERE subscription_id = %s AND verification_status = 'verified'""",
        (subscription_id,),
    )
    await db.execute("INSERT INTO audit_logs(actor_id, action, details) VALUES (%s, 'subscription_refunded', %s::jsonb)",
                     (user.id, json.dumps({"subscription_id": str(subscription_id), "reason": body.reason})))
    return {"subscription": lifecycle.serialize_subscription(subscription)}


@router.get("/internal/jobs")
async def run_jobs(request: Request, db=DB):
    secret = os.getenv("CRON_SECRET", "")
    supplied = request.headers.get("authorization", "")
    if not secret or not hmac.compare_digest(supplied, f"Bearer {secret}"):
        raise HTTPException(401, "Unauthorized")
    return await jobs.run_all(db)
