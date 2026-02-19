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
from .models import User, UserRead, UserCreate, UserUpdate
import os
from datetime import datetime
from dotenv import load_dotenv
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType

# Load .env from the backend directory
env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
load_dotenv(env_path)


SECRET = os.getenv("AUTH_SECRET", "SECRET")
print(f"DEBUG: Auth secret loaded. Length: {len(SECRET)}. Starts with: {SECRET[:4]}...")

# Email Configuration
conf = ConnectionConfig(
    MAIL_USERNAME=os.getenv("MAIL_USERNAME", ""),
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD", ""),
    MAIL_FROM=os.getenv("MAIL_FROM", "admin@enchiridion.xyz"),
    MAIL_PORT=int(os.getenv("MAIL_PORT", 587)),
    MAIL_SERVER=os.getenv("MAIL_SERVER", "smtp.gmail.com"),
    MAIL_FROM_NAME=os.getenv("MAIL_FROM_NAME", "Enchiridion Admin"),
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)

# Email Configuration
conf = ConnectionConfig(
    MAIL_USERNAME=os.getenv("MAIL_USERNAME", ""),
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD", ""),
    MAIL_FROM=os.getenv("MAIL_FROM", "admin@enchiridion.xyz"),
    MAIL_PORT=int(os.getenv("MAIL_PORT", 587)),
    MAIL_SERVER=os.getenv("MAIL_SERVER", "smtp.gmail.com"),
    MAIL_FROM_NAME=os.getenv("MAIL_FROM_NAME", "Enchiridion Admin"),
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)


class GoogleSheetsUserDatabase(BaseUserDatabase[User, uuid.UUID]):
    def __init__(self, user_model, id_type):
        self.user_model = user_model
        self.id_type = id_type

    async def get(self, id: uuid.UUID) -> Optional[User]:
        import asyncio
        records = await asyncio.to_thread(sheets_client.get_all_records, "Partners")
        for record in records:
            try:
                user_dict = self._to_user_dict(record)
                if user_dict.get("id") == id:
                    return User.model_validate(user_dict)
            except Exception:
                continue
        return None

    async def get_by_email(self, email: str) -> Optional[User]:
        import asyncio
        print(f"DEBUG: Searching for user with email: '{email}'")
        records = await asyncio.to_thread(sheets_client.get_all_records, "Partners")
        print(f"DEBUG: Found {len(records)} total records in Partners sheet.")
        
        if records:
            # Keys check removed to avoid UnicodeEncodeError in some environments
            pass
        
        target_email = email.lower().strip()
        for record in records:
            # Try to find a key that looks like "Email Address", "email", or "username"
            record_email = None
            for key, value in record.items():
                if key.lower().replace(" ", "") in ["emailaddress", "email", "username"]:
                    record_email = str(value).lower().strip()
                    break
            
            if record_email == target_email:
                # print(f"DEBUG: Match found for {email} in sheet record.") # Removed to avoid encoding issues
                try:
                    user_dict = self._to_user_dict(record)
                    return User.model_validate(user_dict)
                except Exception as e:
                    print(f"DEBUG: Error validating user record: {e}")
                    return None


        print(f"DEBUG: No match found for {email} after checking all records.")
        return None

    async def create(self, user_dict: dict) -> User:
        print(f"DEBUG: Creating user in Google Sheets: {user_dict.get('email')}")
        # Generate ID if not present
        if "id" not in user_dict:
            user_dict["id"] = uuid.uuid4()
            
        # Ensure default values for boolean flags
        user_dict.setdefault("is_active", True)
        user_dict.setdefault("is_superuser", False)
        user_dict.setdefault("is_verified", False)
        
        # Map to the strict column structure (Feb 19 Evening Update):
        # A: USERNAME, B: PASSWORD, C: FULL NAME, D: REFERRAL CODE, 
        # E: POINTS, F: REVENUE (₦), G: LIFETIME EARNINGS, H: TOTAL REFERRALS, 
        # I: PAYOUT STATUS, J: BANK NAME, K: ACCOUNT NAME, L: ACCOUNT NUMBER, 
        # M: REFERRED_BY, N: REGISTRATION_IP, O: DATE_JOINED, 
        # P: is_superuser, Q: is_active, R: is_verified

        now = datetime.now()
        row = [
            user_dict["email"],             # A: USERNAME
            user_dict["hashed_password"],  # B: PASSWORD
            user_dict.get("name", ""),      # C: FULL NAME
            user_dict.get("referral_code", ""), # D: REFERRAL CODE
            0.0,                            # E: POINTS
            0.0,                            # F: REVENUE (\u20a6)
            0.0,                            # G: LIFETIME EARNINGS
            0,                              # H: TOTAL REFERRALS
            "PENDING",                       # I: PAYOUT STATUS
            user_dict.get("bank_name", ""), # J: BANK NAME
            user_dict.get("account_name", ""), # K: ACCOUNT NAME
            user_dict.get("account_number", ""), # L: ACCOUNT NUMBER
            user_dict.get("referred_by", ""),# M: REFERRED_BY
            user_dict.get("ip", ""),         # N: REGISTRATION_IP
            now.isoformat(),                 # O: DATE_JOINED
            "FALSE",                         # P: is_superuser
            "TRUE",                          # Q: is_active
            "FALSE"                          # R: is_verified
        ]
        
        try:
            sheets_client.append_row("Partners", row)

            user_dict["date_joined"] = now
            print(f"DEBUG: Successfully created user {user_dict['email']} in sheet with expanded columns.")
            return User.model_validate(user_dict)
        except Exception as e:
            print(f"DEBUG: Failed to create user in sheet: {e}")
            raise e

    async def update(self, user: User, update_dict: dict) -> User:
        print(f"DEBUG: Updating user {user.email} in sheet with: {list(update_dict.keys())}")
        
        # 1. Find user in sheet by Email (A)
        records = sheets_client.get_all_records("Partners")
        row_idx = None
        for i, record in enumerate(records):
            # Check Column A (USERNAME)
            if str(record.get("USERNAME", "")).lower().strip() == user.email.lower().strip():
                row_idx = i + 2 # 1-indexed + header
                break
        
        if not row_idx:
            print(f"ERROR: Could not find user {user.email} to update.")
            raise Exception("User not found in sheet for update")

        # 2. Update relevant cells
        # Columns based on auth.py mapping:
        # B: PASSWORD (1-indexed: 2)
        # P: is_superuser (16)
        # Q: is_active (17)
        # R: is_verified (18)
        
        try:
            if "hashed_password" in update_dict:
                sheets_client.update_cell("Partners", row_idx, 2, update_dict["hashed_password"])
            
            if "is_superuser" in update_dict:
                sheets_client.update_cell("Partners", row_idx, 16, "TRUE" if update_dict["is_superuser"] else "FALSE")
            
            if "is_active" in update_dict:
                sheets_client.update_cell("Partners", row_idx, 17, "TRUE" if update_dict["is_active"] else "FALSE")
                
            if "is_verified" in update_dict:
                sheets_client.update_cell("Partners", row_idx, 18, "TRUE" if update_dict["is_verified"] else "FALSE")

            # Update in-memory user
            user_dict = user.model_dump()
            user_dict.update(update_dict)
            return User.model_validate(user_dict)
        except Exception as e:
            print(f"ERROR: Failed to update sheet: {e}")
            raise e


    async def delete(self, user: User) -> None:
        pass

    def _to_user_dict(self, record):
        # Helper to find value by case-insensitive key
        def get_val(r, *keys):
            for k in keys:
                # Direct match
                if k in r: return r[k]
                # Case-insensitive match
                for rk in r.keys():
                    if rk.lower().strip() == k.lower().strip() or rk.lower().replace(" ", "") == k.lower().replace(" ", ""):
                        return r[rk]
            return None

        # Determine email first as it's used for fallbacks
        val = get_val(record, "Email Address", "Email", "USERNAME")
        email = str(val if val is not None else "").strip()


        # Handle DateJoined parsing with fallback
        date_joined = get_val(record, "DateJoined", "Date Joined", "Timestamp")
        if isinstance(date_joined, str) and date_joined:
            try:
                date_joined = datetime.fromisoformat(date_joined)
            except ValueError:
                date_joined = datetime.now()
        else:
            date_joined = datetime.now()

        hashed_password = get_val(record, "Password", "hashed_password")
        
        # Handle ID with deterministic fallback if column is missing
        user_id_str = get_val(record, "id", "UUID")
        if user_id_str:
            try:
                user_id = uuid.UUID(str(user_id_str))
            except ValueError:
                import hashlib
                user_id = uuid.UUID(hashlib.md5(email.encode()).hexdigest())
        else:
            # Create a consistent ID based on email if sheet is missing the ID column
            import hashlib
            user_id = uuid.UUID(hashlib.md5(email.encode()).hexdigest())

        return {
            "id": user_id,
            "email": email,
            "hashed_password": hashed_password,
            "is_active": str(get_val(record, "is_active", "active") or "TRUE").upper() == "TRUE",
            "is_superuser": str(get_val(record, "is_superuser", "superuser") or "FALSE").upper() == "TRUE",
            "is_verified": str(get_val(record, "is_verified", "verified") or "FALSE").upper() == "TRUE",
            "name": get_val(record, "Name", "Full Name") or "",
            "referral_code": get_val(record, "ReferralCode", "Referral Code") or "",
            "referred_by": get_val(record, "REFERRED_BY", "referred_by") or "",
            "date_joined": date_joined
        }


def safe_float(v):
    """Robust conversion of sheet values (strings/None/numbers) to float."""
    if v is None:
        return 0.0
    if isinstance(v, (int, float)):
        return float(v)
    # Clean string: remove currency symbols, commas, and whitespace
    # Replace longer codes first to avoid partial matches (e.g., NGN before N)
    clean_v = str(v).replace("NGN", "").replace("\u20a6", "").replace(",", "").replace("$", "").replace("N", "").strip()


    if not clean_v:
        return 0.0
    try:
        return float(clean_v)
    except (ValueError, TypeError):
        return 0.0

def get_user_db():
    yield GoogleSheetsUserDatabase(User, uuid.UUID)

class UserManager(UUIDIDMixin, BaseUserManager[User, uuid.UUID]):
    reset_password_token_secret = SECRET
    verification_token_secret = SECRET

    async def on_after_register(self, user: User, request: Optional[Request] = None):
        print(f"DEBUG: User {user.email} registered. Checking referral...")
        
        # 1. Check if referred_by exists
        # Note: Depending on how User object is populated, referred_by might be in user_dict
        # or we might need to check the raw request data if it's not in the model.
        # But we added it to UserRead and User object should have it if coming from UserCreate.
        referred_by = getattr(user, "referred_by", None)
        
        if referred_by:
            print(f"DEBUG: User was referred by {referred_by}. Attempting to credit...")
            
            # 2. Fraud Prevention: Self-referral check (Email)
            # Find referrer by code
            records = sheets_client.get_all_records("Partners")
            referrer_record = None
            referrer_row_idx = None
            
            for i, record in enumerate(records):
                if str(record.get("REFERRAL CODE", "")).strip().lower() == referred_by.strip().lower():
                    referrer_record = record
                    referrer_row_idx = i + 2 # 1-indexed + header
                    break
            
            if referrer_record:
                referrer_email = str(referrer_record.get("USERNAME", "")).lower().strip()
                if referrer_email == user.email.lower().strip():
                    print(f"WARNING: Self-referral detected for {user.email}. Skipping credit.")
                    return

                # 3. Credit Referrer (0.1 Points) using robust safe_float
                try:
                    current_points = safe_float(referrer_record.get("POINTS", 0.0))
                    new_points = round(current_points + 0.1, 2)
                    new_revenue = round(new_points * 100, 2)
                    
                    # Atomic update of columns E (Points) and F (Revenue)
                    sheets_client.update_range("Partners", f"E{referrer_row_idx}:F{referrer_row_idx}", [[new_points, new_revenue]])
                    
                    # 4. Log Activity
                    activity_row = [
                        datetime.now().isoformat(),
                        referred_by,
                        "Registration",
                        0.1,
                        f"New signup: {user.email}",
                        "", # F: REPORTED Status
                        "PENDING" # G: Payout Status
                    ]
                    sheets_client.append_row("ActivityLog", activity_row)
                    
                    print(f"DEBUG: Successfully credited {referred_by} with 0.1 points for {user.email}")
                except Exception as e:
                    print(f"ERROR: Failed to credit referrer: {e}")
            else:
                print(f"WARNING: Referrer with code {referred_by} not found.")
        else:
            print("DEBUG: No referral code provided for this registration.")

    async def on_after_forgot_password(
        self, user: User, token: str, request: Optional[Request] = None
    ):
        print(f"DEBUG: Forgot password triggered for {user.email}")
        
        # Determine the reset URL (Production vs Local)
        # In a real app, you'd use the request origin or a config variable
        # For Enchiridion, the frontend is usually on port 3000
        reset_link = f"http://localhost:3000/reset-password?token={token}"
        
        html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
            <h2 style="color: #0f172a; margin-bottom: 24px;">Password Reset Request</h2>
            <p style="color: #475569; line-height: 1.6;">Hello,</p>
            <p style="color: #475569; line-height: 1.6;">We received a request to reset your password for your Enchiridion Partner account. Click the button below to set a new password:</p>
            <div style="margin: 32px 0;">
                <a href="{reset_link}" style="background-color: #ef4444; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600; display: inline-block;">Reset Password</a>
            </div>
            <p style="color: #475569; line-height: 1.6; font-size: 14px;">If you didn't request this, you can safely ignore this email.</p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 24px 0;">
            <p style="color: #94a3b8; font-size: 12px;">Enchiridion Medical Handbook & Companion</p>
        </div>
        """

        message = MessageSchema(
            subject="Enchiridion - Password Reset Request",
            recipients=[user.email],
            body=html,
            subtype=MessageType.html
        )

        fm = FastMail(conf)
        try:
            await fm.send_message(message)
            print(f"DEBUG: Reset email sent successfully to {user.email}")
        except Exception as e:
            print(f"ERROR: Failed to send reset email: {e}")


    async def on_after_reset_password(
        self, user: User, request: Optional[Request] = None
    ):
        print(f"DEBUG: Password successfully reset for {user.email}")


    async def on_after_request_verify(
        self, user: User, token: str, request: Optional[Request] = None
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

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_manager,
    [auth_backend],
)

current_active_user = fastapi_users.current_user(active=True)
current_active_superuser = fastapi_users.current_user(active=True, superuser=True)
