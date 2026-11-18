"""Account deletion through DELETE /api/v1/account."""

import psycopg

from tests.conftest import auth_headers, create_user, fetch
from tests.test_billing import (  # noqa: F401
    fake_flutterwave, fake_google, google_purchase, subscribe_on_website, verify,
)


def test_deletion_requires_sign_in(client):
    assert client.delete("/api/v1/account").status_code == 401


def test_deletion_removes_the_account_and_its_study_data(client, db_url):
    user_id = create_user(db_url)
    with psycopg.connect(db_url) as db:
        db.execute("INSERT INTO public.notebook_entries(user_id, id, content) VALUES (%s, 'n1', 'note')", (user_id,))
        db.execute("INSERT INTO enchiridion_web.leads(kind, email) VALUES ('newsletter', 'Reader@example.com')")
    response = client.delete("/api/v1/account", headers=auth_headers(user_id))
    assert response.status_code == 200, response.text
    assert fetch(db_url, "SELECT id FROM auth.users WHERE id = %s", (user_id,)) == []
    assert fetch(db_url, "SELECT id FROM public.profiles WHERE id = %s", (user_id,)) == []
    assert fetch(db_url, "SELECT id FROM enchiridion_web.partners WHERE id = %s", (user_id,)) == []
    assert fetch(db_url, "SELECT user_id FROM public.notebook_entries WHERE user_id = %s", (user_id,)) == []
    assert fetch(db_url, "SELECT id FROM enchiridion_web.leads") == []


def test_website_subscription_is_cancelled_and_payment_records_kept(client, db_url, fake_flutterwave):
    user_id = create_user(db_url)
    subscribe_on_website(client, fake_flutterwave, auth_headers(user_id))
    response = client.delete("/api/v1/account", headers=auth_headers(user_id))
    assert response.status_code == 200, response.text
    assert any(path.endswith("/cancel") for _, path, _, _ in fake_flutterwave.requests)
    subscription = fetch(db_url, "SELECT user_id, auto_renewing FROM billing.subscriptions")[0]
    assert subscription == {"user_id": None, "auto_renewing": False}
    assert len(fetch(db_url, "SELECT id FROM billing.payments")) == 1


def test_renewing_google_play_subscription_must_be_cancelled_first(client, db_url, fake_google):
    purchases, _ = fake_google
    user_id = create_user(db_url)
    purchases["token-delete-01"] = google_purchase(user_id)
    assert verify(client, auth_headers(user_id), "token-delete-01").status_code == 200
    response = client.delete("/api/v1/account", headers=auth_headers(user_id))
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "cancel_google_play_first"
    assert "play.google.com" in response.json()["detail"]["url"]
    assert fetch(db_url, "SELECT id FROM auth.users WHERE id = %s", (user_id,)) != []


def test_cancelled_google_play_subscription_does_not_block_deletion(client, db_url, fake_google):
    purchases, _ = fake_google
    user_id = create_user(db_url)
    purchases["token-delete-02"] = google_purchase(user_id, state="SUBSCRIPTION_STATE_CANCELED")
    assert verify(client, auth_headers(user_id), "token-delete-02").status_code == 200
    assert client.delete("/api/v1/account", headers=auth_headers(user_id)).status_code == 200


def test_referral_payouts_block_deletion(client, db_url):
    user_id = create_user(db_url)
    client.get("/users/me", headers=auth_headers(user_id))
    with psycopg.connect(db_url) as db:
        db.execute("INSERT INTO enchiridion_web.payouts(partner_id, amount) VALUES (%s, 500)", (user_id,))
    response = client.delete("/api/v1/account", headers=auth_headers(user_id))
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "payouts_on_record"
