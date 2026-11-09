"""Flutterwave v3 API client; every payment fact is fetched here with the secret key, never taken from a browser."""

import base64
import hashlib
import hmac
import os

import httpx
from fastapi import HTTPException

API_BASE = "https://api.flutterwave.com/v3"


def secret_key():
    value = os.getenv("FLUTTERWAVE_SECRET_KEY", "")
    if not value:
        raise HTTPException(503, "Flutterwave is not configured")
    return value


async def call(method: str, path: str, *, json: dict | None = None, params: dict | None = None) -> dict:
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.request(
                method, f"{API_BASE}{path}", json=json, params=params,
                headers={"Authorization": f"Bearer {secret_key()}"},
            )
            response.raise_for_status()
            payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(502, "Flutterwave is temporarily unavailable") from exc
    if payload.get("status") != "success":
        raise HTTPException(502, "Flutterwave rejected the request")
    return payload


async def fetch_transaction(transaction_id) -> dict:
    payload = await call("GET", f"/transactions/{int(transaction_id)}/verify")
    data = payload.get("data")
    if not isinstance(data, dict) or str(data.get("id")) != str(transaction_id):
        raise HTTPException(502, "Flutterwave returned an unexpected transaction")
    return data


async def fetch_transaction_by_reference(reference: str) -> dict | None:
    try:
        payload = await call("GET", "/transactions/verify_by_reference", params={"tx_ref": reference})
    except HTTPException as exc:
        if exc.status_code == 502:
            return None
        raise
    data = payload.get("data")
    return data if isinstance(data, dict) and data.get("tx_ref") == reference else None


async def verify_transaction(transaction_id) -> dict:
    data = await fetch_transaction(transaction_id)
    if data.get("status") != "successful":
        raise HTTPException(400, "Payment has not succeeded")
    return data


def webhook_is_authentic(raw_body: bytes, headers) -> bool:
    secret = os.getenv("FLUTTERWAVE_WEBHOOK_SECRET", "")
    if not secret:
        raise HTTPException(503, "Flutterwave webhook is not configured")
    signature = headers.get("flutterwave-signature")
    if signature:
        expected = base64.b64encode(hmac.new(secret.encode(), raw_body, hashlib.sha256).digest()).decode()
        return hmac.compare_digest(signature, expected)
    # Flutterwave v3 accounts send the configured secret hash itself in verif-hash.
    return hmac.compare_digest(headers.get("verif-hash", ""), secret)
