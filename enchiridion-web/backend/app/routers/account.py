"""Permanent deletion of the signed-in account, shared by the Android app and the website."""

from fastapi import APIRouter, Depends, HTTPException

from ..auth import CurrentUser, current_active_user
from ..billing import flutterwave_billing, lifecycle
from ..database import get_db

router = APIRouter()
DB = Depends(get_db, scope="function")
USER = Depends(current_active_user)

CANCEL_GOOGLE_PLAY_FIRST = (
    "Your Premium subscription renews through Google Play. Cancel it in Google Play first, "
    "then delete your account, so you are not charged again."
)
PAYOUTS_ON_RECORD = (
    "This account has referral payouts on record that we must keep for our accounts. "
    "Email support@enchiridion.site and we will delete everything else."
)


async def renewing_subscriptions(db, user_id) -> list[dict]:
    return [subscription for subscription in await lifecycle.live_subscriptions(db, user_id)
            if subscription["auto_renewing"] and subscription["internal_state"] in lifecycle.RECURRING_LIVE_STATES]


@router.delete("/account")
async def delete_account(user: CurrentUser = USER, db=DB):
    await lifecycle.lock_user_billing(db, user.id)
    renewing = await renewing_subscriptions(db, user.id)
    for subscription in renewing:
        if subscription["provider"] == "google_play":
            raise HTTPException(409, {"code": "cancel_google_play_first", "message": CANCEL_GOOGLE_PLAY_FIRST,
                                      "url": lifecycle.google_play_management_url(subscription["provider_product_id"])})
    payouts = await (await db.execute(
        "SELECT 1 FROM enchiridion_web.payouts WHERE partner_id = %s LIMIT 1", (user.id,))).fetchone()
    if payouts:
        raise HTTPException(409, {"code": "payouts_on_record", "message": PAYOUTS_ON_RECORD})
    for subscription in renewing:
        await flutterwave_billing.cancel(db, subscription, f"user:{user.id}")
    await db.execute("DELETE FROM enchiridion_web.leads WHERE lower(email) = lower(%s)", (user.email,))
    await db.execute("DELETE FROM auth.users WHERE id = %s", (user.id,))
    return {"deleted": True}
