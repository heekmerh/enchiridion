"""Marketing consent and unsubscribe handling, kept separate from essential account email."""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..auth import CurrentUser, current_active_user
from ..billing import notifications
from ..database import get_db

router = APIRouter()
DB = Depends(get_db, scope="function")
USER = Depends(current_active_user)


def serialize(row: dict) -> dict:
    return {
        "marketing_opt_in": row["marketing_opt_in"] and row["marketing_unsubscribed_at"] is None,
        "marketing_consent_at": row["marketing_consent_at"].isoformat() if row["marketing_consent_at"] else None,
        "transactional_email_enabled": row["transactional_email_enabled"],
        "signup_source": row["signup_source"],
    }


async def preferences_row(db, user_id) -> dict:
    await db.execute("INSERT INTO public.communication_preferences(user_id) VALUES (%s) ON CONFLICT DO NOTHING", (user_id,))
    return await (await db.execute(
        "SELECT * FROM public.communication_preferences WHERE user_id = %s FOR UPDATE", (user_id,),
    )).fetchone()


async def set_marketing_consent(db, user_id, granted: bool, source: str, region: str = ""):
    await db.execute(
        """UPDATE public.communication_preferences
           SET marketing_opt_in = %s,
               marketing_consent_source = CASE WHEN %s THEN %s ELSE marketing_consent_source END,
               marketing_consent_region = CASE WHEN %s THEN %s ELSE marketing_consent_region END,
               marketing_consent_at = CASE WHEN %s THEN now() ELSE marketing_consent_at END,
               marketing_unsubscribed_at = CASE WHEN %s THEN NULL ELSE now() END,
               updated_at = now()
           WHERE user_id = %s""",
        (granted, granted, source, granted, region, granted, granted, user_id),
    )
    await db.execute(
        "INSERT INTO public.communication_consent_events(user_id, granted, source, region) VALUES (%s, %s, %s, %s)",
        (user_id, granted, source, region),
    )


@router.get("/preferences")
async def get_preferences(user: CurrentUser = USER, db=DB):
    return serialize(await preferences_row(db, user.id))


class PreferencesUpdate(BaseModel):
    marketing_opt_in: bool
    region: str = Field(default="", max_length=80)


@router.put("/preferences")
async def update_preferences(body: PreferencesUpdate, user: CurrentUser = USER, db=DB):
    row = await preferences_row(db, user.id)
    currently_opted_in = row["marketing_opt_in"] and row["marketing_unsubscribed_at"] is None
    if body.marketing_opt_in != currently_opted_in:
        await set_marketing_consent(db, user.id, body.marketing_opt_in, "web_account", body.region)
    return serialize(await preferences_row(db, user.id))


class UnsubscribeRequest(BaseModel):
    token: uuid.UUID


@router.post("/unsubscribe")
async def unsubscribe(body: UnsubscribeRequest, db=DB):
    row = await (await db.execute(
        "SELECT user_id, marketing_opt_in FROM public.communication_preferences WHERE unsubscribe_token = %s FOR UPDATE",
        (body.token,),
    )).fetchone()
    if not row:
        raise HTTPException(404, "This unsubscribe link is not valid")
    if row["marketing_opt_in"]:
        await set_marketing_consent(db, row["user_id"], False, "unsubscribe_link")
    await db.execute(
        "UPDATE email_outbox SET status = 'skipped', last_error = 'Unsubscribed' WHERE user_id = %s AND status = 'pending' AND kind = ANY(%s)",
        (row["user_id"], list(notifications.MARKETING_KINDS)),
    )
    return {"unsubscribed": True, "message": "You won't receive further Enchiridion offers. Account and billing emails continue."}


@router.post("/dispatch-mine")
async def dispatch_mine(user: CurrentUser = USER, db=DB):
    return await notifications.dispatch(db, user_id=user.id, limit=5)
