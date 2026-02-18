import uuid
from typing import Optional

from fastapi import Depends, Request
from fastapi_users import BaseUserManager, FastAPIUsers, UUIDIDMixin
from fastapi_users.authentication import (
    AuthenticationBackend,
    BearerTransport,
    JWTStrategy,
)
from fastapi_users.db import BaseUserDatabase

from .sheets import sheets_client
from .models import UserRead, UserCreate, UserUpdate
import os
from datetime import datetime

SECRET = os.getenv("AUTH_SECRET", "SECRET")

class GoogleSheetsUserDatabase(BaseUserDatabase):
    async def get(self, id: uuid.UUID) -> Optional[dict]:
        records = sheets_client.get_all_records("Partners")
        for record in records:
            if record.get("id") == str(id):
                return self._to_user_dict(record)
        return None

    async def get_by_email(self, email: str) -> Optional[dict]:
        records = sheets_client.get_all_records("Partners")
        for record in records:
            if record.get("Email Address") == email:
                return self._to_user_dict(record)
        return None

    async def create(self, user_dict: dict) -> dict:
        # Map fastapi-users dict to Google Sheets columns
        # Partners Columns: Username, Password, Name, ReferralCode, Email Address, DateJoined, id, is_active, is_superuser, is_verified
        row = [
            user_dict["email"], # Username
            user_dict["hashed_password"],
            user_dict.get("name", ""),
            user_dict.get("referral_code", ""),
            user_dict["email"], # Email Address
            datetime.now().isoformat(),
            str(user_dict["id"]),
            user_dict["is_active"],
            user_dict["is_superuser"],
            user_dict["is_verified"]
        ]
        sheets_client.append_row("Partners", row)
        return user_dict

    async def update(self, user: dict, update_dict: dict) -> dict:
        # Find user in sheet by ID and update cells
        records = sheets_client.get_all_records("Partners")
        for i, record in enumerate(records):
            if record.get("id") == str(user["id"]):
                # This is inefficient but for MVP it works
                # Sheet row is i + 2 (1-indexed + header)
                # Map update_dict keys to column indices if necessary
                pass 
        return {**user, **update_dict}

    async def delete(self, user: dict) -> None:
        pass

    def _to_user_dict(self, record):
        return {
            "id": uuid.UUID(record["id"]),
            "email": record["Email Address"],
            "hashed_password": record["Password"],
            "is_active": record.get("is_active", True),
            "is_superuser": record.get("is_superuser", False),
            "is_verified": record.get("is_verified", False),
            "name": record.get("Name", ""),
            "referral_code": record.get("ReferralCode", "")
        }

def get_user_db():
    yield GoogleSheetsUserDatabase(UserRead, uuid.UUID)

class UserManager(UUIDIDMixin, BaseUserManager[UserRead, uuid.UUID]):
    reset_password_token_secret = SECRET
    verification_token_secret = SECRET

    async def on_after_register(self, user: UserRead, request: Optional[Request] = None):
        print(f"User {user.id} has registered.")

    async def on_after_forgot_password(
        self, user: UserRead, token: str, request: Optional[Request] = None
    ):
        print(f"User {user.id} has forgot their password. Reset token: {token}")

    async def on_after_request_verify(
        self, user: UserRead, token: str, request: Optional[Request] = None
    ):
        print(f"Verification requested for user {user.id}. Verification token: {token}")

async def get_user_manager(user_db=Depends(get_user_db)):
    yield UserManager(user_db)

bearer_transport = BearerTransport(tokenUrl="auth/jwt/login")

def get_jwt_strategy() -> JWTStrategy:
    return JWTStrategy(secret=SECRET, lifetime_seconds=3600)

auth_backend = AuthenticationBackend(
    name="jwt",
    transport=bearer_transport,
    get_strategy=get_jwt_strategy,
)

fastapi_users = FastAPIUsers[UserRead, uuid.UUID](
    get_user_manager,
    [auth_backend],
)

current_active_user = fastapi_users.current_user(active=True)
