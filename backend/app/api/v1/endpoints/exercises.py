from app import crud, models
from app.api import deps
from app.core.security import get_current_student
from app.services.pronunciation_service import assess_student_pronunciation
from app.services.reference_audio_service import get_reference_audio_stream
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/exercises", tags=["exercises"])


@router.get("/{exercise_id}")
async def get_exercise(exercise_id: int, db: AsyncSession = Depends(deps.get_db)):
    exercise = await crud.exercise.get(db, id=exercise_id)
    if not exercise:
        raise HTTPException(404, "Exercise not found")
    return exercise


@router.post("/{exercise_id}/submit-pronunciation")
async def submit_pronunciation(
    exercise_id: int,
    audio: UploadFile = File(...),
    db: AsyncSession = Depends(deps.get_db),
    current_user: models.User = Depends(get_current_student),
):
    exercise = await crud.exercise.get(db, id=exercise_id)
    if not exercise:
        raise HTTPException(404, "Exercise not found")

    audio_content = await audio.read()  # Raw bytes
    result = await assess_student_pronunciation(
        db, exercise, audio_content, current_user.id
    )
    return result


@router.get("/{exercise_id}/reference-audio")
async def get_reference_audio(
    exercise_id: int,
    blending: bool = Query(False),
    db: AsyncSession = Depends(deps.get_db),
):
    exercise = await crud.exercise.get(db, id=exercise_id)
    if not exercise:
        raise HTTPException(404, "Exercise not found")

    return await get_reference_audio_stream(exercise, blending=blending)
