from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException

from ..auth import current_active_superuser, optional_user
from ..database import get_db
from ..models import ReviewCreate

router = APIRouter()


def serialize(row):
    return {
        "id": str(row["id"]), "name": row["name"], "jobTitle": row["job_title"],
        "organization": row["organization"], "rating": row["rating"], "text": row["text"],
        "status": row["status"], "createdAt": row["created_at"].isoformat(),
        "approvedAt": row["approved_at"].isoformat() if row["approved_at"] else None,
    }


@router.get("/")
async def get_reviews(admin: bool = False, user=Depends(optional_user), db=Depends(get_db, scope="function")):
    if admin and (not user or not user.is_superuser):
        raise HTTPException(403, "Admin access required")
    rows = await (await db.execute(
        "SELECT * FROM reviews WHERE (%s OR status = 'approved') ORDER BY created_at DESC", (admin,),
    )).fetchall()
    return [serialize(row) for row in rows]


@router.post("/", status_code=201)
async def submit_review(review: ReviewCreate, db=Depends(get_db, scope="function")):
    row = await (await db.execute(
        """INSERT INTO reviews(name, job_title, organization, rating, text)
           VALUES (%s, %s, %s, %s, %s) RETURNING id""",
        (review.name, review.jobTitle, review.organization or "", review.rating, review.text),
    )).fetchone()
    return {"message": "Review submitted successfully and is pending approval.", "id": str(row["id"])}


@router.put("/{review_id}")
async def moderate_review(review_id: UUID, status: Literal["approved", "rejected"],
                          user=Depends(current_active_superuser), db=Depends(get_db, scope="function")):
    row = await (await db.execute(
        """UPDATE reviews SET status = %s,
           approved_at = CASE WHEN %s = 'approved' THEN now() ELSE NULL END
           WHERE id = %s RETURNING id""", (status, status, review_id),
    )).fetchone()
    if not row:
        raise HTTPException(404, "Review not found")
    return {"message": f"Review {status} successfully"}
