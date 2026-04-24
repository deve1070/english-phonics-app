from typing import List

from app import crud
from app.models.exercise import Exercise
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def get_recommended_exercises(
    db: AsyncSession,
    user_id: int,
    limit: int = 10,
    weak_threshold: float = 70.0,
    weak_phonemes_limit: int = 5,
) -> List[Exercise]:
    """
    Adaptive recommendation engine for personalized learning path.

    Logic:
    1. Find user's weakest phonemes (lowest avg pronunciation scores).
    2. Prioritize exercises linked to those weak phonemes.
    3. If not enough exercises found, extend with next uncompleted lesson.
    4. Fallback to general exercises if still empty.
    """

    # Step 1: Get weakest phonemes for this user.
    # FIX: added the missing JOIN on exercise_phoneme (was using undefined alias `ep`)
    weak_phonemes_query = text("""
        SELECT
            p.id        AS phoneme_id,
            p.symbol,
            AVG(ps.score) AS avg_score
        FROM pronunciation_scores ps
        JOIN exercises e
            ON ps.exercise_id = e.id
        JOIN exercise_phoneme ep
            ON ep.exercise_id = e.id
        JOIN phonemes p
            ON ep.phoneme_id = p.id
        WHERE ps.user_id = :user_id
        GROUP BY p.id, p.symbol
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

    exercises = []

    if phoneme_ids:
        # Step 2: Exercises linked to weak phonemes
        exercises = await crud.exercise.get_by_phoneme_ids(
            db=db, phoneme_ids=phoneme_ids, limit=limit
        )

    if len(exercises) < limit:
        # Step 3: Top up from the next uncompleted lesson.
        # FIX: method is get_next_uncompleted_for_user, not get_next_uncompleted_lesson_exercises
        next_exercises = await crud.exercise.get_next_uncompleted_for_user(
            db=db, user_id=user_id, limit=limit - len(exercises)
        )
        exercises.extend(next_exercises)

    if not exercises:
        # Step 4: Fallback — return any exercises at all
        exercises = await crud.exercise.get_multi(db, skip=0, limit=limit)
        if not exercises:
            raise HTTPException(status_code=404, detail="No exercises available")

    return exercises


async def get_personalized_feedback(
    db: AsyncSession,
    user_id: int,
) -> dict:
    """
    Generate motivational feedback based on recent pronunciation performance.
    Used by the dashboard and progress screen.
    """
    recent_scores = await crud.pronunciation_score.get_recent_by_user(
        db=db, user_id=user_id, limit=10
    )

    if not recent_scores:
        return {"message": "Start practicing to get personalized feedback!"}

    avg_recent = sum(s.score for s in recent_scores) / len(recent_scores)

    if avg_recent >= 90:
        feedback = "You're doing fantastic! Keep up the great work! 🌟"
    elif avg_recent >= 70:
        feedback = "Good progress! Focus on tricky sounds for even better results. 😊"
    else:
        feedback = "Great effort! More practice will help you master those sounds. 👍"

    return {
        "average_recent_score": round(avg_recent, 1),
        "feedback": feedback,
        "practiced_count": len(recent_scores),
    }
