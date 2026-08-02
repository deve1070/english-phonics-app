"""
Weekly goals a child sets for themselves.
=========================================
"I can do things. I can get somewhere." That belief is the actual point
of this feature, and it is built out of mastery experiences — a thing
attempted, a thing reached, repeated — not out of being told you are
clever. Everything below is arranged around making the reaching happen.

Four rules the code enforces, each of which is a way of failing it:

  1. **The child chooses.** A target handed down by the app is homework.
     Three options go up on Monday and the child picks one, or picks
     nothing and is asked no further questions.

  2. **Every option is reachable.** Targets are sized from that child's
     own last few weeks, not from an idea of what a seven-year-old ought
     to manage. The most common way to teach a child they cannot do
     things is to set them a goal they cannot reach and then show them
     the gap.

  3. **The target never moves.** It is written down when chosen. A target
     recomputed on read would creep upwards as the child improved — the
     goal retreating as they walk towards it.

  4. **There is no failure.** A week that ends short ends silently: no
     red, no "you missed it", no counter of weeks lost. The prize is
     simply not there, and Monday brings a fresh choice.

On rewards. Handing out tokens for something a child already enjoys can
displace the enjoyment with the token — the overjustification effect, and
a real risk in an app that is otherwise trying to make reading its own
reward. Two things keep the prize on the right side of it: it is a
souvenir rather than a currency (nothing can be spent, traded or ranked),
and it records what the child chose to do rather than paying them for
compliance. The prize is a keepsake of a week, and it is shown from the
first day precisely so the child is working towards something they can
see rather than being surprised with a payment afterwards.
"""

from dataclasses import dataclass
from datetime import date, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.engagement import PhonemeUnlock, RecognitionAttempt, WeeklyGoal
from app.models.enums import GoalKind
from app.services.recognition_service import ROUND_SIZE
from app.services.streak_service import practice_days, week_start

# Bounds on what a week may ask for. The ceilings matter more than the
# floors: a goal of seven days needs a perfect week, which means one
# ordinary busy Tuesday turns the whole week into a miss. Six is the most
# this app will ever ask of a child, and there is no way to opt into more.
MIN_DAYS, MAX_DAYS = 2, 6

# Two rounds, and tied to the round size rather than written as a number:
# a floor of one round is a week's promise a child keeps by accident in
# their first two minutes, which teaches them nothing about working
# towards something and empties the medal of any meaning. Two is still
# small enough that anyone who turns up twice reaches it.
MIN_FOUND, MAX_FOUND = 2 * ROUND_SIZE, 40

MIN_MASTERED, MAX_MASTERED = 1, 5

# How much of their own recent history a target is sized from. Three weeks
# is enough to see a pace and short enough that a child who has just got
# going is not measured against the fortnight they spent doing nothing.
HISTORY_WEEKS = 3


@dataclass(frozen=True)
class GoalOption:
    """One of the three things a child may promise on a Monday."""

    kind: GoalKind
    target: int


@dataclass(frozen=True)
class GoalProgress:
    kind: GoalKind
    target: int
    done: int
    week_start: date
    completed_at: datetime | None

    @property
    def is_complete(self) -> bool:
        return self.done >= self.target

    @property
    def remaining(self) -> int:
        return max(0, self.target - self.done)


# ── Sizing ───────────────────────────────────────────────────────────


def stretch_target(recent: list[int], floor: int, ceiling: int) -> int:
    """A number a little past what this child has been doing.

    The best of the recent weeks rather than the average, and then one
    more: aiming at a child's average asks them to be typical, which is
    not a goal, and aiming at double their best is how you teach a child
    that goals are things other people reach.
    """
    best = max(recent) if recent else 0
    return max(floor, min(best + 1, ceiling))


async def _weekly_counts(
    db: AsyncSession, child_id: int, kind: GoalKind, today: date
) -> list[int]:
    """How much of `kind` the child did in each of the last few full weeks."""
    starts = [
        week_start(today) - timedelta(weeks=w) for w in range(1, HISTORY_WEEKS + 1)
    ]
    return [await _count(db, child_id, kind, start) for start in starts]


async def _count(
    db: AsyncSession, child_id: int, kind: GoalKind, start: date
) -> int:
    """How much of `kind` the child did in the week beginning `start`."""
    end = start + timedelta(days=7)

    if kind is GoalKind.DAYS:
        days = await practice_days(db, child_id)
        return sum(1 for day in days if start <= day < end)

    if kind is GoalKind.SOUNDS_FOUND:
        # Correct answers, not questions asked. Otherwise the goal is met
        # by tapping through rounds without listening, which would teach
        # a child that the way to reach a target is to stop trying.
        return (
            await db.execute(
                select(func.count(RecognitionAttempt.id)).where(
                    RecognitionAttempt.child_id == child_id,
                    RecognitionAttempt.is_correct.is_(True),
                    RecognitionAttempt.answered_at >= start,
                    RecognitionAttempt.answered_at < end,
                )
            )
        ).scalar() or 0

    # SOUNDS_MASTERED — creatures woken this week.
    return (
        await db.execute(
            select(func.count(PhonemeUnlock.id)).where(
                PhonemeUnlock.child_id == child_id,
                PhonemeUnlock.unlocked_at >= start,
                PhonemeUnlock.unlocked_at < end,
            )
        )
    ).scalar() or 0


async def options_for(
    db: AsyncSession, child_id: int, today: date | None = None
) -> list[GoalOption]:
    """The three choices to put in front of the child this Monday.

    Always all three kinds, always in the same order, so a child who has
    settled on "I come every day" finds it where they left it rather than
    having to re-read three cards each week.
    """
    today = today or date.today()
    bounds = {
        GoalKind.DAYS: (MIN_DAYS, MAX_DAYS),
        GoalKind.SOUNDS_FOUND: (MIN_FOUND, MAX_FOUND),
        GoalKind.SOUNDS_MASTERED: (MIN_MASTERED, MAX_MASTERED),
    }
    options = []
    for kind, (floor, ceiling) in bounds.items():
        recent = await _weekly_counts(db, child_id, kind, today)
        options.append(
            GoalOption(kind=kind, target=stretch_target(recent, floor, ceiling))
        )
    return options


# ── Choosing and tracking ────────────────────────────────────────────


async def current_goal(
    db: AsyncSession, child_id: int, today: date | None = None
) -> WeeklyGoal | None:
    today = today or date.today()
    return (
        await db.execute(
            select(WeeklyGoal).where(
                WeeklyGoal.child_id == child_id,
                WeeklyGoal.week_start == week_start(today),
            )
        )
    ).scalar_one_or_none()


async def choose(
    db: AsyncSession,
    child_id: int,
    kind: GoalKind,
    today: date | None = None,
) -> WeeklyGoal:
    """Set this week's goal, or return the one already set.

    The target comes from the server, never from the client. Not because
    a child would cheat — they have nothing to cheat for here — but
    because the sizing is the part that makes the promise keepable, and
    it belongs next to the history it is derived from.

    Changing kind mid-week is refused by returning what is already there.
    A goal that can be swapped on Saturday for whichever one is closest to
    done is not a promise, and the moment of choosing is what gives the
    rest of the week its meaning.
    """
    today = today or date.today()
    existing = await current_goal(db, child_id, today)
    if existing is not None:
        return existing

    options = await options_for(db, child_id, today)
    target = next(o.target for o in options if o.kind is kind)

    goal = WeeklyGoal(
        child_id=child_id,
        week_start=week_start(today),
        kind=kind,
        target=target,
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)
    return goal


async def progress(
    db: AsyncSession, child_id: int, today: date | None = None
) -> GoalProgress | None:
    """How far along this week's goal is, marking it complete if it is.

    Writes on read, like streak_summary and for the same reason: the
    child has to see the prize light up in the moment they earn it, and a
    nightly job would hand it to them the following morning with the
    effort already forgotten.
    """
    today = today or date.today()
    goal = await current_goal(db, child_id, today)
    if goal is None:
        return None

    done = await _count(db, child_id, goal.kind, goal.week_start)

    if goal.completed_at is None and done >= goal.target:
        goal.completed_at = datetime.utcnow()
        await db.commit()

    return GoalProgress(
        kind=goal.kind,
        target=goal.target,
        done=done,
        week_start=goal.week_start,
        completed_at=goal.completed_at,
    )


@dataclass(frozen=True)
class EarnedWeek:
    week_start: date
    # Carried so the prize can show what the week was spent on. A shelf of
    # identical tokens says only how many times the child complied; a
    # shelf that says "that week I came every day, that week I went
    # listening" is a record of decisions they made.
    kind: GoalKind


async def earned_weeks(db: AsyncSession, child_id: int) -> list[EarnedWeek]:
    """Every week this child finished what they set out to do.

    The prize shelf. Weeks that fell short are not in this list and are
    not represented by a gap either — an empty slot on a shelf is a record
    of failure, and this feature does not keep one.
    """
    rows = (
        await db.execute(
            select(WeeklyGoal.week_start, WeeklyGoal.kind)
            .where(
                WeeklyGoal.child_id == child_id,
                WeeklyGoal.completed_at.isnot(None),
            )
            .order_by(WeeklyGoal.week_start)
        )
    ).all()
    return [EarnedWeek(week_start=start, kind=kind) for start, kind in rows]
