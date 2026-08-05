from typing import List

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..models.exercise import Exercise
from ..models.lesson import Lesson
from ..models.phoneme import Phoneme
from ..models.progress import Progress
from ..schemas.exercise import ExerciseCreate, ExerciseUpdate
from .base import CRUDBase


class CRUDExercise(CRUDBase[Exercise, ExerciseCreate, ExerciseUpdate]):
    # ------------------------------------------------------------------
    # Get a single exercise with phonemes eagerly loaded.
    # Avoids MissingGreenlet errors in async context.
    # ------------------------------------------------------------------
    async def get_with_phonemes(
        self, db: AsyncSession, *, exercise_id: int
    ) -> Exercise | None:
        result = await db.execute(
            select(Exercise)
            .options(selectinload(Exercise.phonemes))
            .filter(Exercise.id == exercise_id)
        )
        return result.scalar_one_or_none()

    # ------------------------------------------------------------------
    # Get exercises linked to specific phonemes (many-to-many).
    # Used by recommendation_service to find exercises for weak phonemes.
    # ------------------------------------------------------------------
    async def get_by_phoneme_ids(
        self, db: AsyncSession, *, phoneme_ids: List[int], limit: int = 10
    ) -> List[Exercise]:
        if not phoneme_ids:
            return []
        stmt = (
            select(Exercise)
            .join(Exercise.phonemes)
            .where(Phoneme.id.in_(phoneme_ids))
            .limit(limit)
        )
        result = await db.execute(stmt)
        return result.scalars().all()

    # ------------------------------------------------------------------
    # Get exercises from the next uncompleted lesson for a user.
    # Used by recommendation_service as fallback when no weak phonemes.
    # ------------------------------------------------------------------
    async def get_next_uncompleted_for_user(
        self, db: AsyncSession, *, user_id: int, limit: int = 10
    ) -> List[Exercise]:
        # Find the max lesson order the user has fully completed
        completed_stmt = (
            select(func.max(Lesson.order))
            .join(Progress, Progress.lesson_id == Lesson.id)
            .where(
                and_(
                    Progress.user_id == user_id,
                    Progress.completed == True,
                )
            )
        )
        completed_result = await db.execute(completed_stmt)
        max_completed_order = completed_result.scalar() or 0

        # Get exercises from the very next lesson in sequence
        stmt = (
            select(Exercise)
            .join(Exercise.lesson)
            .where(Lesson.order == max_completed_order + 1)
            .limit(limit)
        )
        result = await db.execute(stmt)
        return result.scalars().all()

    # ------------------------------------------------------------------
    # Save a batch of AI-generated exercises to the DB in one transaction.
    # Called by exercise_generation_service after AI returns results.
    # Each item in `exercises_data` is a dict with keys:
    #   lesson_id, content, type (ExerciseType), difficulty, graphemes
    # Returns the saved Exercise objects (with IDs populated).
    #
    # `graphemes` is the segmentation the generator already proved the
    # content against. It is stored rather than recomputed: the check
    # that admitted this content and the check that later decides who
    # may see it must be reading the same answer, or content clears
    # generation and is then withheld from the child it was made for.
    # ------------------------------------------------------------------
    async def bulk_create(
        self,
        db: AsyncSession,
        *,
        exercises_data: List[dict],
        phoneme: "Phoneme",  # noqa: F821 — forward ref
    ) -> List[Exercise]:
        saved = []
        for data in exercises_data:
            db_obj = Exercise(
                lesson_id=data["lesson_id"],
                content=data["content"],
                type=data["type"],
                difficulty=data.get("difficulty", 1),
                graphemes=data.get("graphemes"),
            )
            db_obj.phonemes = [phoneme]  # link to the target phoneme
            db.add(db_obj)
            saved.append(db_obj)

        await db.commit()
        for obj in saved:
            await db.refresh(obj)
        return saved


crud_exercise = CRUDExercise(Exercise)
