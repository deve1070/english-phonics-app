"""
The daily quest.
================
Three exercises a day: one to review, one to learn, one to stretch for.

Why exactly three, and why fixed:

  - **Finite.** A child has to be able to *finish today*. An endless feed
    never gives that, and "done" is the feeling that brings them back
    tomorrow. Three also sits comfortably inside the parent's screen-time
    cap, so the two systems never fight — the quest is always completable
    before the limit lands.

  - **Fixed once chosen.** The selection is written to the database the
    first time it is asked for each day. Re-rolling on every request
    would change the goalposts while the child worked, and a target that
    moves is a target you cannot hit.

  - **Three roles, not three exercises.** Review is the sound they are
    weakest on, which makes the slot do spaced repetition without anyone
    having to build a scheduler. Current is where they are. Stretch is
    one step past it — winnable, not safe.

Completion is derived, never stored: an item is done when the child has
attempted its exercise today. Attempted, not passed — the quest rewards
turning up and trying, the same rule the mascot follows. Storing a flag
would mean a second source of truth that could disagree with the scores.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.engagement import DailyQuest, DailyQuestItem
from app.models.enums import QuestSlot
from app.models.exercise import Exercise
from app.models.lesson import Lesson
from app.models.phoneme import Phoneme
from app.models.progress import Progress
from app.models.pronuncation_score import PronunciationScore
from app.services.mastery_service import phoneme_stats

QUEST_SIZE = len(QuestSlot)


@dataclass(frozen=True)
class QuestItemView:
    slot: QuestSlot
    exercise: Exercise
    completed: bool


@dataclass(frozen=True)
class QuestView:
    quest_date: date
    items: list[QuestItemView]

    @property
    def completed_count(self) -> int:
        return sum(1 for i in self.items if i.completed)

    @property
    def is_complete(self) -> bool:
        return bool(self.items) and all(i.completed for i in self.items)


# ── Selection ────────────────────────────────────────────────────────


async def _exercises_for_phonemes(
    db: AsyncSession, phoneme_ids: list[int]
) -> dict[int, list[Exercise]]:
    """Exercises grouped by the phoneme they practise, easiest first."""
    if not phoneme_ids:
        return {}
    result = await db.execute(
        select(Phoneme.id, Exercise)
        .join(Exercise.phonemes)
        .where(Phoneme.id.in_(phoneme_ids))
        .order_by(Exercise.difficulty, Exercise.id)
    )
    grouped: dict[int, list[Exercise]] = {}
    for phoneme_id, exercise in result.all():
        grouped.setdefault(phoneme_id, []).append(exercise)
    return grouped


async def _current_lesson_id(db: AsyncSession, child_id: int) -> int | None:
    """The first lesson the child has not finished every exercise in.

    Lessons with no exercises are skipped rather than treated as
    unfinished — with generated content missing, an empty lesson would
    otherwise pin every child to lesson one forever. Same carve-out the
    journey map makes on the client, for the same reason.
    """
    lessons = (
        await db.execute(select(Lesson).order_by(Lesson.order))
    ).scalars().all()

    totals = dict(
        (
            await db.execute(
                select(Exercise.lesson_id, func.count(Exercise.id))
                .group_by(Exercise.lesson_id)
            )
        ).all()
    )
    done = dict(
        (
            await db.execute(
                select(Exercise.lesson_id, func.count(Exercise.id))
                .join(Progress, Progress.exercise_id == Exercise.id)
                .where(Progress.user_id == child_id, Progress.completed.is_(True))
                .group_by(Exercise.lesson_id)
            )
        ).all()
    )

    for lesson in lessons:
        total = totals.get(lesson.id, 0)
        if total == 0:
            continue
        if done.get(lesson.id, 0) < total:
            return lesson.id
    return lessons[-1].id if lessons else None


async def _pick_review(
    db: AsyncSession, child_id: int, taken: set[int]
) -> Exercise | None:
    """An exercise for the attempted sound the child scores worst on.

    Mastered sounds are excluded — re-drilling something they have got is
    the fastest way to make practice feel pointless.
    """
    stats = await phoneme_stats(db, child_id)
    weak = sorted(
        (s for s in stats.values() if not s.mastered),
        key=lambda s: s.avg_score,
    )
    if not weak:
        return None
    by_phoneme = await _exercises_for_phonemes(db, [s.phoneme_id for s in weak])
    for stat in weak:
        for exercise in by_phoneme.get(stat.phoneme_id, []):
            if exercise.id not in taken:
                return exercise
    return None


async def _pick_current(
    db: AsyncSession, child_id: int, taken: set[int]
) -> Exercise | None:
    """An unfinished exercise from the lesson the child is working through."""
    lesson_id = await _current_lesson_id(db, child_id)
    if lesson_id is None:
        return None

    completed_ids = set(
        (
            await db.execute(
                select(Progress.exercise_id).where(
                    Progress.user_id == child_id, Progress.completed.is_(True)
                )
            )
        ).scalars().all()
    )

    candidates = (
        await db.execute(
            select(Exercise)
            .where(Exercise.lesson_id == lesson_id)
            .order_by(Exercise.difficulty, Exercise.id)
        )
    ).scalars().all()

    # Prefer something not yet finished; fall back to any exercise in the
    # lesson so a child who has finished everything still gets a quest.
    for exercise in candidates:
        if exercise.id not in taken and exercise.id not in completed_ids:
            return exercise
    for exercise in candidates:
        if exercise.id not in taken:
            return exercise
    return None


async def _pick_stretch(
    db: AsyncSession, child_id: int, taken: set[int]
) -> Exercise | None:
    """An exercise for the earliest sound the child has never attempted.

    One step past the edge, not ten: phonemes are walked in curriculum
    order, so the stretch is always the very next thing rather than
    something arbitrary from the far end of the syllabus.
    """
    attempted = set(
        (
            await db.execute(
                select(PronunciationScore.phoneme_id)
                .where(
                    PronunciationScore.user_id == child_id,
                    PronunciationScore.phoneme_id.isnot(None),
                )
                .distinct()
            )
        ).scalars().all()
    )

    phonemes = (
        await db.execute(select(Phoneme).order_by(Phoneme.order))
    ).scalars().all()
    unseen = [p.id for p in phonemes if p.id not in attempted]
    if not unseen:
        return None

    by_phoneme = await _exercises_for_phonemes(db, unseen)
    for phoneme_id in unseen:
        for exercise in by_phoneme.get(phoneme_id, []):
            if exercise.id not in taken:
                return exercise
    return None


async def _select_exercises(
    db: AsyncSession, child_id: int
) -> list[tuple[QuestSlot, Exercise]]:
    """Fill the three slots, skipping any that cannot be filled.

    A slot goes empty rather than being padded with a repeat. A quest of
    two real tasks is honest; a quest of three where one is the same word
    twice teaches a child that the quest is noise.
    """
    taken: set[int] = set()
    picked: list[tuple[QuestSlot, Exercise]] = []

    for slot, pick in (
        (QuestSlot.REVIEW, _pick_review),
        (QuestSlot.CURRENT, _pick_current),
        (QuestSlot.STRETCH, _pick_stretch),
    ):
        exercise = await pick(db, child_id, taken)
        if exercise is not None:
            taken.add(exercise.id)
            picked.append((slot, exercise))

    return picked


# ── Persistence and read ─────────────────────────────────────────────


async def _load_quest(
    db: AsyncSession, child_id: int, quest_date: date
) -> DailyQuest | None:
    result = await db.execute(
        select(DailyQuest)
        .options(selectinload(DailyQuest.items).selectinload(DailyQuestItem.exercise))
        .where(DailyQuest.child_id == child_id, DailyQuest.quest_date == quest_date)
    )
    return result.scalar_one_or_none()


async def _attempted_exercise_ids_on(
    db: AsyncSession, child_id: int, day: date
) -> set[int]:
    start = datetime.combine(day, time.min)
    end = start + timedelta(days=1)
    result = await db.execute(
        select(PronunciationScore.exercise_id)
        .where(
            PronunciationScore.user_id == child_id,
            PronunciationScore.timestamp >= start,
            PronunciationScore.timestamp < end,
        )
        .distinct()
    )
    return set(result.scalars().all())


async def get_or_create_today(
    db: AsyncSession, child_id: int, today: date | None = None
) -> QuestView:
    """Today's quest, built on first ask and stable thereafter."""
    today = today or date.today()

    quest = await _load_quest(db, child_id, today)
    if quest is None:
        picked = await _select_exercises(db, child_id)
        quest = DailyQuest(child_id=child_id, quest_date=today)
        quest.items = [
            DailyQuestItem(exercise_id=exercise.id, slot=slot)
            for slot, exercise in picked
        ]
        db.add(quest)
        try:
            await db.commit()
        except IntegrityError:
            # Two requests raced on the first fetch of the day and the
            # unique constraint caught the loser. The winner's quest is
            # just as good — take it rather than failing the request.
            await db.rollback()
        quest = await _load_quest(db, child_id, today)
        if quest is None:  # pragma: no cover — only if the insert truly failed
            return QuestView(quest_date=today, items=[])

    attempted = await _attempted_exercise_ids_on(db, child_id, today)
    return QuestView(
        quest_date=today,
        items=[
            QuestItemView(
                slot=item.slot,
                exercise=item.exercise,
                completed=item.exercise_id in attempted,
            )
            for item in quest.items
        ],
    )
