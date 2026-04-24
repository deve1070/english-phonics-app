from typing import Optional

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.progress import Progress
from ..schemas.progress import ProgressCreate, ProgressUpdate
from .base import CRUDBase


class CRUDProgress(CRUDBase[Progress, ProgressCreate, ProgressUpdate]):
    # ------------------------------------------------------------------
    # Used by pronunciation_service to find an existing progress row
    # before deciding whether to create or update.
    # ------------------------------------------------------------------
    async def get_by_user_and_exercise(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        exercise_id: int,
    ) -> Optional[Progress]:
        result = await db.execute(
            select(Progress).where(
                and_(
                    Progress.user_id == user_id,
                    Progress.exercise_id == exercise_id,
                )
            )
        )
        return result.scalar_one_or_none()

    # ------------------------------------------------------------------
    # Upsert pattern: update existing row or create a new one.
    # Called after a pronunciation attempt is scored.
    # ------------------------------------------------------------------
    async def upsert_after_attempt(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        lesson_id: int,
        exercise_id: int,
        score: float,
    ) -> Progress:
        progress = await self.get_by_user_and_exercise(
            db, user_id=user_id, exercise_id=exercise_id
        )

        if progress:
            progress.attempts += 1
            progress.score = score
            # Mark completed when score >= 80 (passing threshold)
            progress.completed = score >= 80.0
            db.add(progress)
        else:
            progress = Progress(
                user_id=user_id,
                lesson_id=lesson_id,
                exercise_id=exercise_id,
                score=score,
                attempts=1,
                completed=score >= 80.0,
            )
            db.add(progress)

        await db.commit()
        await db.refresh(progress)
        return progress


crud_progress = CRUDProgress(Progress)
