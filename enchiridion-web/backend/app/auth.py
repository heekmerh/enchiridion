"""Supabase Auth session verification shared by the website and the Flutter app."""

import os
import uuid
from dataclasses import dataclass
from functools import lru_cache

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .database import get_db

SUPABASE_AUDIENCE = "authenticated"
ASYMMETRIC_ALGORITHMS = ("RS256", "ES256")

bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentUser:
    id: uuid.UUID
    email: str
    name: str
    referral_code: str
    referred_by: str | None
    is_verified: bool
    is_superuser: bool
    is_active: bool


def supabase_url():
    return os.getenv("SUPABASE_URL", "").rstrip("/")


@lru_cache(maxsize=4)
def jwks_client(base_url: str):
    return jwt.PyJWKClient(f"{base_url}/auth/v1/.well-known/jwks.json", cache_keys=True, lifespan=3600)


def signing_key(token: str, algorithm: str):
    if algorithm == "HS256":
        secret = os.getenv("SUPABASE_JWT_SECRET", "")
        if not secret:
            raise HTTPException(503, "Session verification is not configured")
        return secret
    if algorithm in ASYMMETRIC_ALGORITHMS:
        base_url = supabase_url()
        if not base_url:
            raise HTTPException(503, "Session verification is not configured")
        try:
            return jwks_client(base_url).get_signing_key_from_jwt(token).key
        except jwt.PyJWTError as exc:
            raise HTTPException(401, "Invalid session") from exc
    raise HTTPException(401, "Invalid session")


def decode_access_token(token: str) -> dict:
    try:
        algorithm = jwt.get_unverified_header(token).get("alg", "")
    except jwt.PyJWTError as exc:
        raise HTTPException(401, "Invalid session") from exc
    key = signing_key(token, algorithm)
    base_url = supabase_url()
    try:
        return jwt.decode(
            token, key, algorithms=[algorithm], audience=SUPABASE_AUDIENCE,
            issuer=f"{base_url}/auth/v1" if base_url else None,
            options={"require": ["exp", "sub"], "verify_iss": bool(base_url)},
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(401, "Session expired or invalid") from exc


async def ensure_partner(db, user_id):
    await db.execute(
        """INSERT INTO partners(id, email, referral_code, is_verified)
           SELECT u.id, lower(trim(u.email)), substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
                  u.email_confirmed_at IS NOT NULL
           FROM auth.users u WHERE u.id = %s AND u.email IS NOT NULL
           ON CONFLICT DO NOTHING""",
        (user_id,),
    )
    await db.execute("INSERT INTO onboarding(user_id) VALUES (%s) ON CONFLICT DO NOTHING", (user_id,))


async def load_user(db, user_id) -> CurrentUser | None:
    query = """SELECT u.id, lower(u.email) AS email, u.email_confirmed_at IS NOT NULL AS is_verified,
                      p.id AS partner_id, coalesce(p.name, '') AS name, coalesce(p.referral_code, '') AS referral_code,
                      p.referred_by, coalesce(p.is_superuser, false) AS is_superuser,
                      coalesce(p.is_active, true) AS is_active
               FROM auth.users u LEFT JOIN partners p ON p.id = u.id
               WHERE u.id = %s AND u.email IS NOT NULL"""
    row = await (await db.execute(query, (user_id,))).fetchone()
    if row and row["partner_id"] is None:
        await ensure_partner(db, user_id)
        row = await (await db.execute(query, (user_id,))).fetchone()
    if not row:
        return None
    return CurrentUser(
        id=row["id"], email=row["email"], name=row["name"], referral_code=row["referral_code"],
        referred_by=row["referred_by"], is_verified=row["is_verified"],
        is_superuser=row["is_superuser"], is_active=row["is_active"],
    )


async def optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db=Depends(get_db, scope="function"),
) -> CurrentUser | None:
    if not credentials or credentials.scheme.lower() != "bearer":
        return None
    claims = decode_access_token(credentials.credentials)
    try:
        user_id = uuid.UUID(claims["sub"])
    except ValueError as exc:
        raise HTTPException(401, "Invalid session") from exc
    user = await load_user(db, user_id)
    if not user:
        raise HTTPException(401, "Account not found")
    if not user.is_active:
        raise HTTPException(403, "Account is disabled")
    return user


async def current_active_user(user: CurrentUser | None = Depends(optional_user)) -> CurrentUser:
    if not user:
        raise HTTPException(401, "Sign in required")
    return user


async def current_active_superuser(user: CurrentUser = Depends(current_active_user)) -> CurrentUser:
    if not user.is_superuser:
        raise HTTPException(403, "Admin access required")
    return user
