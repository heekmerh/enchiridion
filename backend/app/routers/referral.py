from fastapi import APIRouter, Depends, HTTPException
from ..models import ActivityLog, PayoutSettings
from ..sheets import sheets_client
from ..auth import current_active_user, UserRead
from datetime import datetime

router = APIRouter()

@router.post("/log-activity")
async def log_activity(activity: ActivityLog):
    # Map to ActivityLog sheet columns: Timestamp, ReferralCode, ActivityType, Points, URL
    row = [
        activity.timestamp,
        activity.refCode,
        activity.type,
        activity.points,
        activity.details.get("url", "")
    ]
    sheets_client.append_row("ActivityLog", row)
    return {"success": True}

@router.get("/stats")
async def get_stats(user: UserRead = Depends(current_active_user)):
    # Fetch user stats from Partners sheet
    # This would involve summing up points from ActivityLog filtered by user's refCode
    # For MVP, we can return what's in the Partners sheet
    records = sheets_client.get_all_records("Partners")
    for record in records:
        if record.get("Email Address") == user.email:
            return {
                "points": record.get("Points", 0),
                "revenue": record.get("Revenue (₦)", 0),
                "referralCode": record.get("ReferralCode", "")
            }
    raise HTTPException(status_code=404, detail="Stats not found")

@router.post("/update-payout")
async def update_payout(settings: PayoutSettings, user: UserRead = Depends(current_active_user)):
    # Ensure user is updating their own payout or has permission
    # Headers: ReferralCode, AccountName, AccountNumber, BankName
    row = [
        settings.refCode,
        settings.accountName,
        settings.accountNumber,
        settings.bankName
    ]
    sheets_client.append_row("PayoutSettings", row)
    return {"success": True}
