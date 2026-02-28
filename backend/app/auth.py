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

# Frontend URL — set to production domain on Vercel
FRONTEND_URL = os.getenv("FRONTEND_URL", "https://enchiridion.ng").rstrip("/")

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
            record_email = sheets_client.get_case_insensitive_val(record, "USERNAME", "Email", "Email Address", "emailaddress")
            if str(record_email or "").lower().strip() == target_email:
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
            user_dict["email"],             # A: USERNAME (0)
            user_dict["hashed_password"],  # B: PASSWORD (1)
            user_dict.get("name", ""),      # C: FULL NAME (2)
            user_dict.get("referral_code", ""), # D: REFERRAL CODE (3)
            0.0,                            # E: POINTS (4)
            0.0,                            # F: REVENUE (₦) (5)
            0.0,                            # G: LIFETIME EARNINGS (6)
            0,                              # H: TOTAL REFERRALS (7)
            "PENDING",                       # I: PAYOUT STATUS (8)
            user_dict.get("bank_name", ""), # J: BANK NAME (9)
            user_dict.get("account_name", ""), # K: ACCOUNT NAME (10)
            user_dict.get("account_number", ""), # L: ACCOUNT NUMBER (11)
            user_dict.get("referred_by", ""),# M: REFERRED_BY (12)
            user_dict.get("ip", ""),         # N: REGISTRATION_IP (13)
            now.isoformat(),                 # O: DATE_JOINED (14)
            "FALSE",                         # P: is_superuser (15)
            "TRUE",                          # Q: is_active (16)
            "FALSE",                         # R: is_verified (17)
            0.0,                             # S: last payout amount (18)
            "",                              # T: EMPTY (19)
            "",                              # U: EMPTY (20)
            "",                              # V: Milestone 1 (21)
            "",                              # W: Milestone 2 (22)
            user_dict.get("state", ""),      # X: STATE (23)
            user_dict.get("country", ""),    # Y: COUNTRY (24)
            user_dict.get("profession", ""), # Z: PROFESSION (25)
            user_dict.get("phone", ""),      # AA: PHONE (26)
            user_dict.get("institution", "") # AB: INSTITUTION (27)
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
        # Removed local get_val as it is replaced by sheets_client helper

        # Determine email first as it's used for fallbacks
        val = sheets_client.get_case_insensitive_val(record, "USERNAME", "Email Address", "Email")
        email = str(val if val is not None else "").strip()


        # Handle DateJoined parsing with fallback
        date_joined = sheets_client.get_case_insensitive_val(record, "DateJoined", "Date Joined", "Timestamp")
        if isinstance(date_joined, str) and date_joined:
            try:
                date_joined = datetime.fromisoformat(date_joined)
            except ValueError:
                date_joined = datetime.now()
        else:
            date_joined = datetime.now()

        hashed_password = sheets_client.get_case_insensitive_val(record, "Password", "hashed_password")
        
        # Handle ID with deterministic fallback if column is missing
        user_id_str = sheets_client.get_case_insensitive_val(record, "id", "UUID")
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
            "is_active": str(sheets_client.get_case_insensitive_val(record, "is_active", "active", default="TRUE")).upper() == "TRUE",
            "is_superuser": str(sheets_client.get_case_insensitive_val(record, "is_superuser", "superuser", default="FALSE")).upper() == "TRUE",
            "is_verified": str(sheets_client.get_case_insensitive_val(record, "is_verified", "verified", default="FALSE")).upper() == "TRUE",
            "name": sheets_client.get_case_insensitive_val(record, "Name", "Full Name") or "",
            "referral_code": sheets_client.get_case_insensitive_val(record, "ReferralCode", "Referral Code") or "",
            "referred_by": sheets_client.get_case_insensitive_val(record, "REFERRED_BY", "referred_by") or "",
            "date_joined": date_joined,
            "state": sheets_client.get_case_insensitive_val(record, "STATE", "state") or "",
            "country": sheets_client.get_case_insensitive_val(record, "COUNTRY", "country") or "",
            "profession": sheets_client.get_case_insensitive_val(record, "PROFESSION", "profession") or "",
            "phone": sheets_client.get_case_insensitive_val(record, "PHONE", "phone") or "",
            "institution": sheets_client.get_case_insensitive_val(record, "INSTITUTION", "institution") or ""
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

    async def send_partner_welcome_email(self, user: User):
        """Sends a welcome email to a new partner with their referral link."""
        referral_link = f"https://enchiridion.ng/?ref={user.referral_code}"
        
        html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #4169E1; font-size: 24px; text-transform: uppercase; letter-spacing: 1px; margin: 0;">Enchiridion Partner Network</h1>
                <p style="color: #64748b; font-size: 14px; margin-top: 5px;">Medical Handbook & Companion</p>
            </div>
            
            <h2 style="color: #0f172a; margin-bottom: 20px;">Welcome, {user.name}!</h2>
            
            <p style="color: #334155; line-height: 1.6; font-size: 16px;">
                We are thrilled to have you join the Enchiridion Partner Network. Your account has been successfully created, and you are now part of an elite community shaping modern medical education.
            </p>
            
            <div style="background-color: #f8fafc; border: 2px solid #111827; padding: 24px; margin: 32px 0; text-align: center;">
                <p style="color: #64748b; font-size: 14px; text-transform: uppercase; font-weight: 800; margin-bottom: 12px;">Your Unique Referral Link</p>
                <div style="background: white; border: 1px solid #e2e8f0; padding: 12px; font-family: monospace; font-size: 18px; color: #111827; margin-bottom: 20px;">
                    {referral_link}
                </div>
                <a href="{FRONTEND_URL}/#login" style="background-color: #4169E1; color: white; padding: 14px 28px; border-radius: 0; text-decoration: none; font-weight: 800; display: inline-block; text-transform: uppercase; letter-spacing: 1px; box-shadow: 4px 4px 0px #111827;">
                    Login To Dashboard
                </a>
            </div>
            
            <p style="color: #334155; line-height: 1.6; font-size: 16px;">
                Start sharing your link to earn impactful rewards and help medical professionals and students access trusted knowledge.
            </p>
            
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 32px 0;">
            
            <div style="text-align: center; color: #94a3b8; font-size: 12px;">
                <p>© 2026 Enchiridion. All rights reserved.</p>
                <p>Ensuring medical excellence through tech-forward solutions.</p>
            </div>
        </div>
        """

        message = MessageSchema(
            subject="Welcome to the Enchiridion Partner Network!",
            recipients=[user.email],
            body=html,
            subtype=MessageType.html
        )

        fm = FastMail(conf)
        try:
            await fm.send_message(message)
            print(f"DEBUG: Welcome email sent successfully to {user.email}")
            
            # Update Admin Audit Execution Log
            log_row = [
                datetime.now().isoformat(),
                "Partner Onboarding",
                f"New Registration: {user.name} ({user.email})",
                "SUCCESS",
                f"Welcome Email sent to {user.email}"
            ]
            sheets_client.append_row("Admin Audit", log_row)
            
        except Exception as e:
            print(f"ERROR: Failed to send welcome email or log: {e}")
            # Try to log failure
            try:
                fail_row = [
                    datetime.now().isoformat(),
                    "Partner Onboarding",
                    f"New Registration: {user.name} ({user.email})",
                    "FAILED",
                    f"Error: {str(e)}"
                ]
                sheets_client.append_row("Admin Audit", fail_row)
            except:
                pass

    async def send_friend_joined_email(self, referrer_email: str, friend_name: str):
        """Notifies a referrer that their friend has successfully joined and they earned points."""
        html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #4169E1; font-size: 24px; text-transform: uppercase; letter-spacing: 1px; margin: 0;">Enchiridion Rewards</h1>
            </div>
            
            <h2 style="color: #0f172a; margin-bottom: 20px;">Good News!</h2>
            
            <p style="color: #334155; line-height: 1.6; font-size: 16px;">
                Your friend <strong>{friend_name}</strong> just successfully joined the Enchiridion Partner Network and verified their account!
            </p>
            
            <div style="background-color: #f0fdf4; border: 2px solid #16a34a; padding: 24px; margin: 32px 0; text-align: center;">
                <p style="color: #16a34a; font-size: 18px; font-weight: 800; margin: 0;">You've earned 0.1 Points (₦10)!</p>
            </div>
            
            <p style="color: #334155; line-height: 1.6; font-size: 16px;">
                Keep sharing your link to earn more rewards and help spread medical excellence.
            </p>
            
            <div style="text-align: center; margin-top: 30px;">
                <a href="{FRONTEND_URL}/#login" style="background-color: #4169E1; color: white; padding: 12px 24px; border-radius: 0; text-decoration: none; font-weight: 800; text-transform: uppercase;">
                    Check Your Dashboard
                </a>
            </div>
            
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 32px 0;">
            
            <div style="text-align: center; color: #94a3b8; font-size: 12px;">
                <p>© 2026 Enchiridion. All rights reserved.</p>
            </div>
        </div>
        """

        message = MessageSchema(
            subject="You just earned 10 Naira because your friend joined!",
            recipients=[referrer_email],
            body=html,
            subtype=MessageType.html
        )

        fm = FastMail(conf)
        try:
            await fm.send_message(message)
            print(f"DEBUG: Referral notification email sent to {referrer_email}")
        except Exception as e:
            print(f"ERROR: Failed to send referral notification: {e}")

    async def credit_referrer_conversion(self, referred_by: str, referee_email: str, referee_ip: str):
        """Credits the referrer when a referee completes verification."""
        print(f"DEBUG: Attempting to credit {referred_by} for conversion of {referee_email}...")
        
        # 1. Find referrer by code
        records = sheets_client.get_all_records("Partners")
        referrer_record = None
        referrer_row_idx = None
        
        for i, record in enumerate(records):
            ref_val = sheets_client.get_case_insensitive_val(record, "REFERRAL CODE", "ReferralCode", "referral_code")
            if str(ref_val or "").strip().lower() == referred_by.strip().lower():
                referrer_record = record
                referrer_row_idx = i + 2 # 1-indexed + header
                break
        
        if not referrer_record:
            print(f"WARNING: Referrer with code {referred_by} not found during conversion.")
            return

        referrer_email = str(sheets_client.get_case_insensitive_val(referrer_record, "USERNAME", "Email", "Email Address", default="")).lower().strip()
        
        # 2. Fraud Prevention: Self-referral check (Email)
        if referrer_email == referee_email.lower().strip():
            print(f"WARNING: Self-referral (email) detected for {referee_email}. Skipping credit.")
            sheets_client.log_audit("Fraud Check", f"Self-referral blocked: {referee_email}", "BLOCKED")
            return

        # 3. Fraud Prevention: IP Check
        # We fetch the referrer's IP from Column N (Index 13)
        referrer_ip = referrer_record.get("REGISTRATION_IP", "")
        if not referrer_ip:
             # Try absolute index check if header mapping failed
             row_data = sheets_client.get_worksheet("Partners").row_values(referrer_row_idx)
             if len(row_data) > 13:
                 referrer_ip = row_data[13]

        if referrer_ip == referee_ip and referee_ip != "unknown" and referee_ip != "":
            print(f"WARNING: Self-referral (IP: {referee_ip}) detected for {referee_email}. Skipping credit.")
            sheets_client.log_audit("Fraud Check", f"Self-referral IP block: {referee_email} matches referrer {referrer_email}", "BLOCKED")
            # return # Optional: some users might share IP in a hospital/school. Maybe just log it?
            # User requirement says "checks that the Referee is a new user (unique IP/Email) to prevent self-referral fraud"
            return 

        # 4. Credit Referrer (0.1 Points)
        try:
            p_val = sheets_client.get_case_insensitive_val(referrer_record, "POINTS", "points", "Pts")
            current_points = safe_float(p_val)
            new_points = round(current_points + 0.1, 2)
            new_revenue = round(new_points * 100, 2)
            
            # Atomic update of columns E (Points) and F (Revenue)
            sheets_client.update_range("Partners", f"E{referrer_row_idx}:F{referrer_row_idx}", [[new_points, new_revenue]])
            
            # 5. Log Activity
            activity_row = [
                datetime.now().isoformat(),
                referred_by,
                "Referral Conversion",
                0.1,
                f"Verified signup: {referee_email}",
                "", # F: REPORTED Status
                "PENDING" # G: Payout Status
            ]
            sheets_client.append_row("ActivityLog", activity_row)
            
            # 6. Notify Referrer
            import asyncio
            asyncio.create_task(self.send_friend_joined_email(referrer_email, referee_email.split("@")[0]))
            
            sheets_client.log_audit("Referral Credit", f"Credited {referred_by} for verification of {referee_email}")
            print(f"DEBUG: Successfully credited {referred_by} with 0.1 points for {referee_email}")
        except Exception as e:
            print(f"ERROR: Failed to credit referrer during conversion: {e}")
            sheets_client.log_audit("Referral Credit", f"Failed to credit {referred_by} for {referee_email}: {e}", "FAILED")

    async def on_after_register(self, user: User, request: Optional[Request] = None):
        print(f"DEBUG: User {user.email} registered. Triggering onboarding...")
        
        # Trigger Welcome Email and Logging
        import asyncio
        asyncio.create_task(self.send_partner_welcome_email(user))

        # 0. Initialize Onboarding Progress
        try:
            onboarding_row = [
                user.email,
                "FALSE", # IsVerified (even if registered, verification is a separate event)
                "FALSE", # IsPartner
                "FALSE", # IsDistributor
                "FALSE", # HasPurchasedBook
                datetime.now().isoformat()
            ]
            # Use get_or_create to ensure headers exist
            sheets_client.get_or_create_worksheet("UserOnboarding", ["Email", "IsVerified", "IsPartner", "IsDistributor", "HasPurchasedBook", "LastUpdated"])
            sheets_client.append_row("UserOnboarding", onboarding_row)
        except Exception as e:
            print(f"ERROR: Failed to initialize onboarding for {user.email}: {e}")

        # 1. Check if referred_by exists
        referred_by = getattr(user, "referred_by", None)
        
        if referred_by:
            print(f"DEBUG: User was referred by {referred_by}. Logging pending conversion...")
            
            # Log Pending Activity
            activity_row = [
                datetime.now().isoformat(),
                referred_by,
                "Registration",
                0.0, # 0 points until verified
                f"New signup (Pending Verification): {user.email}",
                "", # F: REPORTED Status
                "PENDING_VERIFICATION" # G: Payout Status / Internal Status
            ]
            sheets_client.append_row("ActivityLog", activity_row)
        else:
            print("DEBUG: No referral code provided for this registration.")

    async def record_milestone_and_credit(self, referrer_email: str, referee_email: str, milestone_type: str, points: float):
        """Records a unique milestone and credits the referrer if not already done."""
        unique_key = f"{referee_email.lower().strip()}_{milestone_type}"
        print(f"DEBUG: Recording milestone '{milestone_type}' for {referee_email} to credit {referrer_email}")

        # 1. Idempotency Check (Prevent double points)
        try:
            ws = sheets_client.get_or_create_worksheet("ReferralMilestones", ["Timestamp", "ReferrerEmail", "RefereeEmail", "MilestoneType", "PointsAwarded", "UniqueKey"])
            records = sheets_client.get_all_records("ReferralMilestones")
            for r in records:
                if str(r.get("UniqueKey", "")).lower().strip() == unique_key.lower().strip():
                    print(f"DEBUG: Milestone '{unique_key}' already recorded. Skipping.")
                    return
        except Exception as e:
            print(f"DEBUG: Milestone check error: {e}")

        # 2. Find Referrer in Partners Sheet
        records = sheets_client.get_all_records("Partners")
        referrer_record = None
        referrer_row_idx = None
        for i, r in enumerate(records):
            if str(r.get("USERNAME", "")).lower().strip() == referrer_email.lower().strip():
                referrer_record = r
                referrer_row_idx = i + 2
                break
        
        if not referrer_record:
            print(f"WARNING: Referrer {referrer_email} not found in Partners sheet.")
            return

        # 3. Apply Credit
        try:
            p_val = sheets_client.get_case_insensitive_val(referrer_record, "POINTS", "points", "Pts")
            current_points = safe_float(p_val)
            new_points = round(current_points + points, 2)
            new_revenue = round(new_points * 100, 2)
            
            sheets_client.update_range("Partners", f"E{referrer_row_idx}:F{referrer_row_idx}", [[new_points, new_revenue]])
            
            # 4. Record Milestone
            milestone_row = [
                datetime.now().isoformat(),
                referrer_email,
                referee_email,
                milestone_type,
                points,
                unique_key
            ]
            
            # Ensure worksheet exists
            sheets_client.get_or_create_worksheet("ReferralMilestones", ["Timestamp", "ReferrerEmail", "RefereeEmail", "MilestoneType", "PointsAwarded", "UniqueKey"])
            sheets_client.append_row("ReferralMilestones", milestone_row)

            # 5. Log Activity
            activity_label = {
                "partner": "Partner Onboarding",
                "distributor": "Distributor Setup",
                "network_spread": "Network Growth (Tier 2)",
                "book_purchase": "Book Purchase"
            }.get(milestone_type, milestone_type)

            activity_row = [
                datetime.now().isoformat(),
                referrer_record.get("REFERRAL CODE", "N/A"),
                activity_label,
                points,
                f"Referee: {referee_email}",
                "", 
                "PENDING"
            ]
            sheets_client.append_row("ActivityLog", activity_row)
            
            # 6. Notify Referrer
            asyncio.create_task(self.send_milestone_notification(referrer_email, referee_email.split("@")[0], milestone_type, points))
            
            print(f"DEBUG: Successfully credited {referrer_email} for milestone {milestone_type}")

        except Exception as e:
            print(f"ERROR: Failed to credit milestone: {e}")

    async def send_milestone_notification(self, email: str, friend_name: str, m_type: str, points: float):
        """Sends specific notification for various milestones."""
        subjects = {
            "partner": "New Friend Joined!",
            "distributor": "Distributor Lead Reward!",
            "network_spread": "Network Growth Reward!",
            "book_purchase": "Referral Purchase Reward!"
        }
        
        body_texts = {
            "partner": f"Your friend <strong>{friend_name}</strong> has joined the network!",
            "distributor": f"Your friend <strong>{friend_name}</strong> just applied to be a Distributor!",
            "network_spread": f"A friend of <strong>{friend_name}</strong> just joined! Your network is growing.",
            "book_purchase": f"Your friend <strong>{friend_name}</strong> just purchased a book!"
        }

        html = f"""
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
            <h2 style="color: #4169E1;">Enchiridion Rewards</h2>
            <p>{body_texts.get(m_type, "You've earned a reward!")}</p>
            <div style="background: #f8fafc; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
                <span style="font-size: 24px; font-weight: bold; color: #16a34a;">+ {points} Points (₦{int(points*100)})</span>
            </div>
            <p style="color: #64748b; font-size: 14px;">Log in to your dashboard to view your updated balance.</p>
        </div>
        """

        message = MessageSchema(
            subject=subjects.get(m_type, "New Referral Reward!"),
            recipients=[email],
            body=html,
            subtype=MessageType.html
        )
        fm = FastMail(conf)
        try:
            await fm.send_message(message)
        except Exception as e:
            print(f"DEBUG: Milestone email failed: {e}")

    async def on_after_verify(self, user: User, request: Optional[Request] = None):
        print(f"DEBUG: User {user.email} verified. Processing Milestones...")

        # Update Onboarding Progress Sheet
        try:
            records = sheets_client.get_all_records("UserOnboarding")
            row_idx = None
            for i, r in enumerate(records):
                if str(r.get("Email", "")).lower().strip() == user.email.lower().strip():
                    row_idx = i + 2
                    break
            
            if row_idx:
                sheets_client.update_cell("UserOnboarding", row_idx, 2, "TRUE")
                sheets_client.update_cell("UserOnboarding", row_idx, 6, datetime.now().isoformat())
            else:
                # If for some reason it's missing, create it
                onboarding_row = [user.email, "TRUE", "FALSE", "FALSE", "FALSE", datetime.now().isoformat()]
                sheets_client.append_row("UserOnboarding", onboarding_row)
        except Exception as e:
            print(f"ERROR: Failed to update onboarding verification for {user.email}: {e}")
        
        referred_by = getattr(user, "referred_by", None)
        if referred_by:
            # 1. Credit Referrer (Partner Onboarding)
            records = sheets_client.get_all_records("Partners")
            referrer_record = None
            for r in records:
                if str(r.get("REFERRAL CODE", "")).strip().lower() == referred_by.strip().lower():
                    referrer_record = r
                    break
            
            if referrer_record:
                referrer_email = str(referrer_record.get("USERNAME", "")).lower().strip()
                
                # Fraud Check (IP) - reuse existing logic if possible, or fetch from sheet
                referee_ip = "unknown" # Could fetch from user record if stored
                
                # Use the new milestone helper
                import asyncio
                # 0.1 for direct partner onboarding
                asyncio.create_task(self.record_milestone_and_credit(referrer_email, user.email, "partner", 0.1))
                
                # 2. Tier-2 Logic (Network Growth / User A)
                u_a_code = referrer_record.get("REFERRED_BY", "")
                if u_a_code:
                    u_a_record = None
                    for r in records:
                        if str(r.get("REFERRAL CODE", "")).strip().lower() == u_a_code.strip().lower():
                            u_a_record = r
                            break
                    if u_a_record:
                        u_a_email = str(u_a_record.get("USERNAME", "")).lower().strip()
                        # User A gets +0.1 for User C's verification via User B
                        asyncio.create_task(self.record_milestone_and_credit(u_a_email, user.email, "network_spread", 0.1))
        else:
            print(f"DEBUG: User {user.email} verified but has no referrer.")

    async def on_after_forgot_password(
        self, user: User, token: str, request: Optional[Request] = None
    ):
        print(f"DEBUG: Forgot password triggered for {user.email}")
        
        # Determine the reset URL (Production vs Local)
        # In a real app, you'd use the request origin or a config variable
        # For Enchiridion, the frontend is usually on port 3000
        reset_link = f"{FRONTEND_URL}/reset-password?token={token}"
        
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
