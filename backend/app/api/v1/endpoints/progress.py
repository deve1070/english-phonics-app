from app import models, schemas
from app.api.deps import get_db
from app.core.security import get_current_user
from app.services.recommendation_service import (
    get_personalized_feedback,
    get_recommended_exercises,
)
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/progress", tags=["progress", "recommendations"])


@router.get("/me/recommended", response_model=list[schemas.exercise.ExerciseResponse])
async def get_my_recommended_exercises(
    db: AsyncSession = Depends(get_db),
    limit: int = 10,
    current_user: models.User = Depends(get_current_user),
):
    """Get personalized exercise recommendation for the current student."""
    exercises = await get_recommended_exercises(
        db=db, user_id=current_user.id, limit=limit
    )
    if not exercises:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No recommended exercises found.",
        )
    return exercises


@router.get("/me/feedback")
async def get_my_feedback(
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get  motivational summary feedback based on recent performance."""
    feedback = await get_personalized_feedback(db=db, user_id=current_user.id)
    return feedback
