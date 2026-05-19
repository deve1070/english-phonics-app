from fastapi import APIRouter

from .auth import router as auth_router
from .exercises import router as exercises_router
from .lessons import router as lessons_router
from .tts import router as tts_router
from .users import router as users_router

api_router = APIRouter()

api_router.include_router(auth_router)
api_router.include_router(lessons_router)

api_router.include_router(users_router)

api_router.include_router(exercises_router)
api_router.include_router(tts_router)
