"""Nightly feedback digest emailed to the admin address, with SMTP replaced by a fake."""

from unittest.mock import AsyncMock

import psycopg
import pytest

from app import mailer
from tests.conftest import create_user, fetch

CRON = {"Authorization": "Bearer cron-secret"}
DIGEST = "/api/v1/internal/feedback-digest"


@pytest.fixture
def digest_env(monkeypatch):
    monkeypatch.setenv("CRON_SECRET", "cron-secret")
    monkeypatch.setenv("ADMIN_EMAIL", "Admin@Example.com")
    monkeypatch.setattr(mailer, "is_configured", lambda: True)


def add_feedback(db_url, user_id, message="The search box loses my text.", category="complaint", age="3 hours"):
    with psycopg.connect(db_url) as db:
        db.execute(
            """INSERT INTO public.app_feedback(user_id, category, message, platform, created_at)
               VALUES (%s, %s, %s, 'android', now() - %s::interval)""",
            (user_id, category, message, age),
        )


def rewind_digest_window(db_url, age="2 hours"):
    with psycopg.connect(db_url) as db:
        db.execute(
            """UPDATE enchiridion_web.email_outbox
               SET payload = jsonb_set(payload, '{through}', to_jsonb((now() - %s::interval)::text))
               WHERE kind = 'feedback_digest'""",
            (age,),
        )


def digest_statuses(db_url):
    return [row["status"] for row in fetch(
        db_url, "SELECT status FROM enchiridion_web.email_outbox WHERE kind = 'feedback_digest' ORDER BY created_at")]


def test_digest_requires_the_cron_secret(client, digest_env):
    assert client.get(DIGEST).status_code == 401
    assert client.get(DIGEST, headers={"Authorization": "Bearer wrong"}).status_code == 401


def test_quiet_day_sends_nothing(client, db_url, digest_env):
    body = client.get(DIGEST, headers=CRON).json()
    assert body == {"queued": False, "emails": {"sent": 0, "skipped": 0, "failed": 0}}
    mailer.send_email.assert_not_awaited()
    assert digest_statuses(db_url) == []


def test_digest_lists_every_message_for_the_admin_and_escapes_user_text(client, db_url, digest_env):
    first = create_user(db_url, "first@example.com")
    second = create_user(db_url, "second@example.com")
    add_feedback(db_url, first, "Please add <b>dark</b> mode.\nIt hurts at night.", "feature_request")
    add_feedback(db_url, second)
    assert client.get(DIGEST, headers=CRON).json()["emails"]["sent"] == 1
    recipient, subject, html_body, _ = mailer.send_email.await_args.args
    assert recipient == "admin@example.com"
    assert subject == "Enchiridion feedback: 2 new messages"
    assert "Feature request" in html_body and "Complaint" in html_body
    assert "first@example.com" in html_body and "second@example.com" in html_body
    assert "&lt;b&gt;dark&lt;/b&gt; mode.<br>It hurts at night." in html_body
    assert "<b>dark</b>" not in html_body
    assert digest_statuses(db_url) == ["sent"]


def test_second_delivery_of_the_cron_event_does_not_repeat_the_email(client, db_url, digest_env):
    add_feedback(db_url, create_user(db_url))
    client.get(DIGEST, headers=CRON)
    assert client.get(DIGEST, headers=CRON).json()["queued"] is False
    assert mailer.send_email.await_count == 1


def test_each_digest_covers_only_messages_since_the_last_one(client, db_url, digest_env):
    user_id = create_user(db_url)
    add_feedback(db_url, user_id, "Message from yesterday.")
    client.get(DIGEST, headers=CRON)
    rewind_digest_window(db_url)
    add_feedback(db_url, user_id, "Message from today.", age="1 hour")
    assert client.get(DIGEST, headers=CRON).json()["emails"]["sent"] == 1
    _, subject, html_body, _ = mailer.send_email.await_args.args
    assert subject == "Enchiridion feedback: 1 new message"
    assert "Message from today." in html_body and "Message from yesterday." not in html_body


def test_message_sent_in_the_final_minute_waits_for_the_next_digest(client, db_url, digest_env):
    add_feedback(db_url, create_user(db_url), age="0 seconds")
    assert client.get(DIGEST, headers=CRON).json()["queued"] is False
    assert mailer.send_email.await_count == 0


def test_undelivered_digest_is_retried_with_later_messages_in_one_email(client, db_url, digest_env, monkeypatch):
    user_id = create_user(db_url)
    add_feedback(db_url, user_id, "Message from the outage.")
    monkeypatch.setattr(mailer, "send_email", AsyncMock(return_value=False))
    assert client.get(DIGEST, headers=CRON).json()["emails"]["failed"] == 1
    assert digest_statuses(db_url) == ["pending"]
    add_feedback(db_url, user_id, "Message after the outage.", age="1 hour")
    delivered = AsyncMock(return_value=True)
    monkeypatch.setattr(mailer, "send_email", delivered)
    assert client.get(DIGEST, headers=CRON).json()["emails"]["sent"] == 1
    html_body = delivered.await_args.args[2]
    assert "Message from the outage." in html_body and "Message after the outage." in html_body
    assert delivered.await_count == 1
    assert digest_statuses(db_url) == ["sent"]


def test_morning_job_retries_an_undelivered_digest(client, db_url, digest_env, monkeypatch):
    add_feedback(db_url, create_user(db_url))
    monkeypatch.setattr(mailer, "send_email", AsyncMock(return_value=False))
    client.get(DIGEST, headers=CRON)
    delivered = AsyncMock(return_value=True)
    monkeypatch.setattr(mailer, "send_email", delivered)
    assert client.get("/api/v1/internal/jobs", headers=CRON).json()["emails"]["sent"] == 1
    assert digest_statuses(db_url) == ["sent"]


def test_digest_run_leaves_other_queued_email_for_the_morning_job(client, db_url, digest_env):
    user_id = create_user(db_url, "payer@example.com")
    add_feedback(db_url, user_id)
    with psycopg.connect(db_url) as db:
        db.execute(
            """INSERT INTO enchiridion_web.email_outbox(user_id, kind, recipient, dedupe_key)
               VALUES (%s, 'expiry', 'payer@example.com', 'expiry:test')""",
            (user_id,),
        )
    client.get(DIGEST, headers=CRON)
    assert mailer.send_email.await_args.args[0] == "admin@example.com"
    assert fetch(db_url, "SELECT status FROM enchiridion_web.email_outbox WHERE kind = 'expiry'") == [{"status": "pending"}]


def test_recipient_falls_back_to_the_sending_mailbox(client, db_url, digest_env, monkeypatch):
    monkeypatch.delenv("ADMIN_EMAIL")
    monkeypatch.setenv("MAIL_FROM", "hikma@example.com")
    add_feedback(db_url, create_user(db_url))
    client.get(DIGEST, headers=CRON)
    assert mailer.send_email.await_args.args[0] == "hikma@example.com"


def test_no_configured_address_queues_nothing(client, db_url, digest_env, monkeypatch):
    for name in ("ADMIN_EMAIL", "MAIL_FROM", "MAIL_USERNAME"):
        monkeypatch.delenv(name, raising=False)
    add_feedback(db_url, create_user(db_url))
    assert client.get(DIGEST, headers=CRON).json()["queued"] is False
    assert digest_statuses(db_url) == []
