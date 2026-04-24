from typing import List, Optional

from app.api.deps import get_db
from app.core.security import get_current_active_user, get_current_admin
from app.crud.crud_lesson import crud_lesson
from app.models.enums import Level
from app.models.user import User
from app.schemas.lesson import (
    ExerciseSummary,
    LessonCreate,
    LessonDetailResponse,
    LessonExercisesResponse,
    LessonResponse,
    LessonUpdate,
)
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/lessons", tags=["lessons"])



# ----------------------------------------------------------------------
# GET /lessons
# Public: list all lessons, optionally filtered by level.
# Returns flat LessonResponse list (no nested children) for speed.
# ----------------------------------------------------------------------
@router.get("/", response_model=List[LessonResponse])
async def list_lessons(
    level: Optional[Level] = Query(
        default=None,
        description="Filter by level (LEVEL1–LEVEL5). Omit for all levels.",
    ),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_active_user),  # must be logged in
):
    """
    Returns all lessons ordered by level then order index.
    Optionally filter by a specific level.
    """
    lessons = await crud_lesson.get_by_level(db, level=level, skip=skip, limit=limit)
    return lessons


# ----------------------------------------------------------------------
# GET /lessons/{lesson_id}
# Authenticated: get a single lesson with its phonemes.
# exercise_count is derived from the loaded relationship.
# ----------------------------------------------------------------------
@router.get("/{lesson_id}", response_model=LessonDetailResponse)
async def get_lesson(
    lesson_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_active_user),
):
    """
    Returns a lesson with its associated phonemes and exercise count.
    Phoneme list is used by the Flutter app to render the lesson overview card.
    """
    lesson = await crud_lesson.get_with_relations(db, lesson_id=lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lesson with id {lesson_id} not found.",
        )

    # Build the response manually to inject the derived exercise_count field
    return LessonDetailResponse(
        id=lesson.id,
        order=lesson.order,
        level=lesson.level,
        created_at=lesson.created_at,
        phonemes=sorted(lesson.phonemes, key=lambda p: p.order),
        exercise_count=len(lesson.exercises),
    )


# ----------------------------------------------------------------------
# GET /lessons/{lesson_id}/exercises
# Authenticated: get all exercises belonging to a lesson.
# Used by Flutter to populate the exercise list screen.
# ----------------------------------------------------------------------
@router.get("/{lesson_id}/exercises", response_model=LessonExercisesResponse)
async def get_lesson_exercises(
    lesson_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_active_user),
):
    """
    Returns all exercises for a given lesson.
    Each exercise includes content, type, audio_url, and difficulty
    so the Flutter app can render the correct exercise widget.
    """
    lesson = await crud_lesson.get_exercises(db, lesson_id=lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lesson with id {lesson_id} not found.",
        )

    return LessonExercisesResponse(
        lesson_id=lesson.id,
        level=lesson.level,
        exercises=[
            ExerciseSummary(
                id=ex.id,
                content=ex.content,
                type=ex.type.value if hasattr(ex.type, "value") else ex.type,
                difficulty=ex.difficulty,
            )
            for ex in lesson.exercises
        ],
    )


# ----------------------------------------------------------------------
# POST /lessons  (Admin only)
# Create a new lesson.
# ----------------------------------------------------------------------
@router.post(
    "/",
    response_model=LessonResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_lesson(
    lesson_in: LessonCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    """Admin only. Creates a new lesson at the given level and order."""
    lesson = await crud_lesson.create(db, obj_in=lesson_in)
    return lesson


# ----------------------------------------------------------------------
# PUT /lessons/{lesson_id}  (Admin only)
# Update lesson order or level.
# ----------------------------------------------------------------------
@router.put("/{lesson_id}", response_model=LessonResponse)
async def update_lesson(
    lesson_id: int,
    lesson_in: LessonUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    """Admin only. Updates lesson order or level."""
    lesson = await crud_lesson.get(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lesson with id {lesson_id} not found.",
        )
    lesson = await crud_lesson.update(db, db_obj=lesson, obj_in=lesson_in)
    return lesson


# ----------------------------------------------------------------------
# DELETE /lessons/{lesson_id}  (Admin only)
# Hard delete — cascades to exercises via DB relationship.
# ----------------------------------------------------------------------
@router.delete("/{lesson_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_lesson(
    lesson_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    """Admin only. Deletes a lesson and all its exercises (cascade)."""
    lesson = await crud_lesson.get(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lesson with id {lesson_id} not found.",
        )
    await crud_lesson.remove(db, id=lesson_id)
