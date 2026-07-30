"""app/api/v1/router.py"""

# Phone-based auth — OTP + biometric + invite links
# Parent management dashboard
from app.api.v1.endpoints import (
    auth,
    exercises,
    lessons,
    parents,
    phonemes,
    tts,
    users,
)
from fastapi import APIRouter

api_router = APIRouter()

api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(lessons.router)
api_router.include_router(phonemes.router)
api_router.include_router(exercises.router)
api_router.include_router(tts.router)
api_router.include_router(parents.router)  # ← parent dashboard
