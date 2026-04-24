from typing import List, Optional

from app.crud.base import CRUDBase
from app.models.enums import Level
from app.models.lesson import Lesson
from app.schemas.lesson import LessonCreate, LessonUpdate
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload


class CRUDLesson(CRUDBase[Lesson, LessonCreate, LessonUpdate]):
    # ------------------------------------------------------------------
    # Get a single lesson with phonemes + exercises eagerly loaded.
    # Used by GET /lessons/{id} so we avoid N+1 queries.
    # ------------------------------------------------------------------
    async def get_with_relations(
        self, db: AsyncSession, *, lesson_id: int
    ) -> Optional[Lesson]:
        result = await db.execute(
            select(Lesson)
            .options(
                selectinload(Lesson.phonemes),
                selectinload(Lesson.exercises),
            )
            .filter(Lesson.id == lesson_id)
        )
        return result.scalar_one_or_none()

    # ------------------------------------------------------------------
    # List lessons filtered by level, ordered by `order` column.
    # If level is None, returns all lessons across every level.
    # ------------------------------------------------------------------
    async def get_by_level(
        self,
        db: AsyncSession,
        *,
        level: Optional[Level] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> List[Lesson]:
        query = select(Lesson).order_by(Lesson.level, Lesson.order)
        if level is not None:
            query = query.filter(Lesson.level == level)
        query = query.offset(skip).limit(limit)
        result = await db.execute(query)
        return result.scalars().all()

    # ------------------------------------------------------------------
    # Get all exercises for a lesson.
    # Used by GET /lessons/{id}/exercises.
    # ------------------------------------------------------------------
    async def get_exercises(
        self, db: AsyncSession, *, lesson_id: int
    ) -> Optional[Lesson]:
        result = await db.execute(
            select(Lesson)
            .options(selectinload(Lesson.exercises))
            .filter(Lesson.id == lesson_id)
        )
        return result.scalar_one_or_none()


crud_lesson = CRUDLesson(Lesson)
