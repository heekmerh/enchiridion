"""Website persistence against a disposable local Postgres; live Supabase URLs are rejected by the fixtures."""

import base64
import hashlib
import hmac
import json
from decimal import Decimal
from unittest.mock import AsyncMock

import psycopg
import pytest
from fastapi import HTTPException
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app import flutterwave
from app.database import get_db
from app.main import app
from app.rewards import credit, process_payment
from tests.conftest import auth_headers, create_user, fetch


def test_signup_trigger_creates_partner_profile(client, db_url):
    user_id = create_user(db_url, referral_code="reader", state="Lagos", country="Nigeria", profession="Doctor")
    headers = auth_headers(user_id)
    profile = client.get("/users/me", headers=headers).json()
    assert profile["id"] == str(user_id)
    assert profile["name"] == "Test Reader"
    assert profile["referral_code"] == "reader"
    assert profile["is_verified"] and not profile["is_superuser"]
    assert client.patch("/users/me", headers=headers, json={"name": "Updated Reader"}).json()["name"] == "Updated Reader"
    assert fetch(db_url, "SELECT name FROM enchiridion_web.partners")[0]["name"] == "Updated Reader"


def test_sessions_are_verified(client, db_url):
    user_id = create_user(db_url)
    assert client.get("/users/me").status_code == 401
    assert client.get("/users/me", headers=auth_headers(user_id, expires_in=-60)).status_code == 401
    assert client.get("/users/me", headers=auth_headers(user_id, secret="wrong-secret-wrong-secret-wrong-secret")).status_code == 401
    assert client.get("/users/me", headers={"Authorization": "Bearer not-a-jwt"}).status_code == 401


def test_signup_metadata_cannot_grant_admin_or_self_referral(client, db_url):
    user_id = create_user(db_url, is_superuser=True, referral_code="self", referred_by="self")
    profile = client.get("/users/me", headers=auth_headers(user_id)).json()
    assert not profile["is_superuser"]
    assert profile["referred_by"] is None


def test_verified_signup_rewards_referrer_once(client, db_url):
    referrer = create_user(db_url, "referrer@example.com", referral_code="ref")
    buyer = create_user(db_url, "buyer@example.com", referred_by="REF")
    for _ in range(2):
        assert client.get("/users/me", headers=auth_headers(buyer)).status_code == 200
    row = fetch(db_url, "SELECT points, total_referrals FROM enchiridion_web.partners WHERE id = %s", (referrer,))[0]
    assert row["points"] == Decimal("0.10") and row["total_referrals"] == 1


def test_google_signup_can_claim_a_referrer_once_while_new(client, db_url):
    referrer = create_user(db_url, "referrer@example.com", referral_code="ref")
    google_user = create_user(db_url, "google@example.com", signup_source="unknown")
    headers = auth_headers(google_user)
    assert client.post("/referral/claim-referrer", headers=headers, json={"refCode": "missing"}).json() == {"claimed": False}
    assert client.post("/referral/claim-referrer", headers=headers, json={"refCode": "REF"}).json() == {"claimed": True}
    assert client.post("/referral/claim-referrer", headers=headers, json={"refCode": "REF"}).json() == {"claimed": False}
    client.get("/users/me", headers=headers)
    assert fetch(db_url, "SELECT total_referrals FROM enchiridion_web.partners WHERE id = %s", (referrer,))[0]["total_referrals"] == 1
    old_user = create_user(db_url, "old@example.com")
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE enchiridion_web.partners SET date_joined = now() - interval '2 days' WHERE id = %s", (old_user,))
    assert client.post("/referral/claim-referrer", headers=auth_headers(old_user), json={"refCode": "ref"}).json() == {"claimed": False}


def test_unverified_accounts_cannot_claim_guest_purchases(client, db_url):
    with psycopg.connect(db_url) as db:
        db.execute("INSERT INTO enchiridion_web.purchase_orders(tx_ref,email,amount,quantity) VALUES ('guest-1','late@example.com',10000,1)")
        db.execute("INSERT INTO enchiridion_web.payments(reference,transaction_id,email,amount,currency) VALUES ('guest-1','77','late@example.com',10000,'NGN')")
    user_id = create_user(db_url, "late@example.com", verified=False)
    client.get("/users/me", headers=auth_headers(user_id))
    assert not fetch(db_url, "SELECT has_purchased_book FROM enchiridion_web.onboarding")[0]["has_purchased_book"]
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE auth.users SET email_confirmed_at = now() WHERE id = %s", (user_id,))
    client.get("/users/me", headers=auth_headers(user_id))
    assert fetch(db_url, "SELECT has_purchased_book FROM enchiridion_web.onboarding")[0]["has_purchased_book"]


def test_review_moderation_and_access_control(client, db_url):
    response = client.post("/reviews/", json={"name": "Reader", "jobTitle": "Doctor", "rating": 5, "text": "Useful reference"})
    assert response.status_code == 201
    review_id = response.json()["id"]
    assert client.get("/reviews/").json() == []
    assert client.get("/reviews/?admin=true").status_code == 403
    headers = auth_headers(create_user(db_url))
    assert client.put(f"/reviews/{review_id}?status=approved", headers=headers).status_code == 403
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE enchiridion_web.partners SET is_superuser = true")
    assert client.put(f"/reviews/{review_id}?status=approved", headers=headers).status_code == 200
    assert len(client.get("/reviews/").json()) == 1
    assert client.post("/reviews/", json={"name": "Reader", "jobTitle": "Doctor", "rating": 6, "text": "Bad rating"}).status_code == 422


def test_leads_are_committed(client, db_url):
    for route in ("capture-lead", "subscribe-newsletter"):
        assert client.post(f"/referral/{route}", json={"email": "lead@example.com", "refCode": "direct"}).status_code == 200
    assert client.post("/referral/distributor-lead", json={"name": "Distributor", "phone": "08012345678", "whatsapp": "08012345678", "location": "Lagos"}).status_code == 200
    assert fetch(db_url, "SELECT count(*) AS count FROM enchiridion_web.leads")[0]["count"] == 3


@pytest.mark.asyncio
async def test_rewards_are_idempotent_and_rollback(db_url):
    partner_id = create_user(db_url, "ref@example.com", referral_code="ref")
    async with await psycopg.AsyncConnection.connect(db_url, row_factory=dict_row) as db:
        await db.execute("SET search_path = enchiridion_web, public")
        assert await credit(db, partner_id, "buyer@example.com", "book_purchase", 5)
        assert not await credit(db, partner_id, "buyer@example.com", "book_purchase", 5)
        try:
            async with db.transaction():
                await credit(db, partner_id, "second@example.com", "book_purchase", 5)
                raise RuntimeError("Simulated failure before commit")
        except RuntimeError:
            pass
        row = await (await db.execute("SELECT points FROM partners WHERE id = %s", (partner_id,))).fetchone()
        assert row["points"] == Decimal("5")
        assert (await (await db.execute("SELECT count(*) AS count FROM milestones")).fetchone())["count"] == 1


@pytest.mark.asyncio
async def test_verified_payment_matches_order_and_retries_once(db_url):
    create_user(db_url, "ref@example.com", referral_code="ref")
    create_user(db_url, "buyer@example.com", referral_code="buyer", referred_by="ref")
    async with await psycopg.AsyncConnection.connect(db_url, row_factory=dict_row) as db:
        await db.execute("SET search_path = enchiridion_web, public")
        await db.execute("INSERT INTO purchase_orders(tx_ref,email,amount,quantity,metadata) VALUES ('order-1','buyer@example.com',10000,1,%s)", (Jsonb({"product": "book"}),))
        data = {"id": 123, "tx_ref": "order-1", "status": "successful", "currency": "NGN", "amount": 10000, "customer": {"email": "buyer@example.com"}}
        for changes in ({"amount": 1}, {"currency": "USD"}, {"status": "failed"}, {"customer": {"email": "wrong@example.com"}}, {"tx_ref": "missing"}):
            with pytest.raises(HTTPException):
                await process_payment(db, {**data, **changes})
        assert (await process_payment(db, data))["success"]
        assert (await process_payment(db, data))["already_processed"]
        balances = await (await db.execute("SELECT email, points FROM partners ORDER BY email")).fetchall()
        assert [row["points"] for row in balances] == [Decimal("1"), Decimal("5")]
        assert (await (await db.execute("SELECT count(*) AS count FROM payments")).fetchone())["count"] == 1


def test_supabase_browser_roles_have_no_private_schema_access(db_url):
    with psycopg.connect(db_url) as db:
        for role in ("anon", "authenticated"):
            for schema in ("enchiridion_web", "billing", "legacy"):
                assert db.execute("SELECT has_schema_privilege(%s, %s, 'USAGE')", (role, schema)).fetchone() == (False,)


def test_payout_reversal_preserves_new_earnings(client, db_url):
    headers = auth_headers(create_user(db_url, referral_code="reader"))
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE enchiridion_web.partners SET is_superuser=true,points=5")
    body = {"email": "reader@example.com", "refCode": "reader"}
    assert client.post("/referral/mark-as-paid", headers=headers, json=body).status_code == 200
    with psycopg.connect(db_url) as db:
        db.execute("UPDATE enchiridion_web.partners SET points=2")
    assert client.post("/referral/audit/revert-payout", headers=headers, json=body).status_code == 200
    assert client.post("/referral/audit/revert-payout", headers=headers, json=body).status_code == 409
    with psycopg.connect(db_url) as db:
        assert db.execute("SELECT points,lifetime_earnings FROM enchiridion_web.partners").fetchone() == (7, 0)


def test_book_order_webhook_verifies_signature_and_transaction(client, db_url, monkeypatch):
    monkeypatch.setenv("FLUTTERWAVE_WEBHOOK_SECRET", "test-webhook-secret")
    verified = AsyncMock(return_value={
        "id": 456, "tx_ref": "webhook-order", "status": "successful", "currency": "NGN",
        "amount": 13000, "customer": {"email": "guest@example.com"},
    })
    monkeypatch.setattr(flutterwave, "fetch_transaction", verified)
    with psycopg.connect(db_url) as db:
        db.execute("INSERT INTO enchiridion_web.purchase_orders(tx_ref,email,amount,quantity) VALUES ('webhook-order','guest@example.com',13000,1)")
    raw = json.dumps({"event": "charge.completed", "data": {"id": 456, "status": "successful"}}).encode()
    signature = base64.b64encode(hmac.new(b"test-webhook-secret", raw, hashlib.sha256).digest()).decode()
    assert client.post("/referral/flutterwave/webhook", content=raw).status_code == 401
    assert not verified.called
    response = client.post("/referral/flutterwave/webhook", content=raw, headers={"flutterwave-signature": signature})
    assert response.status_code == 200, response.text
    assert verified.await_count == 1
    duplicate = client.post("/api/v1/payments/flutterwave/webhook", content=raw, headers={"flutterwave-signature": signature})
    assert duplicate.json() == {"status": "duplicate"}
    assert fetch(db_url, "SELECT count(*) AS count FROM enchiridion_web.payments")[0]["count"] == 1
    assert fetch(db_url, "SELECT authentication FROM billing.payment_events ORDER BY received_at")[0]["authentication"] == "rejected"
    assert client.post("/referral/complete-purchase", json={"email": "guest@example.com"}).status_code == 422
    assert client.post("/referral/credit-purchase", json={}).status_code == 410
    assert client.post("/referral/webhook/payment-success", json={}).status_code == 410


def test_failed_commit_never_returns_success(client, db_url):
    async def failing_database():
        async with await psycopg.AsyncConnection.connect(db_url, row_factory=dict_row) as db:
            await db.execute("SET LOCAL search_path = enchiridion_web, public")
            yield db
            raise psycopg.OperationalError("Simulated commit failure")
    app.dependency_overrides[get_db] = failing_database
    response = client.post("/referral/capture-lead", json={"email": "rollback@example.com", "refCode": ""})
    assert response.status_code == 503
    assert fetch(db_url, "SELECT count(*) AS count FROM enchiridion_web.leads")[0]["count"] == 0


def test_book_checkout_uses_server_price_and_shipping(client, db_url, monkeypatch):
    monkeypatch.setenv("FLUTTERWAVE_SECRET_KEY", "test-only")
    monkeypatch.setenv("BOOK_PRICE_NGN", "10000")
    with psycopg.connect(db_url) as db:
        db.execute("INSERT INTO enchiridion_web.shipping_rates(name,cost) VALUES ('Lagos',3000)")
    body = {"email": "guest@example.com", "quantity": 2, "state": "Lagos", "fullName": "Reader",
            "address": "1 Test Street", "city": "Ikeja", "phone": "+2348000000000", "amount": 1}
    response = client.post("/referral/initialize-purchase", json=body)
    assert response.status_code == 200, response.text
    assert response.json()["amount"] == 23000
    row = fetch(db_url, "SELECT amount, metadata FROM enchiridion_web.purchase_orders")[0]
    assert row["amount"] == 23000
    assert row["metadata"]["address"] == "1 Test Street"
