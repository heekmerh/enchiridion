from fastapi import APIRouter, Depends, HTTPException, Query
from ..models import Review, ReviewCreate
from ..sheets import sheets_client
from ..auth import current_active_user, current_active_superuser, UserRead
from datetime import datetime
import uuid
from typing import List

router = APIRouter()

@router.get("/", response_model=List[Review])
async def get_reviews(admin: bool = Query(False)):
    records = sheets_client.get_all_records("Reviews")
    reviews = []
    for record in records:
        review = Review(
            id=str(record.get("id", "")),
            name=record.get("Name", ""),
            jobTitle=record.get("Job Title", ""),
            organization=record.get("Organization", ""),
            rating=int(record.get("Rating", 0)),
            text=record.get("Text", ""),
            status=record.get("Status", "pending"),
            createdAt=record.get("CreatedAt", ""),
            approvedAt=record.get("ApprovedAt")
        )
        if admin or review.status == "approved":
            reviews.append(review)
            
    # Sort by createdAt descending
    reviews.sort(key=lambda x: x.createdAt, reverse=True)
    return reviews

@router.post("/", status_code=201)
async def submit_review(review: ReviewCreate):
    new_id = str(uuid.uuid4())
    created_at = datetime.now().isoformat()
    # Sheet columns: id, Name, Job Title, Organization, Rating, Text, Status, CreatedAt, ApprovedAt
    row = [
        new_id,
        review.name,
        review.jobTitle,
        review.organization or "",
        review.rating,
        review.text,
        "pending",
        created_at,
        ""
    ]
    sheets_client.append_row("Reviews", row)
    return {"message": "Review submitted successfully and is pending approval.", "id": new_id}

@router.put("/{review_id}")
async def moderate_review(
    review_id: str, 
    status: str = Query(..., enum=["approved", "rejected"]), 
    user: UserRead = Depends(current_active_superuser)
):
    
    # Find review by ID and update status
    # This is a bit complex with gspread without direct row lookup by ID
    # For MVP, we'll use find_cell
    cell = sheets_client.find_cell("Reviews", review_id, 1) # Column 1 is id
    if not cell:
        raise HTTPException(status_code=404, detail="Review not found")
    
    sheets_client.update_cell("Reviews", cell.row, 7, status) # Column 7 is Status
    if status == "approved":
        sheets_client.update_cell("Reviews", cell.row, 9, datetime.now().isoformat()) # Column 9 is ApprovedAt
        
    return {"message": f"Review {status} successfully"}
