from pydantic import BaseModel, EmailStr, Field
from typing import Optional


class UserUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    state: Optional[str] = Field(default=None, max_length=100)
    country: Optional[str] = Field(default=None, max_length=100)
    profession: Optional[str] = Field(default=None, max_length=100)
    phone: Optional[str] = Field(default=None, max_length=40)
    institution: Optional[str] = Field(default=None, max_length=200)


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
    rating: int = Field(ge=1, le=5)
    text: str = Field(min_length=1, max_length=10000)

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
