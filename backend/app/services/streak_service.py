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

On top of that grace sits an earned freeze, which bridges one fully
missed day. See the "Freezes" section below for why it is earned the way
it is and why it is spent without asking.

Day boundaries are UTC, matching _screen_time_today in the parents endpoints.
For users well outside UTC this can shift a practice session into an adjacent
day; making this timezone-aware needs a per-user timezone, which the schema
does not currently carry.
"""

from dataclasses import dataclass
from datetime import date, timedelta

from sqlalchemy import distinct, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.engagement import StreakFreeze
from app.models.parent import LearningGoal
from app.models.pronuncation_score import PronunciationScore

# A freeze covers a single missed day. Never two: the point is to protect
# a child who had a busy Tuesday, not to make the streak meaningless.
FREEZE_COVERS_DAYS = 1


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


# ── Freezes ──────────────────────────────────────────────────────────
#
# A broken streak is the moment a child stops coming back, and the most
# common cause is one ordinary busy day, not a loss of interest. A freeze
# absorbs exactly that: one missed day, bridged, so the run survives.
#
# It has to be earned, or the streak stops meaning anything. It is earned
# by practising on as many days in the week as the parent's own
# lessons_per_week goal asks for — which is the parent's stated definition
# of a good week, so the app is not inventing a second standard.
#
# It is spent automatically. Asking a six-year-old whether to spend a
# token to repair a streak is a decision they cannot evaluate, and making
# them find the button turns a kindness into a trap.


def week_start(day: date) -> date:
    """Monday of the week containing `day`. Matches parents._current_week_monday."""
    return day - timedelta(days=day.weekday())


def qualifying_weeks(days: set[date], days_per_week: int) -> set[date]:
    """Week-start dates in which the child practised often enough to earn a freeze."""
    if days_per_week <= 0:
        return set()
    counts: dict[date, int] = {}
    for day in days:
        start = week_start(day)
        counts[start] = counts.get(start, 0) + 1
    return {start for start, count in counts.items() if count >= days_per_week}


def freeze_candidate(days: set[date], today: date) -> date | None:
    """The one past day that, if bridged, would keep the streak alive.

    Returns None when there is nothing worth spending a freeze on: no
    practice at all, no gap, or a gap too wide for one freeze to close.

    Never returns today. Today is not missed until it is over, and
    spending a freeze on a day the child may still practise would throw
    the token away.
    """
    if not days:
        return None

    yesterday = today - timedelta(days=1)

    if today in days:
        cursor = today
    elif yesterday in days:
        cursor = yesterday
    else:
        # The run has already lapsed. It is rescuable only if yesterday
        # was the single miss — anything longer is a genuine break, and
        # a freeze that resurrected week-old streaks would make the
        # number meaningless.
        return yesterday if (yesterday - timedelta(days=1)) in days else None

    # Walk back to the first day not practised.
    while cursor in days:
        cursor -= timedelta(days=1)

    # Bridging only works if the run continues on the far side; otherwise
    # the gap is two or more days wide and one freeze cannot close it.
    if (cursor - timedelta(days=1)) not in days:
        return None
    return cursor


@dataclass(frozen=True)
class StreakSummary:
    days: int
    freezes_available: int
    frozen_dates: list[date]

    @property
    def freeze_used_recently(self) -> bool:
        """True if a freeze is holding the current run together."""
        return bool(self.frozen_dates)


async def _lessons_per_week(db: AsyncSession, child_id: int) -> int:
    result = await db.execute(
        select(LearningGoal.lessons_per_week).where(LearningGoal.child_id == child_id)
    )
    return result.scalar_one_or_none() or 3


async def streak_summary(
    db: AsyncSession, child_id: int, today: date | None = None
) -> StreakSummary:
    """The streak, with freezes earned and spent.

    This writes: it awards freezes the child has earned and consumes one
    when a gap needs bridging. A read that mutates is not free, but the
    alternative is a scheduled job, and a streak that only repairs itself
    once a night would show the child a broken run every morning — which
    is precisely the moment the feature exists to protect.

    Both writes are idempotent. Awards collide on
    uq_freeze_child_week; a consumed freeze records the date it covered,
    so re-running never spends a second one on the same gap.
    """
    today = today or date.today()
    days = await practice_days(db, child_id)

    # ── Award ────────────────────────────────────────────────────
    earned = qualifying_weeks(days, await _lessons_per_week(db, child_id))
    if earned:
        await db.execute(
            pg_insert(StreakFreeze)
            .values([{"child_id": child_id, "earned_week_start": w} for w in sorted(earned)])
            .on_conflict_do_nothing(constraint="uq_freeze_child_week")
        )
        await db.commit()

    freezes = (
        await db.execute(select(StreakFreeze).where(StreakFreeze.child_id == child_id))
    ).scalars().all()

    spent = [f for f in freezes if f.consumed_for_date is not None]
    unspent = [f for f in freezes if f.consumed_for_date is None]
    effective = days | {f.consumed_for_date for f in spent}

    # ── Spend ────────────────────────────────────────────────────
    candidate = freeze_candidate(effective, today)
    if candidate is not None:
        # Only a freeze earned in or before the candidate's week may cover
        # it — otherwise this week's freeze would reach back and repair a
        # gap from before it existed. Oldest first, so the token most
        # likely to be stranded gets used.
        usable = sorted(
            (f for f in unspent if f.earned_week_start <= week_start(candidate)),
            key=lambda f: f.earned_week_start,
        )
        if usable:
            usable[0].consumed_for_date = candidate
            await db.commit()
            unspent.remove(usable[0])
            spent.append(usable[0])
            effective = effective | {candidate}

    return StreakSummary(
        days=streak_from_days(effective, today),
        freezes_available=len(unspent),
        frozen_dates=sorted(f.consumed_for_date for f in spent),
    )


async def current_streak(db: AsyncSession, child_id: int, today: date | None = None) -> int:
    """Current practice streak in days. 0 if the child has never practised.

    Freeze-aware, so the number a parent sees on the dashboard is the same
    number the child sees on the home screen.
    """
    return (await streak_summary(db, child_id, today)).days
