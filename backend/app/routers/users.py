"""Website profile for the signed-in Supabase account."""

from fastapi import APIRouter, Depends
from psycopg import sql

from ..auth import CurrentUser, current_active_user
from ..database import get_db
from ..models import UserUpdate
from ..rewards import sync_verified_partner

router = APIRouter()
DB = Depends(get_db, scope="function")
USER = Depends(current_active_user)
PROFILE_FIELDS = ("name", "state", "country", "profession", "phone", "institution")


async def profile(db, user: CurrentUser) -> dict:
    row = await (await db.execute("SELECT * FROM partners WHERE id = %s", (user.id,))).fetchone()
    return {
        "id": str(user.id), "email": user.email, "is_verified": user.is_verified,
        "is_superuser": user.is_superuser, "is_active": user.is_active,
        "referral_code": row["referral_code"], "referred_by": row["referred_by"],
        "date_joined": row["date_joined"].isoformat(),
        **{field: row[field] for field in PROFILE_FIELDS},
    }


@router.get("/me")
async def me(user: CurrentUser = USER, db=DB):
    await sync_verified_partner(db, user)
    return await profile(db, user)


@router.patch("/me")
async def update_me(body: UserUpdate, user: CurrentUser = USER, db=DB):
    changes = body.model_dump(exclude_none=True)
    if changes:
        await db.execute(
            sql.SQL("UPDATE partners SET {} WHERE id = %s").format(
                sql.SQL(", ").join(sql.SQL("{} = %s").format(sql.Identifier(key)) for key in changes),
            ),
            (*changes.values(), user.id),
        )
    return await profile(db, user)
