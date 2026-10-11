"""Subscription lifecycle across Flutterwave and Google Play, with provider APIs replaced by fakes."""

import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from unittest.mock import AsyncMock

import psycopg
import pytest

from app import flutterwave, mailer
from app.billing import google_play, lifecycle
from tests.conftest import auth_headers, create_user, fetch

WEBHOOK_SECRET = "test-webhook-secret"
FLUTTERWAVE_PLAN_ID = "90001"


class FakeFlutterwave:
    def __init__(self):
        self.requests = []
        self.transactions = {}

    async def call(self, method, path, *, json=None, params=None):
        self.requests.append((method, path, json, params))
        if path == "/payment-plans":
            return {"status": "success", "data": {"id": int(FLUTTERWAVE_PLAN_ID) + len(self.requests)}}
        if path == "/payments":
            return {"status": "success", "data": {"link": "https://checkout.flutterwave.test/pay/" + json["tx_ref"]}}
        if path == "/subscriptions":
            return {"status": "success", "data": [{"id": 5551}]}
        if path.endswith("/cancel"):
            return {"status": "success", "data": {}}
        raise AssertionError(f"Unexpected Flutterwave call {method} {path}")

    async def fetch_transaction(self, transaction_id):
        return self.transactions[int(transaction_id)]

    async def fetch_transaction_by_reference(self, reference):
        return next((tx for tx in self.transactions.values() if tx["tx_ref"] == reference), None)


@pytest.fixture
def fake_flutterwave(monkeypatch):
    fake = FakeFlutterwave()
    monkeypatch.setenv("FLUTTERWAVE_WEBHOOK_SECRET", WEBHOOK_SECRET)
    monkeypatch.setattr(flutterwave, "call", fake.call)
    monkeypatch.setattr(flutterwave, "fetch_transaction", fake.fetch_transaction)
    monkeypatch.setattr(flutterwave, "fetch_transaction_by_reference", fake.fetch_transaction_by_reference)
    return fake


def signed_webhook(client, payload: dict):
    raw = json.dumps(payload).encode()
    signature = base64.b64encode(hmac.new(WEBHOOK_SECRET.encode(), raw, hashlib.sha256).digest()).decode()
    return client.post("/api/v1/payments/flutterwave/webhook", content=raw, headers={"flutterwave-signature": signature})


def successful_charge(fake, transaction_id, tx_ref, amount, email="reader@example.com", **extra):
    fake.transactions[transaction_id] = {
        "id": transaction_id, "tx_ref": tx_ref, "status": "successful", "currency": "NGN", "amount": amount,
        "charged_amount": amount, "app_fee": 21.0, "amount_settled": amount - 21, "customer": {"email": email}, **extra,
    }
    return {"event": "charge.completed", "data": {"id": transaction_id, "status": extra.get("status", "successful")}}


def subscribe_on_website(client, fake, headers, plan_id="premium_monthly", auto_renew=True, transaction_id=1001):
    checkout = client.post("/api/v1/payments/flutterwave/checkout", headers=headers,
                           json={"plan_id": plan_id, "auto_renew": auto_renew, "amount": 1})
    assert checkout.status_code == 200, checkout.text
    reference = checkout.json()["reference"]
    amount = 1500 if plan_id == "premium_monthly" else 15000
    response = signed_webhook(client, successful_charge(fake, transaction_id, reference, amount))
    assert response.status_code == 200, response.text
    return reference


def test_plan_catalogue_uses_server_prices(client, db_url):
    body = client.get("/api/v1/subscription/plans").json()
    plans = {plan["id"]: plan for plan in body["plans"]}
    assert plans["premium_monthly"]["price"]["display"] == "₦1,500"
    assert plans["premium_annual"]["price"]["display"] == "₦15,000"
    assert plans["premium_annual"]["description"] == "Save ₦3,000 compared with twelve monthly payments."
    assert "included" in body["price_notice"]


def test_checkout_requires_verified_account_and_ignores_client_price(client, db_url, fake_flutterwave):
    unverified = create_user(db_url, "new@example.com", verified=False)
    response = client.post("/api/v1/payments/flutterwave/checkout", headers=auth_headers(unverified),
                           json={"plan_id": "premium_monthly"})
    assert response.status_code == 403
    user_id = create_user(db_url)
    response = client.post("/api/v1/payments/flutterwave/checkout", headers=auth_headers(user_id),
                           json={"plan_id": "premium_annual", "amount": 5})
    assert response.status_code == 200, response.text
    assert response.json()["amount"] == 15000
    payment_request = next(body for method, path, body, _ in fake_flutterwave.requests if path == "/payments")
    assert payment_request["amount"] == 15000 and payment_request["payment_options"] == "card"
    assert payment_request["payment_plan"]
    session = fetch(db_url, "SELECT amount, auto_renew, status FROM billing.checkout_sessions")[0]
    assert session == {"amount": Decimal("15000.00"), "auto_renew": True, "status": "pending"}
    with pytest.raises(psycopg.errors.RaiseException):
        with psycopg.connect(db_url) as db:
            db.execute("UPDATE billing.checkout_sessions SET amount = 1")


def test_website_purchase_grants_premium_once(client, db_url, fake_flutterwave):
    user_id = create_user(db_url)
    headers = auth_headers(user_id)
    reference = subscribe_on_website(client, fake_flutterwave, headers)
    current = client.get("/api/v1/subscription/current", headers=headers).json()
    assert current["premium"] is True
    assert current["subscription"]["state"] == "ACTIVE"
    assert current["subscription"]["management"]["method"] == "website"
    replay = signed_webhook(client, {"event": "charge.completed", "data": {"id": 1001, "status": "successful"}})
    assert replay.json() == {"status": "duplicate"}
    confirm = client.post("/api/v1/payments/flutterwave/confirm", headers=headers, json={"reference": reference})
    assert confirm.json()["status"] == "paid"
    assert fetch(db_url, "SELECT count(*) AS count FROM billing.payments")[0]["count"] == 1
    assert fetch(db_url, "SELECT kind FROM enchiridion_web.email_outbox")[0]["kind"] == "purchase_verified"
    other = create_user(db_url, "other@example.com")
    assert client.get(f"/api/v1/payments/flutterwave/checkout/{reference}", headers=auth_headers(other)).status_code == 404


def test_mismatched_payment_is_rejected(client, db_url, fake_flutterwave):
    headers = auth_headers(create_user(db_url))
    reference = client.post("/api/v1/payments/flutterwave/checkout", headers=headers,
                            json={"plan_id": "premium_monthly"}).json()["reference"]
    response = signed_webhook(client, successful_charge(fake_flutterwave, 2001, reference, 100))
    assert response.status_code == 200
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["premium"] is False
    assert fetch(db_url, "SELECT status FROM billing.checkout_sessions")[0]["status"] == "failed"
    assert fetch(db_url, "SELECT verification_status FROM billing.payments")[0]["verification_status"] == "failed"


def test_overlapping_recurring_subscription_is_blocked(client, db_url, fake_flutterwave):
    headers = auth_headers(create_user(db_url))
    subscribe_on_website(client, fake_flutterwave, headers)
    response = client.post("/api/v1/payments/flutterwave/checkout", headers=headers, json={"plan_id": "premium_annual"})
    assert response.status_code == 409
    assert response.json()["detail"]["message"].startswith("Premium is already active")


def test_renewal_extends_period_and_failure_is_recorded(client, db_url, fake_flutterwave):
    headers = auth_headers(create_user(db_url))
    subscribe_on_website(client, fake_flutterwave, headers)
    plan_id = fetch(db_url, "SELECT provider_plan_id FROM billing.subscriptions")[0]["provider_plan_id"]
    first_end = fetch(db_url, "SELECT access_expires_at FROM billing.subscriptions")[0]["access_expires_at"]
    signed_webhook(client, successful_charge(fake_flutterwave, 3001, "FLW-RENEWAL-1", 1500, payment_plan=int(plan_id)))
    row = fetch(db_url, "SELECT access_expires_at, internal_state FROM billing.subscriptions")[0]
    assert row["access_expires_at"] == lifecycle.add_billing_interval(first_end, "month")
    payload = successful_charge(fake_flutterwave, 3002, "FLW-RENEWAL-2", 1500, payment_plan=int(plan_id), status="failed")
    signed_webhook(client, payload)
    assert fetch(db_url, "SELECT internal_state FROM billing.subscriptions")[0]["internal_state"] == "PAYMENT_FAILED"
    kinds = {row["kind"] for row in fetch(db_url, "SELECT kind FROM enchiridion_web.email_outbox")}
    assert {"renewal_verified", "payment_failed"} <= kinds


def test_unmatched_renewal_is_kept_for_reconciliation(client, db_url, fake_flutterwave):
    response = signed_webhook(client, successful_charge(fake_flutterwave, 4001, "UNKNOWN", 1500, payment_plan=1))
    assert response.status_code == 200
    event = fetch(db_url, "SELECT processing_status, last_error FROM billing.payment_events")[0]
    assert event["processing_status"] == "failed" and "No subscription" in event["last_error"]


def test_cancellation_keeps_access_until_period_end(client, db_url, fake_flutterwave):
    headers = auth_headers(create_user(db_url))
    subscribe_on_website(client, fake_flutterwave, headers)
    response = client.post("/api/v1/subscription/cancel", headers=headers)
    assert response.status_code == 200, response.text
    assert response.json()["subscription"]["state"] == "CANCELLED"
    assert ("PUT", "/subscriptions/5551/cancel", None, None) in fake_flutterwave.requests
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["premium"] is True
    assert client.post("/api/v1/subscription/cancel", headers=headers).status_code == 409
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE billing.subscriptions SET access_expires_at = now() - interval '1 minute'")
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["premium"] is False


def cancellation_webhook(plan_id):
    return {"event": "subscription.cancelled", "data": {
        "status": "deactivated", "currency": "NGN", "amount": 1500,
        "customer": {"email": "reader@example.com", "full_name": "Test Reader"},
        "plan": {"id": int(plan_id), "interval": "monthly", "status": "cancel"}}}


def test_provider_cancellation_webhook_without_subscription_id(client, db_url, fake_flutterwave):
    headers = auth_headers(create_user(db_url))
    subscribe_on_website(client, fake_flutterwave, headers)
    plan_id = fetch(db_url, "SELECT provider_plan_id FROM billing.subscriptions")[0]["provider_plan_id"]
    assert signed_webhook(client, cancellation_webhook(plan_id)).json()["status"] == "processed"
    assert signed_webhook(client, cancellation_webhook(plan_id)).json() == {"status": "duplicate"}
    row = fetch(db_url, "SELECT internal_state, auto_renewing FROM billing.subscriptions")[0]
    assert row == {"internal_state": "CANCELLED", "auto_renewing": False}

    with psycopg.connect(db_url) as db:
        db.execute("UPDATE billing.subscriptions SET internal_state = 'EXPIRED', access_expires_at = now() - interval '1 day'")
    subscribe_on_website(client, fake_flutterwave, headers, transaction_id=1002)
    assert signed_webhook(client, cancellation_webhook(plan_id)).json()["status"] == "processed"
    states = [row["internal_state"] for row in fetch(db_url, "SELECT internal_state FROM billing.subscriptions ORDER BY created_at")]
    assert states == ["EXPIRED", "CANCELLED"]


def test_reconciliation_recovers_missed_webhooks_and_expires(client, db_url, fake_flutterwave, monkeypatch):
    monkeypatch.setenv("CRON_SECRET", "cron-secret")
    headers = auth_headers(create_user(db_url))
    reference = client.post("/api/v1/payments/flutterwave/checkout", headers=headers,
                            json={"plan_id": "premium_monthly", "auto_renew": False}).json()["reference"]
    successful_charge(fake_flutterwave, 5001, reference, 1500)
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE billing.checkout_sessions SET created_at = now() - interval '1 hour'")
    assert client.get("/api/v1/internal/jobs").status_code == 401
    result = client.get("/api/v1/internal/jobs", headers={"Authorization": "Bearer cron-secret"}).json()
    assert result["checkouts"]["checked"] == 1
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["premium"] is True
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE billing.subscriptions SET access_expires_at = now() - interval '1 minute'")
    result = client.get("/api/v1/internal/jobs", headers={"Authorization": "Bearer cron-secret"}).json()
    assert result["flutterwave"]["expired"] == 1
    transitions = fetch(db_url, "SELECT to_state, actor FROM billing.subscription_transitions ORDER BY id")
    assert transitions[0]["to_state"] == "ACTIVE"
    assert transitions[-1] == {"to_state": "EXPIRED", "actor": "reconciliation"}


def google_purchase(user_id, state="SUBSCRIPTION_STATE_ACTIVE", base_plan="premium-monthly", order="GPA.1-1",
                    acknowledged=False, days=30, linked=None):
    purchase = {
        "subscriptionState": state,
        "startTime": datetime.now(timezone.utc).isoformat(),
        "regionCode": "NG",
        "acknowledgementState": "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" if acknowledged else "ACKNOWLEDGEMENT_STATE_PENDING",
        "externalAccountIdentifiers": {"obfuscatedExternalAccountId": str(user_id)},
        "lineItems": [{
            "productId": "enchiridion_premium",
            "expiryTime": (datetime.now(timezone.utc) + timedelta(days=days)).isoformat().replace("+00:00", "Z"),
            "autoRenewingPlan": {"autoRenewEnabled": state == "SUBSCRIPTION_STATE_ACTIVE",
                                 "recurringPrice": {"currencyCode": "NGN", "units": "1500"}},
            "offerDetails": {"basePlanId": base_plan},
            "latestSuccessfulOrderId": order,
        }],
    }
    if linked:
        purchase["linkedPurchaseToken"] = linked
    return purchase


@pytest.fixture
def fake_google(monkeypatch):
    purchases = {}
    acknowledge = AsyncMock()
    monkeypatch.setenv("GOOGLE_PLAY_PACKAGE_NAME", "site.enchiridion.app")

    async def fetch_subscription(token):
        if token not in purchases:
            from fastapi import HTTPException
            raise HTTPException(404, "Google Play does not recognise this purchase")
        return purchases[token]

    monkeypatch.setattr(google_play, "fetch_subscription", fetch_subscription)
    monkeypatch.setattr(google_play, "acknowledge", acknowledge)
    return purchases, acknowledge


def verify(client, headers, token):
    return client.post("/api/v1/payments/google/verify", headers=headers,
                       json={"purchase_token": token, "product_id": "enchiridion_premium"})


def test_google_purchase_is_verified_acknowledged_and_bound(client, db_url, fake_google):
    purchases, acknowledge = fake_google
    user_id = create_user(db_url)
    purchases["token-000000001"] = google_purchase(user_id)
    response = verify(client, auth_headers(user_id), "token-000000001")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["premium"] is True and body["acknowledged"] is True
    assert body["subscription"]["management"]["method"] == "google_play"
    acknowledge.assert_awaited_once_with("enchiridion_premium", "token-000000001")
    settlement = fetch(db_url, "SELECT customer_tax, provider_fee, provider_fee_tax, net_amount FROM billing.settlements")[0]
    assert settlement == {"customer_tax": Decimal("104.65"), "provider_fee": Decimal("209.30"),
                          "provider_fee_tax": Decimal("15.70"), "net_amount": Decimal("1170.35")}
    intruder = create_user(db_url, "intruder@example.com")
    assert verify(client, auth_headers(intruder), "token-000000001").status_code == 409
    purchases["token-000000002"] = google_purchase(user_id, order="GPA.2-1")
    assert verify(client, auth_headers(intruder), "token-000000002").status_code == 409


def test_pending_google_purchase_grants_nothing(client, db_url, fake_google):
    purchases, acknowledge = fake_google
    user_id = create_user(db_url)
    purchases["token-pending-1"] = google_purchase(user_id, state="SUBSCRIPTION_STATE_PENDING")
    body = verify(client, auth_headers(user_id), "token-pending-1").json()
    assert body["status"] == "pending" and body["premium"] is False
    assert not acknowledge.called


def test_unknown_google_product_is_rejected(client, db_url, fake_google):
    purchases, _ = fake_google
    user_id = create_user(db_url)
    purchases["token-unknown-1"] = google_purchase(user_id, base_plan="lifetime")
    assert verify(client, auth_headers(user_id), "token-unknown-1").status_code == 422


def test_google_subscriber_cannot_start_website_checkout(client, db_url, fake_google, fake_flutterwave):
    purchases, _ = fake_google
    user_id = create_user(db_url)
    headers = auth_headers(user_id)
    purchases["token-cross-01"] = google_purchase(user_id)
    verify(client, headers, "token-cross-01")
    assert client.post("/api/v1/payments/flutterwave/checkout", headers=headers,
                       json={"plan_id": "premium_monthly"}).status_code == 409
    cancel = client.post("/api/v1/subscription/cancel", headers=headers)
    assert cancel.status_code == 409 and cancel.json()["detail"]["code"] == "manage_with_google_play"


def push(client, message_id, notification):
    data = base64.b64encode(json.dumps(notification).encode()).decode()
    return client.post("/api/v1/payments/google/notifications", headers={"Authorization": "Bearer oidc"},
                       json={"message": {"messageId": message_id, "data": data}, "subscription": "projects/x/subscriptions/y"})


def test_rtdn_lifecycle_hold_refund_and_replacement(client, db_url, fake_google, monkeypatch):
    purchases, _ = fake_google
    monkeypatch.setattr(google_play, "push_request_is_authentic", lambda authorization: authorization == "Bearer oidc")
    user_id = create_user(db_url)
    headers = auth_headers(user_id)
    assert client.post("/api/v1/payments/google/notifications", json={}).status_code == 401

    purchases["token-rtdn-001"] = google_purchase(user_id)
    notice = {"packageName": "site.enchiridion.app",
              "subscriptionNotification": {"notificationType": 4, "purchaseToken": "token-rtdn-001"}}
    assert push(client, "m1", notice).json()["status"] == "processed"
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["premium"] is True
    assert push(client, "m1", notice).json() == {"status": "duplicate"}

    purchases["token-rtdn-001"] = google_purchase(user_id, state="SUBSCRIPTION_STATE_ON_HOLD", acknowledged=True, days=-1)
    push(client, "m2", notice)
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["premium"] is False

    purchases["token-rtdn-002"] = google_purchase(user_id, order="GPA.9-1", linked="token-rtdn-001")
    push(client, "m3", {"packageName": "site.enchiridion.app",
                        "subscriptionNotification": {"notificationType": 4, "purchaseToken": "token-rtdn-002"}})
    rows = {row["provider_reference"]: row for row in fetch(
        db_url, "SELECT provider_reference, internal_state, superseded_by FROM billing.subscriptions")}
    assert rows["token-rtdn-001"]["superseded_by"] is not None
    assert rows["token-rtdn-002"]["internal_state"] == "ACTIVE"

    purchases["token-rtdn-002"] = google_purchase(user_id, state="SUBSCRIPTION_STATE_EXPIRED", order="GPA.9-1",
                                                  acknowledged=True, days=-1)
    push(client, "m4", {"packageName": "site.enchiridion.app", "voidedPurchaseNotification": {
        "purchaseToken": "token-rtdn-002", "orderId": "GPA.9-1", "productType": 1, "refundType": 1}})
    assert fetch(db_url, "SELECT internal_state FROM billing.subscriptions WHERE provider_reference = 'token-rtdn-002'")[0]["internal_state"] == "REFUNDED"
    assert fetch(db_url, "SELECT verification_status FROM billing.payments WHERE reference = 'GPA.9-1'")[0]["verification_status"] == "refunded"
    assert push(client, "m5", {"packageName": "other.app", "testNotification": {}}).json()["status"] == "ignored"


def test_rtdn_before_app_verification_binds_by_account_id(client, db_url, fake_google, monkeypatch):
    purchases, acknowledge = fake_google
    monkeypatch.setattr(google_play, "push_request_is_authentic", lambda authorization: True)
    user_id = create_user(db_url)
    purchases["token-early-01"] = google_purchase(user_id)
    push(client, "early", {"packageName": "site.enchiridion.app",
                           "subscriptionNotification": {"notificationType": 4, "purchaseToken": "token-early-01"}})
    assert fetch(db_url, "SELECT user_id FROM billing.subscriptions")[0]["user_id"] == user_id
    assert verify(client, auth_headers(user_id), "token-early-01").json()["premium"] is True
    assert acknowledge.await_count == 1


def test_offer_email_requires_consent_and_honours_unsubscribe(client, db_url, monkeypatch):
    monkeypatch.setattr(mailer, "is_configured", lambda: True)
    consenting = create_user(db_url, "yes@example.com", marketing_opt_in="true")
    create_user(db_url, "no@example.com")
    create_user(db_url, "app@example.com", signup_source="android_app", marketing_opt_in="true")
    outbox = fetch(db_url, "SELECT recipient, kind FROM enchiridion_web.email_outbox")
    assert outbox == [{"recipient": "yes@example.com", "kind": "premium_offer"}]
    token = fetch(db_url, "SELECT unsubscribe_token FROM public.communication_preferences WHERE user_id = %s", (consenting,))[0]["unsubscribe_token"]
    assert client.post("/api/v1/communications/unsubscribe", json={"token": str(token)}).status_code == 200
    assert client.post("/api/v1/communications/dispatch-mine", headers=auth_headers(consenting)).json()["sent"] == 0
    assert fetch(db_url, "SELECT status FROM enchiridion_web.email_outbox")[0]["status"] == "skipped"
    prefs = client.get("/api/v1/communications/preferences", headers=auth_headers(consenting)).json()
    assert prefs["marketing_opt_in"] is False and prefs["transactional_email_enabled"] is True
    events = fetch(db_url, "SELECT granted, source FROM public.communication_consent_events WHERE user_id = %s ORDER BY id", (consenting,))
    assert [(row["granted"], row["source"]) for row in events] == [(True, "web_signup"), (False, "unsubscribe_link")]


def test_offer_email_is_sent_with_unsubscribe_link(client, db_url, monkeypatch):
    monkeypatch.setattr(mailer, "is_configured", lambda: True)
    user_id = create_user(db_url, "yes@example.com", marketing_opt_in="true")
    assert client.post("/api/v1/communications/dispatch-mine", headers=auth_headers(user_id)).json()["sent"] == 1
    recipient, subject, body, headers = mailer.send_email.await_args.args
    assert recipient == "yes@example.com"
    assert subject == "Your Enchiridion account is ready. Explore Premium."
    assert "₦1,500" in body and "₦15,000" in body and "Save ₦3,000" in body and "/unsubscribe?token=" in body
    assert headers["List-Unsubscribe"].startswith("<http")


def test_manual_grants_and_admin_refunds(client, db_url, fake_flutterwave):
    user_id = create_user(db_url)
    headers = auth_headers(user_id)
    with psycopg.connect(db_url) as db:
        db.execute("SELECT billing.grant_manual_entitlement('reader@example.com', 'premium', null, 'QA')")
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["entitlements"][0]["source"] == "manual"
    with psycopg.connect(db_url) as db:
        db.execute("SELECT billing.revoke_manual_entitlement('reader@example.com')")
    subscribe_on_website(client, fake_flutterwave, headers)
    subscription_id = fetch(db_url, "SELECT id FROM billing.subscriptions")[0]["id"]
    assert client.post(f"/api/v1/admin/subscriptions/{subscription_id}/refunded", headers=headers,
                       json={"reason": "Duplicate"}).status_code == 403
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE enchiridion_web.partners SET is_superuser = true")
    assert client.post(f"/api/v1/admin/subscriptions/{subscription_id}/refunded", headers=headers,
                       json={"reason": "Duplicate"}).status_code == 200
    assert client.get("/api/v1/subscription/entitlements", headers=headers).json()["premium"] is False
    assert fetch(db_url, "SELECT actor FROM billing.subscription_transitions ORDER BY id DESC LIMIT 1")[0]["actor"].startswith("admin:")
