"""Repair the thirteen exercises that rest on a sound taught later.

All thirteen were written against a decodability check that could not
fail once a child knew the alphabet, so nothing objected at the time.
With the check fixed they are simply withheld, which left the story
shelf shut for the first fifty-four sounds of the course.

Two kinds of repair, because there are two kinds of fault.

REWRITE — eleven sentences and stories whose only untaught spelling is
`th`, and always in the word "the". A definite article is not what any
of them is teaching, and "a" carries the sentence just as well. The
text changes; where it sits in the course does not.

REFILE — "back" and "bead" are not broken. "back" is exactly the word
to teach `ck` with, and "bead" the word for `ea`. Each was filed under
a letter it happens to contain — /k/ and /e/ — rather than under the
spelling that makes it worth reading. Moving them is not a
consolation: it puts each one where it teaches something.

Refiling moves what a child's attempt scores toward, since
pronunciation scores inherit their phoneme from this link. That is the
point. A child sounding out "back" is practising `ck`.

    venv/bin/python -m scripts.fix_mislevelled_content [--dry-run]

Nothing is written unless every replacement segments cleanly at the
order it will be served from. A repair that cannot be verified is not
a repair.
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

# exercise id -> replacement text. Keyed by id because the originals are
# near-duplicates of one another and matching on content would rewrite
# the wrong row.
REWRITE = {
    2: "A cat sat on a mat.",
    3: "A cat sat. It is a big cat. It ran fast.",
    44: "A cat sat on a red mat.",
    45: "A red pen is on a bed.",
    46: "A pup ran up a hill.",
    48: "A web is wet.",
    50: "A cat sat on a mat. A rat ran past it. It did not get cross.",
    51: "Dad has a red pen. It is in a tin. A tin is on top of a bed.",
    52: "Sam has a pup. It digs in mud. Sam gets a rag and rubs it. "
        "A pup is not sad.",
    53: "Ten hens sat in a pen. A big dog ran up to it. Hens ran in a hut. "
        "A dog did not get a hen.",
    54: "Wes has a red van. He gets in it and zips up a hill. He stops. "
        "A big cat sat on a van. Wes and a cat nap in it.",
}

# exercise id -> the grapheme it should have been filed under all along.
REFILE = {
    16: "ck",   # "back"
    8: "ea",    # "bead"
}


async def run(*, dry_run: bool) -> int:
    async with AsyncSessionLocal() as db:
        phonemes = (
            await db.execute(select(Phoneme).order_by(Phoneme.order))
        ).scalars().all()
        inventory = build_inventory(phonemes)

        wanted = set(REWRITE) | set(REFILE)
        exercises = {
            e.id: e
            for e in (
                await db.execute(
                    select(Exercise)
                    .options(selectinload(Exercise.phonemes))
                    .where(Exercise.id.in_(wanted))
                )
            ).scalars().all()
        }

        missing = wanted - set(exercises)
        if missing:
            print(f"! no such exercise: {sorted(missing)}")
            await engine.dispose()
            return 1

        problems: list[str] = []
        planned: list[tuple[Exercise, str, str, int]] = []

        for exercise_id, replacement in REWRITE.items():
            exercise = exercises[exercise_id]
            filed_at = min(p.order for p in exercise.phonemes)
            pieces = segment_content(replacement, inventory)
            if pieces is None:
                problems.append(
                    f"[{exercise_id}] replacement will not segment: {replacement!r}"
                )
                continue
            needs = required_order(pieces, inventory) or 0
            planned.append((exercise, replacement, ",".join(pieces), needs))
            print(
                f"  [{exercise_id}] filed {filed_at}, readable from {needs}\n"
                f"      was: {exercise.content}\n"
                f"      now: {replacement}"
            )

        by_grapheme = {}
        for phoneme in phonemes:
            for raw in (phoneme.graphemes or "").split(","):
                by_grapheme.setdefault(raw.strip(), phoneme)

        refiles: list[tuple[Exercise, Phoneme]] = []
        for exercise_id, grapheme in REFILE.items():
            exercise = exercises[exercise_id]
            target = by_grapheme.get(grapheme)
            if target is None:
                problems.append(f"[{exercise_id}] no phoneme teaches `{grapheme}`")
                continue
            was = ", ".join(f"/{p.symbol}/ ({p.order})" for p in exercise.phonemes)
            refiles.append((exercise, target))
            print(
                f"  [{exercise_id}] {exercise.content!r}: {was} "
                f"-> /{target.symbol}/ ({target.order}), which teaches `{grapheme}`"
            )

        if problems:
            print("\nrefusing to write:")
            for problem in problems:
                print(f"  ! {problem}")
            await engine.dispose()
            return 1

        if not dry_run:
            for exercise, replacement, graphemes, _ in planned:
                exercise.content = replacement
                exercise.graphemes = graphemes
            for exercise, target in refiles:
                exercise.phonemes = [target]
            await db.commit()

    await engine.dispose()
    verb = "would rewrite" if dry_run else "rewrote"
    print(f"\n{verb} {len(planned)}, refiled {len(refiles)}")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    raise SystemExit(asyncio.run(run(dry_run=args.dry_run)))
