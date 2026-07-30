from typing import Optional

from sqlalchemy import and_, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
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
    # Upsert pattern: atomic INSERT ... ON CONFLICT DO UPDATE.
    # Called after a pronunciation attempt is scored.
    #
    # Previously this did a SELECT to check for an existing row, then
    # decided INSERT vs UPDATE in Python. Two concurrent submissions for
    # the same (user_id, exercise_id) could both see "no row" and both
    # INSERT, creating duplicate Progress rows. Relies on the
    # uq_progress_user_exercise constraint on the Progress model so the
    # database itself resolves the race atomically.
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
        completed = score >= 80.0

        stmt = pg_insert(Progress).values(
            user_id=user_id,
            lesson_id=lesson_id,
            exercise_id=exercise_id,
            score=score,
            attempts=1,
            completed=completed,
        )
        # Keep the student's best score across attempts, never overwrite
        # a good score with a worse one; completed is derived from the
        # best score, not the latest attempt (same semantics as before).
        best_score = func.greatest(Progress.score, stmt.excluded.score)
        stmt = stmt.on_conflict_do_update(
            index_elements=[Progress.user_id, Progress.exercise_id],
            set_={
                "attempts": Progress.attempts + 1,
                "score": best_score,
                "completed": best_score >= 80.0,
            },
        )
        await db.execute(stmt)
        await db.commit()

        return await self.get_by_user_and_exercise(
            db, user_id=user_id, exercise_id=exercise_id
        )


crud_progress = CRUDProgress(Progress)
