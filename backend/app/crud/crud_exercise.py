from typing import List

from app.models.exercise import Exercise
from app.models.lesson import Lesson, Phoneme
from app.models.progress import Progress
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_by_phoneme_ids(
    db: AsyncSession, phoneme_ids: List[int], limit: int = 10
) -> List[Exercise]:
    """Get exercises linked to specific phonemes(via many-to-many)."""
    if not phoneme_ids:
        return []
    stmt = (
        select(Exercise)
        .join(Exercise.phonemes)
        .where(Exercise.phonemes.any(Phoneme.id.in_(phoneme_ids)))
        .limit(limit)
    )

    result = await db.execute(stmt)
    return result.scalars().all()


async def get_next_uncompleted_for_user(
    db: AsyncSession, user_id: int, limit: int = 10
) -> List[Exercise]:
    """Get exercises from the next unccompleted lesson for the user.
    Assume lessons have 'order' field,progress trackes completed lessons.
    """
    # Find user's current completed lessons(max_order)
    completed_stmt = (
        select(func.max(Lesson.order))
        .join(Progress, Progress.lesson_id == Lesson.id)
        .where(and_(Progress.user_id == user_id, Progress.completed == True))
    )

    completed_result = await db.execute(completed_stmt)
    max_completed_order = completed_result.scalar() or 0

    next_order = max_completed_order + 1

    # Get exercises from the next lesson
    stmt = (
        select(Exercise)
        .join(Exercise.lesson)
        .where(Lesson.order == next_order)
        .limit(limit)
    )

    result = await db.execute(stmt)
    return result.scalars().all()
