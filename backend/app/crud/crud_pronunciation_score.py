from typing import List

from app.crud.base import CRUDBase
from app.models.pronunciation_score import PronunciationScore
from app.schemas.pronunciation_score import PronunciationScoreCreate
from sqalalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

crud_pronunciation_score = CRUDBase[PronunciationScore, PronunciationScoreCreate](
    PronunciationScore
)


async def get_recent_by_user(
    db: AsyncSession, user_id: int, limit: int = 10
) -> List[PronunciationScore]:
    """Get user's most recent pronunciation scores."""
    stmt = (
        select(PronunciationScore)
        .where(PronunciationScore.user_id == user_id)
        .order_by(desc(PronunciationScore.timestamp))
        .limit(limit)
    )

    result = await db.execute(stmt)
    return result.scalars().all()
