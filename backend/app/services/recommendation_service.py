from typing import List

from app import crud, models
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text


async def get_recommended_exercises(
    db: AsyncSession,
    user_id: int,
    limit: int = 10,
    weak_threshold: float = 70.0,
    weak_phonemes_limit: int = 5,
) -> List[models.Exercise]:
    """
    Adaptive recommendation service for perosnalized learning path.


    Logic:
    1,Find user's weakest phonemes (lowest average proununciation scores).
    2,Prioritize exercises linked to those weak phonemes.
    3.If no week phonemes (all mastered)recommend exercises from next uncompleted lesson.
    4.Fallback to Random/general exercises if no data.

    Returns list of exercises schemas(or detailed with phonemes).
    """
    # Step 1: Get weakest phonemes (avg score per phoneme from user's pronunciation scores )
    weak_phonemes_query = text("""
        SELECT
            p.id AS phoneme_id,
            p.symbol,
            AVG(ps.score) AS avg_score
        FROM pronunciation_scores ps
        JOIN exercises e ON ps.exercise_id = e.id
        JOIN phonemes p ON ep.phoneme_id= p.id
        WHERE ps.user_id = :user_id
        GROUP BY p.id,p.symbol
        HAVING AVG(ps.score) < :weak_threshold
        ORDER BY avg_score ASC
        LIMIT :weak_phonemes_limit
    """)

    result = await db.execute(
        weak_phonemes_query,
        {
            "user_id": user_id,
            "weak_threshold": weak_threshold,
            "weak_phonemes_limit": weak_phonemes_limit,
        },
    )
    weak_phonemes = result.fetchall()
    phoneme_ids = [row.phoneme_id for row in weak_phonemes]

    execises = []
    if phoneme_ids:
        # Step 2: Get exercises with weak phonemes  (prioritize current level or random)
        execises = await crud.exercise.get_by_phoneme_ids(
            db=db, phoneme_ids=phoneme_ids, limit=limit
        )
        if len(execises) < limit:
            # Step 3: If masterd weak areas,get next uncompleted lesson exercises
            next_execises = await crud.exercise.get_next_uncompleted_lesson_exercises(
                db=db, user_id=user_id, limit=limit - len(execises)
            )
            execises.extend(next_execises)
        if not execises:
            # Step 4: Fallback to random/general exercises
            execises = await crud.exercise.get_multi(db, skip=0, limit=limit)
            if not execises:
                raise HTTPException(404, "No exercises available")
        return execises


async def get_personalized_feedback(
    db: AsyncSession,
    user_id: int,
) -> dict:
    """
    Optional:Generate Summary feedback based on recent performance.
    Useful for dashboard/motivation.
    """
    recent_scores = await crud.pronunciation_score.get_recent_by_user(
        db=db, user_id=user_id, limit=10
    )
    if not recent_scores:
        return {"message": "Start practicing to get personalized recommendations!"}

    avg_recent = sum(score.score for score in recent_scores) / len(recent_scores)
    if avg_recent >= 90:
        feedback = "You're doing fantastic! Keep up the great work! 🌟"
    elif avg_recent >= 70:
        feedback = "Good progress! Focus on tricky sounds for even better results. 😊"
    else:
        feedback = "Great effort! More practice will help you master those sounds. 👍"

    return {
        "average_recent_score": round(avg_recent),
        "feedback": feedback,
        "practiced_count": len(recent_scores),
    }
