from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from .auth import auth_backend, fastapi_users, UserRead, UserCreate, UserUpdate
from .routers import referral, reviews

import os

app = FastAPI(title="Enchiridion Backend")

# CORS configuration
origins = os.getenv("CORS_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Auth routes
app.include_router(
    fastapi_users.get_auth_router(auth_backend),
    prefix="/auth/jwt",
    tags=["auth"],
)
app.include_router(
    fastapi_users.get_reset_password_router(),
    prefix="/auth",
    tags=["auth"],
)
app.include_router(
    fastapi_users.get_register_router(UserRead, UserCreate),
    prefix="/auth",
    tags=["auth"],
)
app.include_router(
    fastapi_users.get_verify_router(UserRead),
    prefix="/auth",
    tags=["auth"],
)
app.include_router(
    fastapi_users.get_users_router(UserRead, UserUpdate),
    prefix="/users",
    tags=["users"],
)

# Business logic routes
app.include_router(referral.router, prefix="/referral", tags=["referral"])
app.include_router(reviews.router, prefix="/reviews", tags=["reviews"])


@app.get("/")
async def root():

    return {"message": "Enchiridion API is running"}
