"""
Exercises endpoints
====================
GET  /exercises/{exercise_id}               — get a single exercise
POST /exercises/{exercise_id}/submit-pronunciation — submit audio for assessment
GET  /exercises/{exercise_id}/reference-audio      — stream reference audio
POST /exercises/generate                    — generate exercises for a phoneme (NEW)
"""

from typing import List

from app.api.deps import get_db
from app.core.security import get_current_active_user, get_current_student
from app.crud.crud_exercise import crud_exercise
from app.models.phoneme import Phoneme
from app.models.user import User
from app.schemas.exercise import ExerciseResponse
from app.services.exercise_generation_service import generate_exercises_for_phoneme
from app.services.pronunciation_service import assess_student_pronunciation
from app.services.reference_audio_service import get_reference_audio_stream
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import AsyncSessionLocal

router = APIRouter(prefix="/exercises", tags=["exercises"])


# ------------------------------------------------------------------
# GET /exercises/{exercise_id}
# ------------------------------------------------------------------
@router.get("/{exercise_id}", response_model=ExerciseResponse)
async def get_exercise(
    exercise_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_active_user),
):
    exercise = await crud_exercise.get_with_phonemes(db, exercise_id=exercise_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Exercise {exercise_id} not found.",
        )
    return exercise


# ------------------------------------------------------------------
# POST /exercises/{exercise_id}/submit-pronunciation
# Student submits a WAV recording; Azure Speech SDK scores it.
# ------------------------------------------------------------------
@router.post("/{exercise_id}/submit-pronunciation")
async def submit_pronunciation(
    exercise_id: int,
    audio: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_student),
):
    exercise = await crud_exercise.get_with_phonemes(db, exercise_id=exercise_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Exercise {exercise_id} not found.",
        )

    # Read raw bytes from the uploaded file — pronunciation_service expects bytes
    audio_content = await audio.read()
    if not audio_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file is empty.",
        )

    result = await assess_student_pronunciation(
        db=db,
        exercise=exercise,
        audio_content=audio_content,
        user_id=current_user.id,
    )
    return result


# ------------------------------------------------------------------
# GET /exercises/{exercise_id}/reference-audio
# Returns a streaming audio response (pre-recorded or TTS).
# ------------------------------------------------------------------
@router.get("/{exercise_id}/reference-audio")
async def get_reference_audio(
    exercise_id: int,
    blend: bool = False,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_active_user),
):
    exercise = await crud_exercise.get_with_phonemes(db, exercise_id=exercise_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Exercise {exercise_id} not found.",
        )
    return await get_reference_audio_stream(exercise=exercise, blend=blend)


# ------------------------------------------------------------------
# POST /exercises/generate
# Generate + save exercises for a given phoneme.
# The phoneme ordering rule is enforced here:
#   all allowed phonemes (order <= target.order) are fetched and
#   passed to the generation service so the AI prompt is constrained.
# ------------------------------------------------------------------

async def background_generate_exercises(phoneme_id: int):
    """
    Background worker that runs the LLM generation.
    It creates its own DB session so it doesn't crash when the request closes.
    """
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Phoneme).filter(Phoneme.id == phoneme_id))
        target_phoneme = result.scalar_one_or_none()
        if not target_phoneme:
            return

        allowed_result = await db.execute(
            select(Phoneme).filter(
                Phoneme.lesson_id == target_phoneme.lesson_id,
                Phoneme.order <= target_phoneme.order,
            )
        )
        allowed_phonemes = allowed_result.scalars().all()

        try:
            await generate_exercises_for_phoneme(
                db,
                target_phoneme=target_phoneme,
                allowed_phonemes=allowed_phonemes,
            )
        except Exception:
            # In a full production app, we would log this to a monitoring service
            pass


@router.post(
    "/generate",
    status_code=status.HTTP_202_ACCEPTED,
)
async def generate_exercises(
    phoneme_id: int,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_student),
):
    """
    Trigger generation of phonics exercises for the given phoneme.
    Returns 202 Accepted while generation happens in the background.
    """
    # Verify the phoneme exists before kicking off the task
    result = await db.execute(select(Phoneme).filter(Phoneme.id == phoneme_id))
    target_phoneme = result.scalar_one_or_none()
    if not target_phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Phoneme {phoneme_id} not found.",
        )

    # Queue the task
    background_tasks.add_task(background_generate_exercises, phoneme_id)

    return {"message": "Exercise generation started in the background."}
