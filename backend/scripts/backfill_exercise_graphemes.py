"""Fill in exercises.graphemes for content that predates the column.

Run once after the b7c3d91f204e migration. Idempotent: rows that already
carry a segmentation are left alone unless --force is passed.

    venv/bin/python -m scripts.backfill_exercise_graphemes [--dry-run] [--force]

The segmentation is computed by app.curriculum.segmentation, which is a
greedy longest-match and therefore occasionally wrong — it reads
"mishap" as mi·sh·ap. Every result this script writes was read before it
was written; anything it cannot segment it refuses to guess at and
reports instead.

Two kinds of finding get printed and neither is fixed here:

  UNREADABLE  content using a spelling the curriculum never teaches.
              Nothing sensible to store, so the row stays null and the
              gate will withhold it.

  AHEAD       content that becomes readable later than the phoneme it
              is filed under. Two quite different things land here and
              the report separates them.

              A word filed under the sound it *practises* rather than
              its hardest letter is a filing choice, not a fault:
              "cat" teaches /a/ and is filed at sound 1, though a child
              cannot decode it until `t` at sound 20. Serving it early
              is the gate's problem to prevent, not the content's.

              Content resting on an untaught *digraph* is a real fault.
              "The cat sat on a mat." is filed at sound 1 and needs
              `th` from sound 55, so no child can read it for the first
              fifty-four sounds of the course — it is unusable exactly
              where it was meant to be used. The old check could not
              see this, which is how it got written.

              Neither is repaired here. Rewriting a teacher's content
              is not a migration's business.
"""

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import selectinload  # noqa: E402

from app.curriculum.segmentation import (  # noqa: E402
    build_inventory,
    required_order,
    segment_content,
)
from app.db.session import AsyncSessionLocal, engine  # noqa: E402
from app.models.exercise import Exercise  # noqa: E402
from app.models.phoneme import Phoneme  # noqa: E402


async def run(*, dry_run: bool, force: bool) -> int:
    async with AsyncSessionLocal() as db:
        phonemes = (
            await db.execute(select(Phoneme).order_by(Phoneme.order))
        ).scalars().all()
        inventory = build_inventory(phonemes)

        exercises = (
            await db.execute(
                select(Exercise).options(selectinload(Exercise.phonemes))
            )
        ).scalars().all()

        written = skipped = 0
        unreadable: list[tuple[Exercise, str]] = []
        ahead: list[tuple[Exercise, int, int, str]] = []

        for exercise in exercises:
            if exercise.graphemes and not force:
                skipped += 1
                continue

            pieces = segment_content(exercise.content, inventory)
            if pieces is None:
                unreadable.append((exercise, exercise.content))
                continue

            needs = required_order(pieces, inventory) or 0
            # The phoneme a piece of content is filed under is the sound
            # it is meant to practise, so it is also the point in the
            # course where a child meets it.
            filed_at = min((p.order for p in exercise.phonemes), default=needs)
            if needs > filed_at:
                hardest = max(
                    pieces, key=lambda p: inventory[p].order
                )
                ahead.append((exercise, filed_at, needs, hardest))

            if not dry_run:
                exercise.graphemes = ",".join(pieces)
            written += 1

        if not dry_run:
            await db.commit()

    await engine.dispose()

    verb = "would write" if dry_run else "wrote"
    print(f"{verb} {written} segmentations; skipped {skipped} already filled")

    if unreadable:
        print(f"\nUNREADABLE — {len(unreadable)} left null:")
        for exercise, content in unreadable:
            print(f"  [{exercise.id}] {content[:60]!r}")

    digraph = [row for row in ahead if len(row[3]) > 1]
    filing = [row for row in ahead if len(row[3]) == 1]

    if digraph:
        print(
            f"\nRESTS ON AN UNTAUGHT DIGRAPH — {len(digraph)}. "
            "Unreadable where it is meant to be used:"
        )
        for exercise, filed_at, needs, hardest in sorted(
            ahead, key=lambda r: r[2] - r[1], reverse=True
        ):
            if len(hardest) == 1:
                continue
            print(
                f"  [{exercise.id}] filed at sound {filed_at}, "
                f"`{hardest}` arrives at {needs}: {exercise.content[:50]!r}"
            )

    if filing:
        print(
            f"\nFILED UNDER THE SOUND IT PRACTISES — {len(filing)}. "
            "Not a fault; the gate holds these back until readable:"
        )
        for exercise, filed_at, needs, hardest in filing:
            print(
                f"  [{exercise.id}] filed at sound {filed_at}, "
                f"readable from {needs} (`{hardest}`): {exercise.content[:40]!r}"
            )

    return len(unreadable) + len(digraph)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    asyncio.run(run(dry_run=args.dry_run, force=args.force))
