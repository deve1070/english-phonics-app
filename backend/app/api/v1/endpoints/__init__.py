from fastapi import APIRouter

from .auth import router as auth_router
from .exercises import router as exercises_router
from .friends import router as friends_router
from .progress import router as progress_router
from .users import router as users_router

api_router = APIRouter()
api_router.include_router(users_router)
api_router.include_router(auth_router)
api_router.include_router(friends_router)
api_router.include_router(exercises_router)
api_router.include_router(progress_router)
