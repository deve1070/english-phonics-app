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
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

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
    # Change line 57 from:

    # To:
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
    exercise = await crud_exercise.get(db, exercise_id)
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
@router.post(
    "/generate",
    response_model=List[ExerciseResponse],
    status_code=status.HTTP_201_CREATED,
)
async def generate_exercises(
    phoneme_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_student),
):
    """
    Generate phonics exercises for the given phoneme.

    - Fetches the target phoneme by ID.
    - Fetches all phonemes in the same lesson with order <= target.order
      (these are the sounds the child has already been taught).
    - Passes both to Azure OpenAI to generate exercises that only use
      allowed phonemes — enforcing the sequencing rule.
    - Saves the generated exercises to the DB and returns them.
    """
    # Fetch target phoneme
    result = await db.execute(select(Phoneme).filter(Phoneme.id == phoneme_id))
    target_phoneme = result.scalar_one_or_none()
    if not target_phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Phoneme {phoneme_id} not found.",
        )

    # Fetch all allowed phonemes: same lesson, order <= target order
    # This is the core of the sequencing rule.
    allowed_result = await db.execute(
        select(Phoneme).filter(
            Phoneme.lesson_id == target_phoneme.lesson_id,
            Phoneme.order <= target_phoneme.order,
        )
    )
    allowed_phonemes = allowed_result.scalars().all()

    try:
        exercises = await generate_exercises_for_phoneme(
            db,
            target_phoneme=target_phoneme,
            allowed_phonemes=allowed_phonemes,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        )

    return exercises
