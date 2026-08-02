#!/usr/bin/env python3
"""Walks the engagement loop for real, against the live database.

verify_basic_functions.py covers the endpoints as a brand-new child sees
them — every shelf empty, nothing unlocked. That proves the wiring but
not the behaviour: the interesting half is what happens once a child
actually gets good at something, and reaching that state over HTTP would
mean submitting real audio to Azure for every attempt.

So this drives the service layer directly, against the same database the
API uses, with pronunciation scores written in at chosen dates. It
creates a throwaway child, asserts its way through the loop, and deletes
it again.

Usage (from backend/):
  python scripts/verify_engagement.py
"""

from __future__ import annotations

import asyncio
import random
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import delete, select  # noqa: E402

from app.db.session import AsyncSessionLocal  # noqa: E402
from app.models.engagement import (  # noqa: E402
    DailyQuest,
    PhonemeUnlock,
    RecognitionAttempt,
    StreakFreeze,
    WeeklyGoal,
)
from app.models.enums import (  # noqa: E402
    ExerciseType,
    GoalKind,
    QuestSlot,
    RecognitionMode,
    UserRole,
)
from app.models.exercise import Exercise  # noqa: E402
from app.models.parent import LearningGoal  # noqa: E402
from app.models.phoneme import Phoneme  # noqa: E402
from app.models.pronuncation_score import PronunciationScore  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import (  # noqa: E402
    collection_service,
    goal_service,
    quest_service,
    recognition_service,
    story_service,
)
from app.services.mastery_service import mastered_phoneme_ids  # noqa: E402
from app.services.streak_service import streak_summary, week_start  # noqa: E402

results: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> bool:
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n       {detail}" if detail else ""))
    return ok


def _report() -> int:
    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    passed = sum(1 for _, ok, _ in results if ok)
    failed = [n for n, ok, _ in results if not ok]
    print(f"{passed}/{len(results)} passed")
    if failed:
        print("\nFAILED:")
        for name in failed:
            print(f"  - {name}")
    return 1 if failed else 0


async def _score(db, child_id: int, exercise: Exercise, value: float, when: date):
    """Record an attempt as if the child had submitted audio on `when`."""
    db.add(
        PronunciationScore(
            exercise_id=exercise.id,
            user_id=child_id,
            phoneme_id=exercise.phonemes[0].id if exercise.phonemes else None,
            score=value,
            # Midday, so a timezone wobble cannot push it into another day.
            timestamp=datetime.combine(when, time(12, 0)),
        )
    )


async def _exercises_for(db, phoneme_order: int) -> list[Exercise]:
    from sqlalchemy.orm import selectinload

    return list(
        (
            await db.execute(
                select(Exercise)
                .options(selectinload(Exercise.phonemes))
                .join(Exercise.phonemes)
                .where(Phoneme.order == phoneme_order)
                .order_by(Exercise.id)
            )
        ).scalars().all()
    )


async def main() -> int:
    async with AsyncSessionLocal() as db:
        stamp = int(datetime.utcnow().timestamp())
        child = User(
            name="Engagement Probe",
            user_name=f"engagement-probe-{stamp}",
            role=UserRole.STUDENT,
        )
        db.add(child)
        await db.flush()
        db.add(LearningGoal(child_id=child.id, lessons_per_week=3))
        await db.commit()
        print(f"probe child id={child.id}\n")

        try:
            return await run_checks(db, child.id)
        finally:
            # Clean up in FK order. A probe row left behind would show up
            # in the parent dashboard of whoever runs this next.
            for model in (
                PronunciationScore,
                PhonemeUnlock,
                RecognitionAttempt,
                StreakFreeze,
                WeeklyGoal,
                LearningGoal,
            ):
                await db.execute(delete(model).where(
                    (model.user_id if model is PronunciationScore else model.child_id)
                    == child.id
                ))
            await db.execute(delete(DailyQuest).where(DailyQuest.child_id == child.id))
            await db.execute(delete(User).where(User.id == child.id))
            await db.commit()
            print("\nprobe child removed")


async def _goal_checks(db, exercise: Exercise, today: date) -> None:
    """The whole arc of one week's promise, on a child made for it."""
    child = User(
        name="Goal Probe",
        user_name=f"goal-probe-{int(datetime.utcnow().timestamp())}",
        role=UserRole.STUDENT,
    )
    db.add(child)
    await db.flush()
    try:
        # A quiet-but-real last week: two days. That is the history the
        # targets are sized from.
        last_week = week_start(today) - timedelta(days=7)
        for offset in (0, 2):
            await _score(db, child.id, exercise, 88.0, last_week + timedelta(days=offset))
        await db.commit()

        options = await goal_service.options_for(db, child.id, today)
        check("the child is offered three ways to spend the week",
              len(options) == 3,
              f"{[(o.kind.value, o.target) for o in options]}")
        check("every option is a real number to aim at",
              all(o.target >= 1 for o in options),
              f"targets={[o.target for o in options]}")
        check("no week ever asks for a perfect attendance record",
              all(o.target <= 6 for o in options if o.kind is GoalKind.DAYS),
              "a seven-day goal fails on one busy Tuesday")

        days_option = next(o for o in options if o.kind is GoalKind.DAYS)
        check("the goal is one step past their own best week",
              days_option.target == 3,
              f"two days last week, asked for {days_option.target}")
        check("nothing is chosen until the child chooses",
              await goal_service.current_goal(db, child.id, today) is None)

        goal = await goal_service.choose(db, child.id, GoalKind.DAYS, today)
        check("choosing writes the promise down",
              goal.kind is GoalKind.DAYS and goal.target == days_option.target,
              f"{goal.kind.value} x{goal.target}")

        state = await goal_service.progress(db, child.id, today)
        check("a fresh week starts at nothing done",
              state.done == 0 and not state.is_complete,
              f"{state.done}/{state.target}")
        check("no prize before the goal is met",
              not await goal_service.earned_weeks(db, child.id))

        # Choosing again mid-week must not swap the promise for whichever
        # one happens to be closest to done.
        again = await goal_service.choose(db, child.id, GoalKind.SOUNDS_MASTERED, today)
        check("the promise cannot be swapped later in the week",
              again.kind is GoalKind.DAYS and again.target == goal.target,
              f"still {again.kind.value} x{again.target}")

        # Part-way. This is the state the child spends most of the week in
        # and the one the app has to show without any hint of falling short.
        await _score(db, child.id, exercise, 90.0, week_start(today))
        await db.commit()
        part = await goal_service.progress(db, child.id, today)
        check("progress counts the days as they happen",
              part.done == 1 and part.remaining == goal.target - 1,
              f"{part.done}/{part.target}, {part.remaining} to go")
        check("the target does not move as the child gets going",
              part.target == goal.target,
              f"{goal.target} then {part.target}")

        for offset in (1, 2):
            day = week_start(today) + timedelta(days=offset)
            if day <= today:
                await _score(db, child.id, exercise, 90.0, day)
        await db.commit()

        finished = await goal_service.progress(db, child.id, today)
        check("meeting the target completes the goal",
              finished.is_complete and finished.completed_at is not None,
              f"{finished.done}/{finished.target}")

        earned = await goal_service.earned_weeks(db, child.id)
        check("a finished week leaves a prize on the shelf",
              [e.week_start for e in earned] == [week_start(today)],
              f"earned={[(e.week_start, e.kind.value) for e in earned]}")
        check("the prize remembers what the week was spent on",
              earned[0].kind is GoalKind.DAYS if earned else False,
              f"kind={earned[0].kind.value if earned else 'none'}")

        stamped = finished.completed_at
        again_read = await goal_service.progress(db, child.id, today)
        check("the prize is not re-awarded on every read",
              again_read.completed_at == stamped,
              f"{stamped} then {again_read.completed_at}")

        # A bad run afterwards must not take it back, the same rule the
        # collectibles follow.
        check("a prize already earned is kept",
              week_start(today)
              in [e.week_start for e in await goal_service.earned_weeks(db, child.id)])
    finally:
        for model in (PronunciationScore, WeeklyGoal, StreakFreeze):
            await db.execute(delete(model).where(
                (model.user_id if model is PronunciationScore else model.child_id)
                == child.id
            ))
        await db.execute(delete(User).where(User.id == child.id))
        await db.commit()


async def run_checks(db, child_id: int) -> int:
    today = date.today()

    print("=" * 70)
    print("A CHILD WHO HAS DONE NOTHING YET")
    print("=" * 70)

    # Runs first because it is the only moment this child is new. The
    # listening game is the rung below speaking and has to work on day
    # one, before a single word has been said into the microphone.
    first_round = await recognition_service.build_round(
        db, child_id, mode=RecognitionMode.EXPLORE, rng=random.Random(3)
    )
    targets = {q.target.id for q in first_round}
    check("a brand-new child gets a full round", len(first_round) >= 3,
          f"n={len(first_round)}")
    check("and it is not the same two sounds over and over",
          len(targets) >= 3,
          f"{len(targets)} different sounds: "
          f"{[q.target.symbol for q in first_round]}")
    check("nothing is recognised before anything is answered",
          not await recognition_service.recognised_phoneme_ids(db, child_id))

    print()
    print("=" * 70)
    print("MASTERY AND COLLECTIBLES")
    print("=" * 70)

    # /a/ is order 1. Two good attempts is the documented bar.
    a_exercises = await _exercises_for(db, 1)
    if not a_exercises:
        # Order 1 carries no exercise in this database; fall back to the
        # first order that does, so the probe still means something.
        for order in range(2, 30):
            a_exercises = await _exercises_for(db, order)
            if a_exercises:
                break
    check("the curriculum has exercises to practise", bool(a_exercises),
          f"n={len(a_exercises)}")
    if not a_exercises:
        return 1

    target = a_exercises[0]
    target_phoneme = target.phonemes[0]

    await _score(db, child_id, target, 95.0, today)
    await db.commit()
    mastered = await mastered_phoneme_ids(db, child_id)
    check("one high attempt is not yet mastery", target_phoneme.id not in mastered,
          f"mastered={sorted(mastered)}")

    await _score(db, child_id, target, 92.0, today)
    await db.commit()
    mastered = await mastered_phoneme_ids(db, child_id)
    check("a second high attempt earns mastery", target_phoneme.id in mastered,
          f"symbol=/{target_phoneme.symbol}/ mastered={sorted(mastered)}")

    pending = await collection_service.sync_unlocks(db, child_id)
    check("mastery unlocks the collectible",
          any(u.phoneme_id == target_phoneme.id for u in pending),
          f"pending={[u.phoneme_id for u in pending]}")

    pending_again = await collection_service.sync_unlocks(db, child_id)
    check("an unseen unlock is still offered on the next sync",
          len(pending_again) == len(pending),
          f"{len(pending)} then {len(pending_again)}")

    acknowledged = await collection_service.mark_seen(db, child_id)
    after_seen = await collection_service.sync_unlocks(db, child_id)
    check("acknowledging clears the celebration exactly once",
          acknowledged == len(pending) and after_seen == [],
          f"acknowledged={acknowledged} still_pending={len(after_seen)}")

    # A bad day must not take the sticker back.
    await _score(db, child_id, target, 10.0, today)
    await _score(db, child_id, target, 10.0, today)
    await _score(db, child_id, target, 10.0, today)
    await db.commit()
    still_mastered = target_phoneme.id in await mastered_phoneme_ids(db, child_id)
    unlocks = await collection_service.all_unlocks(db, child_id)
    check("a collectible survives the average falling back",
          target_phoneme.id in unlocks,
          f"average has dropped below mastery: {not still_mastered}")

    print()
    print("=" * 70)
    print("STORIES")
    print("=" * 70)

    stories = await story_service.list_stories(db, child_id)
    check("the shelf has stories on it", bool(stories), f"n={len(stories)}")
    check("nothing is unlocked by one mastered sound",
          all(not s.is_unlocked for s in stories),
          f"unlocked={[s.title for s in stories if s.is_unlocked]}")

    # Master everything a chosen story needs and it must open.
    paragraph = next((s for s in stories if s.word_count <= 30), stories[0] if stories else None)
    if paragraph:
        story_row = (
            await db.execute(select(Exercise).where(Exercise.id == paragraph.exercise_id))
        ).scalar_one()
        phonemes = (
            await db.execute(select(Phoneme).order_by(Phoneme.order))
        ).scalars().all()
        # Practise every sound in the curriculum up to the last one the
        # story needs, which is what a child who reached this story would
        # have done.
        exercises_by_phoneme: dict[int, Exercise] = {}
        for order in range(1, 91):
            found = await _exercises_for(db, order)
            if found:
                exercises_by_phoneme[order] = found[0]

        for order in sorted(exercises_by_phoneme):
            ex = exercises_by_phoneme[order]
            await _score(db, child_id, ex, 96.0, today)
            await _score(db, child_id, ex, 94.0, today)
        await db.commit()

        reopened = await story_service.list_stories(db, child_id)
        opened = [s for s in reopened if s.is_unlocked]
        check("mastering the curriculum opens stories", bool(opened),
              f"{len(opened)}/{len(reopened)} unlocked: {[s.title for s in opened][:3]}")
        check("an open story carries its text",
              all(s.content for s in opened), "some unlocked story had no content")
        check("a story still locked names the sound in the way",
              all(s.blocking_phoneme for s in reopened if not s.is_unlocked)
              or all(s.is_unlocked for s in reopened),
              f"locked={[(s.title, s.blocking_phoneme) for s in reopened if not s.is_unlocked][:3]}")

    print()
    print("=" * 70)
    print("DAILY QUEST")
    print("=" * 70)

    quest = await quest_service.get_or_create_today(db, child_id)
    slots = [i.slot for i in quest.items]
    check("the quest fills every slot it can", bool(quest.items),
          f"slots={[s.value for s in slots]}")
    check("slots are unique", len(slots) == len(set(slots)), f"slots={slots}")

    # This child has attempted many sounds and scored badly on the first,
    # so the review slot has something obvious to pick.
    review = next((i for i in quest.items if i.slot == QuestSlot.REVIEW), None)
    check("the review slot picks a sound the child is weak on",
          review is not None,
          f"review={review.exercise.content if review else 'not filled'}")

    ids = [i.exercise.id for i in quest.items]
    quest2 = await quest_service.get_or_create_today(db, child_id)
    check("the quest does not re-roll", [i.exercise.id for i in quest2.items] == ids,
          f"{ids} then {[i.exercise.id for i in quest2.items]}")

    check("completion tracks the attempts already made today",
          quest2.completed_count == sum(1 for i in quest2.items if i.completed),
          f"{quest2.completed_count}/{len(quest2.items)} complete")

    print()
    print("=" * 70)
    print("STREAK AND FREEZES")
    print("=" * 70)

    summary = await streak_summary(db, child_id, today)
    check("today's practice counts as a streak of 1", summary.days == 1,
          f"days={summary.days}")

    # Give the child a full qualifying week ending yesterday, then skip a
    # day: the freeze must be earned and then spent without being asked.
    for offset in (2, 3, 4):
        await _score(db, child_id, target, 88.0, today - timedelta(days=offset))
    await db.commit()

    summary = await streak_summary(db, child_id, today)
    check("practising the parent's weekly goal earns a freeze",
          summary.freezes_available + len(summary.frozen_dates) >= 1,
          f"available={summary.freezes_available} spent={summary.frozen_dates}")
    check("the freeze bridges the missed day",
          (today - timedelta(days=1)) in summary.frozen_dates,
          f"frozen={summary.frozen_dates}")
    check("the bridged run is counted end to end", summary.days == 5,
          f"days={summary.days} (today + frozen + 3 practised)")

    before = summary.frozen_dates
    summary = await streak_summary(db, child_id, today)
    check("re-reading does not spend a second freeze",
          summary.frozen_dates == before,
          f"{before} then {summary.frozen_dates}")

    print()
    print("=" * 70)
    print("RECOGNITION")
    print("=" * 70)

    rng = random.Random(7)
    explore = await recognition_service.build_round(
        db, child_id, mode=RecognitionMode.EXPLORE, rng=rng
    )
    check("a round builds", bool(explore), f"n={len(explore)}")
    if not explore:
        return _report()

    check("the answer is always on screen",
          all(q.target in q.options for q in explore),
          f"targets={[q.target.symbol for q in explore]}")
    check("no symbol appears twice in one question",
          all(len({o.id for o in q.options}) == len(q.options) for q in explore),
          f"widths={[q.option_count for q in explore]}")
    check("an unasked sound starts as a straight choice of two",
          all(q.option_count == 2 for q in explore),
          f"widths={[q.option_count for q in explore]}")
    check("every option can actually be heard",
          all(o.id for q in explore for o in q.options),
          f"{sum(len(q.options) for q in explore)} options, each a real phoneme")

    # EXPLORE is the way in, not the test: getting it right while every
    # symbol is audible proves the child can compare, not that they know.
    first = explore[0].target
    await recognition_service.record_answers(db, child_id, [
        recognition_service.SubmittedAnswer(
            phoneme_id=first.id,
            chosen_phoneme_id=first.id,
            mode=RecognitionMode.EXPLORE,
            option_count=4,
        )
        for _ in range(4)
    ])
    check("explore answers never count towards recognising a sound",
          first.id not in await recognition_service.recognised_phoneme_ids(db, child_id),
          f"/{first.symbol}/ after 4 correct explore answers")

    # Three in a row out of four, in CHOOSE, is the documented bar.
    for _ in range(recognition_service.RECOGNITION_STREAK):
        await recognition_service.record_answers(db, child_id, [
            recognition_service.SubmittedAnswer(
                phoneme_id=first.id,
                chosen_phoneme_id=first.id,
                mode=RecognitionMode.CHOOSE,
                option_count=4,
            )
        ])
    recognised = await recognition_service.recognised_phoneme_ids(db, child_id)
    check("three correct out of four earns the sound", first.id in recognised,
          f"/{first.symbol}/ recognised={sorted(recognised)}")

    # A second sound, right three times but only ever out of two symbols.
    narrow = next(q.target for q in explore if q.target.id != first.id)
    for _ in range(recognition_service.RECOGNITION_STREAK):
        await recognition_service.record_answers(db, child_id, [
            recognition_service.SubmittedAnswer(
                phoneme_id=narrow.id,
                chosen_phoneme_id=narrow.id,
                mode=RecognitionMode.CHOOSE,
                option_count=2,
            )
        ])
    check("winning a coin toss three times does not",
          narrow.id not in await recognition_service.recognised_phoneme_ids(db, child_id),
          f"/{narrow.symbol}/ at two symbols")

    stats = await recognition_service.stats_by_phoneme(db, child_id)
    check("the field widens for a child who is steady",
          stats[narrow.id].next_option_count == 3,
          f"next width for /{narrow.symbol}/ = {stats[narrow.id].next_option_count}")

    # A wrong answer, recorded as the confusion it is.
    wrong = next(o for o in explore[0].options if o.id != first.id)
    await recognition_service.record_answers(db, child_id, [
        recognition_service.SubmittedAnswer(
            phoneme_id=first.id,
            chosen_phoneme_id=wrong.id,
            mode=RecognitionMode.CHOOSE,
            option_count=4,
        )
    ])
    matrix = await recognition_service.confusion_counts(db, child_id)
    check("a wrong answer records which sound was reached for instead",
          matrix.get(first.id, {}).get(wrong.id) == 1,
          f"/{first.symbol}/ -> /{wrong.symbol}/ {matrix.get(first.id)}")
    check("a recent mistake takes the sound back off the recognised list",
          first.id not in await recognition_service.recognised_phoneme_ids(db, child_id),
          f"/{first.symbol}/ was recognised until this answer")

    stats = await recognition_service.stats_by_phoneme(db, child_id)
    check("a wrong answer narrows the field again",
          stats[first.id].next_option_count == 3,
          f"next width for /{first.symbol}/ = {stats[first.id].next_option_count}")

    # Abandonment: the child put the phone down. Stored, never held
    # against them, and kept out of the confusion matrix.
    await recognition_service.record_answers(db, child_id, [
        recognition_service.SubmittedAnswer(
            phoneme_id=narrow.id,
            chosen_phoneme_id=None,
            mode=RecognitionMode.CHOOSE,
            option_count=3,
        )
    ])
    after = await recognition_service.stats_by_phoneme(db, child_id)
    check("an abandoned question is not counted as a wrong answer",
          after[narrow.id].asked == stats[narrow.id].asked
          and after[narrow.id].recent_correct_streak
          == stats[narrow.id].recent_correct_streak,
          f"asked {stats[narrow.id].asked} -> {after[narrow.id].asked}")
    check("an abandoned question does not enter the confusion matrix",
          narrow.id not in await recognition_service.confusion_counts(db, child_id),
          f"no confusion recorded against /{narrow.symbol}/")

    # The two tracks stay separate: this child has mastered the whole
    # curriculum by production and recognises almost none of it. That gap
    # is the point — averaging the two would hide it.
    await collection_service.sync_unlocks(db, child_id)
    unlocks = await collection_service.all_unlocks(db, child_id)
    recognised = await recognition_service.recognised_phoneme_ids(db, child_id)
    check("recognising and saying a sound are tracked apart",
          len(unlocks) > len(recognised),
          f"{len(unlocks)} unlocked, {len(recognised)} recognised")

    # Sounds never asked about come first by design, so what this checks
    # is the other end: a sound the child has just had right three times
    # must not keep coming back while eighty others have never been seen.
    later = await recognition_service.build_round(
        db, child_id, mode=RecognitionMode.CHOOSE, rng=random.Random(11)
    )
    check("a settled sound is not asked again straight away",
          narrow.id not in {q.target.id for q in later},
          f"targets={[q.target.symbol for q in later]}")

    print()
    print("=" * 70)
    print("THIS WEEK'S PROMISE")
    print("=" * 70)

    # On its own child, because the arc that matters — nothing done, a
    # promise made, the promise kept — cannot be walked by the probe
    # above, which has already mastered the entire curriculum this week
    # and would meet every goal the moment it chose one.
    await _goal_checks(db, target, today)

    print()
    print("=" * 70)
    print("WHAT COUNTS AS TURNING UP")
    print("=" * 70)

    # A day spent entirely in the listening game is a day of practice.
    # This is the child on a bad connection, and their streak has to
    # survive it — the game exists precisely for that day.
    listener = User(
        name="Listening Probe",
        user_name=f"listen-probe-{int(datetime.utcnow().timestamp())}",
        role=UserRole.STUDENT,
    )
    db.add(listener)
    await db.flush()
    try:
        phoneme = (
            await db.execute(select(Phoneme).order_by(Phoneme.order).limit(1))
        ).scalar_one()
        db.add(RecognitionAttempt(
            child_id=listener.id,
            phoneme_id=phoneme.id,
            chosen_phoneme_id=phoneme.id,
            is_correct=True,
            mode=RecognitionMode.CHOOSE,
            option_count=4,
        ))
        await db.commit()

        summary = await streak_summary(db, listener.id, today)
        check("a day of the listening game counts as practice",
              summary.days == 1, f"days={summary.days}")

        db.add(RecognitionAttempt(
            child_id=listener.id,
            phoneme_id=phoneme.id,
            chosen_phoneme_id=None,
            is_correct=False,
            mode=RecognitionMode.CHOOSE,
            option_count=4,
        ))
        await db.commit()
        after = await streak_summary(db, listener.id, today)
        check("abandoning a round does not manufacture a practice day",
              after.days == 1, f"days={after.days}")
    finally:
        await db.execute(
            delete(RecognitionAttempt).where(RecognitionAttempt.child_id == listener.id)
        )
        await db.execute(delete(User).where(User.id == listener.id))
        await db.commit()

    return _report()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
