"""Shared fixtures for tests against a disposable local Postgres built from supabase_stub.sql and the master schema."""

import os
import time
import uuid
from unittest.mock import AsyncMock
from urllib.parse import urlparse

import jwt
import psycopg
import pytest
from fastapi.testclient import TestClient
from psycopg.rows import dict_row

from app import mailer
from app.database import get_db
from app.main import app

TEST_JWT_SECRET = "test-only-supabase-jwt-secret-0123456789abcdef"
RESET_TABLES = (
    "billing.settlements", "billing.payments", "billing.payment_events", "billing.entitlements",
    "billing.subscription_transitions", "billing.subscriptions", "billing.checkout_sessions",
    "enchiridion_web.leads", "enchiridion_web.reviews", "enchiridion_web.payments",
    "enchiridion_web.purchase_orders", "enchiridion_web.shipping_rates", "enchiridion_web.broadcasts",
    "enchiridion_web.email_outbox", "enchiridion_web.audit_logs", "enchiridion_web.activities",
    "enchiridion_web.payouts", "enchiridion_web.milestones",
)


@pytest.fixture
def db_url(monkeypatch):
    url = os.getenv("TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set TEST_DATABASE_URL to a disposable local Postgres database")
    parsed = urlparse(url)
    assert parsed.hostname in ("127.0.0.1", "localhost")
    assert parsed.path == "/enchiridion_test"
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", TEST_JWT_SECRET)
    monkeypatch.setattr(mailer, "send_email", AsyncMock(return_value=True))
    with psycopg.connect(url, autocommit=True) as db:
        db.execute("ALTER TABLE billing.plan_prices DISABLE TRIGGER plan_prices_immutable")
        db.execute("TRUNCATE " + ", ".join(RESET_TABLES) + " CASCADE")
        db.execute("DELETE FROM billing.provider_plan_mappings WHERE provider = 'flutterwave'")
        db.execute("DELETE FROM billing.plan_prices WHERE change_reason NOT LIKE 'Launch price%'")
        db.execute("UPDATE billing.plan_prices SET effective_to = NULL")
        db.execute("ALTER TABLE billing.plan_prices ENABLE TRIGGER plan_prices_immutable")
        db.execute("DELETE FROM auth.users")
    return url


@pytest.fixture
def client(db_url):
    async def database():
        async with await psycopg.AsyncConnection.connect(db_url, row_factory=dict_row) as db:
            async with db.transaction():
                await db.execute("SET LOCAL search_path = enchiridion_web, public")
                yield db
    app.dependency_overrides[get_db] = database
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def create_user(db_url, email="reader@example.com", verified=True, **metadata) -> uuid.UUID:
    user_id = uuid.uuid4()
    meta = {"name": "Test Reader", "signup_source": "web", **metadata}
    with psycopg.connect(db_url) as db:
        db.execute(
            "INSERT INTO auth.users(id, email, raw_user_meta_data) VALUES (%s, %s, %s)",
            (user_id, email, psycopg.types.json.Jsonb(meta)),
        )
        if verified:
            db.execute("UPDATE auth.users SET email_confirmed_at = now() WHERE id = %s", (user_id,))
    return user_id


def auth_headers(user_id, expires_in=3600, secret=TEST_JWT_SECRET) -> dict:
    token = jwt.encode({"sub": str(user_id), "aud": "authenticated", "role": "authenticated",
                        "exp": int(time.time()) + expires_in}, secret, algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}


def fetch(db_url, query, params=()):
    with psycopg.connect(db_url, row_factory=dict_row) as db:
        return db.execute(query, params).fetchall()
