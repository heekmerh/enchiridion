"""Book checkout totals and lead emails: what the site shows must be what the server charges and sends."""

import pytest

from app import delivery
from app.billing import notifications
from app import mailer
from tests.conftest import fetch

ORDER = {"email": "guest@example.com", "fullName": "Reader", "address": "1 Test Street", "city": "Kano",
         "phone": "+2348000000000", "quantity": 1}


def test_delivery_rules():
    assert delivery.delivery_cost("Kano") == 1500
    assert delivery.delivery_cost("kano", "pickup") == 0
    assert delivery.delivery_cost("Abuja") == 1500
    assert delivery.delivery_cost("Kaduna") == 3000
    assert delivery.delivery_cost("Delta") == 5000
    with pytest.raises(ValueError):
        delivery.delivery_cost("Kaduna", "pickup")
    with pytest.raises(delivery.UnknownState):
        delivery.delivery_cost("Atlantis")
    assert len(delivery.all_states()) == 37


def test_checkout_config_publishes_the_rules_the_server_charges(client, db_url, monkeypatch):
    monkeypatch.setenv("BOOK_PRICE_NGN", "10000")
    config = client.get("/referral/checkout-config").json()
    assert config["bookPrice"] == 10000
    assert config["delivery"]["hubDeliveryCost"] == 1500
    assert "Kano" in config["delivery"]["hubStates"]
    rates = {r["name"]: r["cost"] for r in client.get("/referral/shipping-rates").json()}
    assert rates["Kano"] == 1500 and rates["Delta"] == 5000


@pytest.mark.parametrize("state,fulfillment,amount", [
    ("Kano", "delivery", 11500),
    ("Kano", "pickup", 10000),
    ("Federal Capital Territory (Abuja)", "delivery", 11500),
    ("Kaduna", "delivery", 13000),
    ("Enugu", "delivery", 15000),
])
def test_order_total_is_book_plus_delivery(client, db_url, monkeypatch, state, fulfillment, amount):
    monkeypatch.setenv("FLUTTERWAVE_SECRET_KEY", "test-only")
    monkeypatch.setenv("BOOK_PRICE_NGN", "10000")
    response = client.post("/referral/initialize-purchase", json={**ORDER, "state": state, "fulfillment": fulfillment})
    assert response.status_code == 200, response.text
    order = response.json()
    assert order["amount"] == amount
    assert order["bookPrice"] + order["deliveryCost"] == amount
    assert fetch(db_url, "SELECT amount FROM enchiridion_web.purchase_orders")[0]["amount"] == amount


def test_pickup_outside_a_hub_and_unknown_states_are_refused(client, db_url, monkeypatch):
    monkeypatch.setenv("FLUTTERWAVE_SECRET_KEY", "test-only")
    assert client.post("/referral/initialize-purchase",
                       json={**ORDER, "state": "Kaduna", "fulfillment": "pickup"}).status_code == 400
    assert client.post("/referral/initialize-purchase", json={**ORDER, "state": "Atlantis"}).status_code == 400
    assert fetch(db_url, "SELECT count(*) AS count FROM enchiridion_web.purchase_orders")[0]["count"] == 0


def test_distributor_application_queues_a_support_alert(client, db_url):
    response = client.post("/referral/distributor-lead", json={
        "name": "Ada", "phone": "08012345678", "whatsapp": "08012345678", "location": "Makurdi"})
    assert response.status_code == 200
    rows = fetch(db_url, "SELECT kind, recipient, payload FROM enchiridion_web.email_outbox")
    assert len(rows) == 1
    assert rows[0]["kind"] == "support_alert"
    assert rows[0]["recipient"] == mailer.support_email()
    assert rows[0]["payload"]["fields"]["Location"] == "Makurdi"
    notifications.deliver_lead_emails.assert_called()


def test_newsletter_queues_one_welcome_per_address(client, db_url):
    for _ in range(2):
        assert client.post("/referral/subscribe-newsletter",
                           json={"email": "Reader@Example.com", "refCode": "ha3328"}).status_code == 200
    welcomes = fetch(db_url, "SELECT recipient FROM enchiridion_web.email_outbox WHERE kind = 'newsletter_welcome'")
    assert [row["recipient"] for row in welcomes] == ["reader@example.com"]
    alerts = fetch(db_url, "SELECT count(*) AS count FROM enchiridion_web.email_outbox WHERE kind = 'support_alert'")
    assert alerts[0]["count"] == 2
    leads = fetch(db_url, "SELECT ref_code FROM enchiridion_web.leads WHERE kind = 'newsletter'")
    assert {row["ref_code"] for row in leads} == {"ha3328"}


@pytest.mark.asyncio
async def test_queued_lead_emails_are_sent_and_retried(db_url, monkeypatch):
    import psycopg
    from psycopg.rows import dict_row
    from unittest.mock import AsyncMock
    monkeypatch.setenv("MAIL_USERNAME", "sender@example.com")
    monkeypatch.setenv("MAIL_PASSWORD", "test-only")
    send = AsyncMock(side_effect=[False, True, True])
    monkeypatch.setattr(mailer, "send_email", send)
    async with await psycopg.AsyncConnection.connect(db_url, row_factory=dict_row) as db:
        await db.execute("SET search_path = enchiridion_web, public")
        await notifications.enqueue_newsletter_welcome(db, "reader@example.com")
        await notifications.enqueue_support_alert(db, subject="New distributor application",
                                                  fields={"Name": "<b>Ada</b>"}, dedupe_key="lead:test")
        first = await notifications.dispatch(db, kind="support_alert")
        assert first == {"sent": 0, "skipped": 0, "failed": 1}
        assert await notifications.dispatch(db, kind="support_alert") == {"sent": 1, "skipped": 0, "failed": 0}
        assert await notifications.dispatch(db, kind="newsletter_welcome") == {"sent": 1, "skipped": 0, "failed": 0}
        await db.commit()
    recipient, subject, body, headers = send.await_args.args
    assert recipient == "reader@example.com"
    assert subject == "Welcome to Enchiridion emails"
    assert "unsubscribe" in headers["List-Unsubscribe"]
    alert_body = send.await_args_list[1].args[2]
    assert "&lt;b&gt;Ada&lt;/b&gt;" in alert_body
    statuses = fetch(db_url, "SELECT status FROM enchiridion_web.email_outbox ORDER BY kind")
    assert [row["status"] for row in statuses] == ["sent", "sent"]
