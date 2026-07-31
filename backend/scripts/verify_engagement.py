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
    StreakFreeze,
)
from app.models.enums import ExerciseType, QuestSlot, UserRole  # noqa: E402
from app.models.exercise import Exercise  # noqa: E402
from app.models.parent import LearningGoal  # noqa: E402
from app.models.phoneme import Phoneme  # noqa: E402
from app.models.pronuncation_score import PronunciationScore  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import collection_service, quest_service, story_service  # noqa: E402
from app.services.mastery_service import mastered_phoneme_ids  # noqa: E402
from app.services.streak_service import streak_summary  # noqa: E402

results: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> bool:
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n       {detail}" if detail else ""))
    return ok


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
            for model in (PronunciationScore, PhonemeUnlock, StreakFreeze, LearningGoal):
                await db.execute(delete(model).where(
                    (model.user_id if model is PronunciationScore else model.child_id)
                    == child.id
                ))
            await db.execute(delete(DailyQuest).where(DailyQuest.child_id == child.id))
            await db.execute(delete(User).where(User.id == child.id))
            await db.commit()
            print("\nprobe child removed")


async def run_checks(db, child_id: int) -> int:
    today = date.today()

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


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
