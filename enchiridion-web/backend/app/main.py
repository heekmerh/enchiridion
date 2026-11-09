import logging
import os

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import psycopg

from .database import get_db
from .routers import billing, communications, referral, reviews, users

app = FastAPI(title="Enchiridion Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv(
        "CORS_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000"
    ).split(",") if origin.strip()],
    allow_credentials=True, allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(billing.router, prefix="/api/v1", tags=["billing"])
app.include_router(communications.router, prefix="/api/v1/communications", tags=["communications"])
app.include_router(referral.router, prefix="/referral", tags=["referral"])
app.include_router(reviews.router, prefix="/reviews", tags=["reviews"])


@app.exception_handler(psycopg.Error)
async def database_error(request: Request, exc: psycopg.Error):
    logging.getLogger(__name__).error("Database operation failed: %s", type(exc).__name__)
    return JSONResponse(status_code=503, content={"detail": "Database operation failed; please retry"})


@app.get("/")
async def root():
    return {"message": "Enchiridion API is running"}


@app.get("/health/ready")
async def readiness(db=Depends(get_db, scope="function")):
    await db.execute("SELECT id FROM partners LIMIT 0")
    await db.execute("SELECT id FROM billing.plans LIMIT 0")
    return {"status": "ready", "storage": "supabase"}
