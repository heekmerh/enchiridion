from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class UserRead(BaseModel):
    id: str
    email: EmailStr
    is_active: bool = True
    is_superuser: bool = False
    is_verified: bool = False
    name: str
    referral_code: str
    date_joined: datetime

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str
    referral_code: str

class UserUpdate(BaseModel):
    password: Optional[str] = None
    email: Optional[EmailStr] = None
    name: Optional[str] = None

class ActivityLog(BaseModel):
    type: str
    refCode: str
    points: float
    timestamp: str
    details: dict

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
