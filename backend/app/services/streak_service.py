"""Practice-streak calculation.

A streak is the number of consecutive days, counting backwards from today,
on which a child actually practised.

"Practised" means submitting at least one pronunciation attempt
(a PronunciationScore row). That is deliberately the signal rather than
screen-time sessions: a session is opened when a parent switches into the
child's view, which says nothing about whether the child did any work.
A pronunciation attempt is unambiguous.

Yesterday counts as the anchor as well as today, so a streak is not broken
the moment the clock rolls over — it breaks only once a full day has been
missed. Without that grace, every child's streak would read 0 for the whole
morning until they next practised.

Day boundaries are UTC, matching _screen_time_today in the parents endpoints.
For users well outside UTC this can shift a practice session into an adjacent
day; making this timezone-aware needs a per-user timezone, which the schema
does not currently carry.
"""

from datetime import date, timedelta

from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pronuncation_score import PronunciationScore


async def practice_days(db: AsyncSession, child_id: int) -> set[date]:
    """Every distinct UTC calendar day on which this child practised."""
    result = await db.execute(
        select(distinct(func.date(PronunciationScore.timestamp))).where(
            PronunciationScore.user_id == child_id
        )
    )
    days: set[date] = set()
    for (value,) in result.all():
        if value is None:
            continue
        # func.date() returns a date on asyncpg, but a string on some
        # drivers (notably SQLite in tests) — normalise both.
        days.add(value if isinstance(value, date) else date.fromisoformat(str(value)))
    return days


def streak_from_days(days: set[date], today: date) -> int:
    """Consecutive practice days ending today or yesterday."""
    if not days:
        return 0

    if today in days:
        cursor = today
    elif (today - timedelta(days=1)) in days:
        cursor = today - timedelta(days=1)
    else:
        # Last practice was two or more days ago: the streak is broken.
        return 0

    count = 0
    while cursor in days:
        count += 1
        cursor -= timedelta(days=1)
    return count


async def current_streak(db: AsyncSession, child_id: int, today: date | None = None) -> int:
    """Current practice streak in days. 0 if the child has never practised."""
    return streak_from_days(
        await practice_days(db, child_id),
        today or date.today(),
    )
