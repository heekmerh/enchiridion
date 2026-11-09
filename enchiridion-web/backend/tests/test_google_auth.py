import time
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.billing import google_play

AUDIENCE = "https://api.enchiridion.site/api/v1/payments/google/notifications"
PUSH_ACCOUNT = "rtdn-push@enchiridion.iam.gserviceaccount.com"


@pytest.fixture
def signing_key(monkeypatch):
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setenv("GOOGLE_RTDN_AUDIENCE", AUDIENCE)
    monkeypatch.setenv("GOOGLE_RTDN_SERVICE_ACCOUNT", PUSH_ACCOUNT)
    jwks = SimpleNamespace(get_signing_key_from_jwt=lambda token: SimpleNamespace(key=key.public_key()))
    monkeypatch.setattr(google_play, "google_jwks", lambda: jwks)
    return key


def push_token(key, **overrides):
    claims = {"iss": "https://accounts.google.com", "aud": AUDIENCE, "email": PUSH_ACCOUNT,
              "email_verified": True, "exp": int(time.time()) + 300, **overrides}
    return "Bearer " + jwt.encode(claims, key, algorithm="RS256")


def test_genuine_pubsub_push_is_accepted(signing_key):
    assert google_play.push_request_is_authentic(push_token(signing_key))


@pytest.mark.parametrize("overrides", [
    {"aud": "https://attacker.example"},
    {"email": "someone-else@example.com"},
    {"email_verified": False},
    {"iss": "https://evil.example"},
    {"exp": int(time.time()) - 10},
])
def test_forged_or_misdirected_push_is_rejected(signing_key, overrides):
    assert not google_play.push_request_is_authentic(push_token(signing_key, **overrides))


def test_push_signed_by_another_key_is_rejected(signing_key):
    stranger = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    assert not google_play.push_request_is_authentic(push_token(stranger))
    assert not google_play.push_request_is_authentic("")


def test_google_state_mapping_withholds_access_when_payment_is_on_hold():
    assert google_play.GOOGLE_STATES["SUBSCRIPTION_STATE_IN_GRACE_PERIOD"] == "GRACE_PERIOD"
    assert google_play.GOOGLE_STATES["SUBSCRIPTION_STATE_ON_HOLD"] == "PAYMENT_FAILED"
    assert google_play.GOOGLE_STATES["SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED"] == "EXPIRED"
