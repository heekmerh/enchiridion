from fastapi_users import schemas
import uuid
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class User(schemas.BaseUser[uuid.UUID]):
    name: str
    referral_code: str
    referred_by: Optional[str] = None
    date_joined: datetime
    hashed_password: str
    state: Optional[str] = None
    country: Optional[str] = None
    profession: Optional[str] = None
    phone: Optional[str] = None
    institution: Optional[str] = None

class UserRead(schemas.BaseUser[uuid.UUID]):
    name: str
    referral_code: str
    referred_by: Optional[str] = None
    date_joined: datetime
    state: Optional[str] = None
    country: Optional[str] = None
    profession: Optional[str] = None
    phone: Optional[str] = None
    institution: Optional[str] = None

class UserCreate(schemas.BaseUserCreate):
    name: str
    referral_code: str
    referred_by: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    profession: Optional[str] = None
    phone: Optional[str] = None
    institution: Optional[str] = None

class UserUpdate(schemas.BaseUserUpdate):
    name: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    profession: Optional[str] = None
    phone: Optional[str] = None
    institution: Optional[str] = None

class ActivityLog(BaseModel):
    type: str
    refCode: str
    points: float
    timestamp: str
    details: dict
    payoutStatus: str = "PENDING"

class MarkAsPaidRequest(BaseModel):
    email: str
    refCode: str

class ReviewBase(BaseModel):
    name: str
    jobTitle: str
    organization: Optional[str] = None
    rating: int
    text: str

class ReviewCreate(ReviewBase):
    pass

class Review(ReviewBase):
    id: str
    status: str
    createdAt: str
    approvedAt: Optional[str] = None

class PayoutSettings(BaseModel):
    refCode: str
    accountName: str
    accountNumber: str
    bankName: str

class SessionTrack(BaseModel):
    refCode: str
    ip: str
    userAgent: str

class LeadCapture(BaseModel):
    email: EmailStr
    refCode: str
    timestamp: Optional[str] = None
    details: Optional[dict] = None
    referred_by: Optional[str] = None # Added for consistency

class DistributorLead(BaseModel):
    name: str
    phone: str
    whatsapp: str
    location: str
    timestamp: Optional[str] = None
    refCode: Optional[str] = None # Capture referrer
class ShareTrack(BaseModel):
    refCode: str
    platform: str

class UserProgress(BaseModel):
    email: str
    is_verified: bool = False
    is_partner: bool = False
    is_distributor: bool = False
    has_purchased_book: bool = False
    last_updated: Optional[str] = None
