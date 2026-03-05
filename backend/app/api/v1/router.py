from fastapi import APIRouter

from .endpoints import auth, exercises, friends, phonemes, progress, users

api_router = APIRouter()
api_router.include_router(users.router)
api_router.include_router(auth.router)
api_router.include_router(friends.router)
api_router.include_router(exercises.router)
api_router.include_router(progress.router)
api_router.include_router(phonemes.router)
