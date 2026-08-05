#!/usr/bin/env python3
"""
Backfill phoneme spellings and seed decodable practice content.

Two jobs, in one script because the second depends on the first.

1. **Spellings.** Every phoneme gets an explicit `graphemes` value. The
   curriculum records sounds as a mix of letter names ("Aa") and IPA
   ("ɪ", "kw"), and decodability was being inferred from that string —
   so /ɪ/ contributed no spelling at all and the letter `i` stayed
   undecodable even after the whole alphabet had been taught. That
   silently rejected most generated exercises and would have locked every
   story forever.

2. **Content.** Hand-written words, sentences and short stories for the
   first five lessons, each checked against the spellings a child knows
   at that point in the curriculum. This exists because Azure OpenAI
   generation is down (DeploymentNotFound) and the database holds three
   exercises in total — the daily quest has nothing to choose from and
   the story shelf is empty. Real content, written to the same rule the
   generator is held to, so it can be replaced by generated content
   later without anything downstream changing.

Idempotent: re-running updates spellings in place and skips content that
is already present, matched on (lesson, type, content).

Usage (from backend/):
  python scripts/seed_decodable_content.py            # apply
  python scripts/seed_decodable_content.py --check    # validate only
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import selectinload  # noqa: E402

from app.db.session import AsyncSessionLocal  # noqa: E402
from app.models.enums import ExerciseType  # noqa: E402
from app.models.exercise import Exercise  # noqa: E402
from app.models.phoneme import Phoneme  # noqa: E402
from app.curriculum.segmentation import (  # noqa: E402
    build_inventory,
    segment_content,
)

# ── 1. Spellings, by curriculum order ────────────────────────────────
#
# Orders 1-26 are the alphabet. Where the symbol is already a letter name
# this only makes explicit what was being inferred; where it is IPA it is
# the whole point.
#
# Split digraphs (a_e in "make") are recorded as the bare vowels they
# free up. The allow-list model matches contiguous runs of letters and
# cannot express "a, then any consonant, then e", so the choice is
# between over-permitting slightly and never decoding a magic-e word at
# all. Over-permitting is the right error: it is the same direction the
# quest's stretch slot errs in on purpose.
GRAPHEMES_BY_ORDER: dict[int, str] = {
    1: "a", 2: "b", 3: "c", 4: "d", 5: "e",
    6: "f", 7: "g", 8: "h", 9: "i", 10: "j",
    11: "k", 12: "l", 13: "m", 14: "n", 15: "o",
    16: "p", 17: "q", 18: "r", 19: "s", 20: "t",
    21: "u", 22: "v", 23: "w", 24: "x", 25: "y",
    26: "z",
    27: "a,e",           # a_e  make
    28: "i,e",           # i_e  bike
    29: "o,e",           # o_e  home
    30: "u,e",           # u_e  cube
    31: "ai", 32: "ay", 33: "ee,ea",
    34: "bl", 35: "cl", 36: "br", 37: "cr", 38: "fl",
    39: "gl", 40: "fr", 41: "gr", 42: "pl", 43: "sl",
    44: "dr", 45: "tr", 46: "sm", 47: "sn", 48: "sp",
    49: "sw", 50: "st",
    51: "sh", 52: "ch", 53: "ph", 54: "wh", 55: "th",
    56: "th", 57: "ck", 58: "qu", 59: "ng", 60: "nk",
    61: "nd", 62: "nt", 63: "lt", 64: "mp", 65: "sk",
    66: "sc", 67: "spr", 68: "str", 69: "spl", 70: "squ",
    71: "s",
    72: "ar", 73: "ir,ur", 74: "er,or", 75: "ou,ow",
    76: "oi,oy", 77: "oo,u", 78: "au,aw", 79: "or,oar",
    80: "a,e,i,o,u",     # schwa — any vowel letter, unstressed
    81: "kn", 82: "wr", 83: "mb", 84: "rh", 85: "st",
    86: "ture", 87: "sure", 88: "tion,sion", 89: "ous", 90: "ful",
}

# ── 2. Content ───────────────────────────────────────────────────────
#
# Keyed by the phoneme order it is attached to, which is also the point
# in the curriculum at which it becomes readable. Every entry is verified
# against the cumulative allow-list at that order before insert — the
# --check mode exists so a typo here fails loudly rather than quietly
# producing a word a child cannot decode.
#
# Words come first and stay short. The sentences are dull on purpose:
# a decodable sentence written before the child knows "the" or "was"
# cannot also be witty, and pretending otherwise produces the
# tongue-twisting nonsense that puts children off reading schemes.

# Every phoneme gets a bare sound exercise, generated from its spelling.
#
# Not decoration: a sound with no exercise attached can never be
# attempted, so it can never be mastered, so its collectible is
# unreachable and any story needing it stays locked forever. Words only
# cover a handful of the ninety sounds, which left most of the collection
# and most of the shelf permanently out of reach — caught by
# scripts/verify_engagement.py, which could not open a single story even
# after mastering everything that was practisable.
def phoneme_exercises() -> dict[int, list[str]]:
    return {
        order: [spelling.split(",")[0]]
        for order, spelling in GRAPHEMES_BY_ORDER.items()
    }


WORDS: dict[int, list[str]] = {
    4: ["dad", "bad", "add"],
    5: ["bed", "bead"],
    7: ["bag", "egg"],
    8: ["had", "hag"],
    9: ["did", "hid"],
    11: ["kid", "back"],
    12: ["leg", "lid"],
    13: ["mad", "ham"],
    14: ["man", "hen"],
    15: ["dog", "log"],
    16: ["pig", "pen"],
    18: ["red", "rag"],
    19: ["sad", "gas"],
    20: ["ten", "top", "net"],
    21: ["sun", "mud", "cup"],
    23: ["wet", "web"],
    26: ["zip", "buzz"],
}

SENTENCES: dict[int, list[str]] = {
    # "the" needs /t/, which arrives at order 20. Everything before that
    # has to work without the commonest word in English — which is why
    # these early lines read the way they do.
    15: ["A big dog.", "A hen had an egg."],
    16: ["A pig and a hen."],
    20: ["The cat sat on the mat.", "A red pen is on the bed."],
    21: ["The pup ran up the hill.", "Sam had a big mug."],
    23: ["The web is wet.", "We had ten red hens."],
}

# Stories are PARAGRAPH exercises. Each is attached to the last phoneme it
# needs, so the shelf opens one book at a time as a child works through
# the curriculum rather than all at once.
#
# The first story sits at order 20 rather than earlier: without /t/ there
# is no "the", "to", "it" or "not", and what is left is not a story.
STORIES: dict[int, list[str]] = {
    20: [
        "The cat sat on a mat. A rat ran past the cat. "
        "The cat did not get cross.",
        "Dad has a red pen. The pen is in a tin. "
        "The tin is on top of the bed.",
    ],
    21: [
        "Sam has a pup. The pup digs in the mud. "
        "Sam gets a rag and rubs the pup. The pup is not sad.",
        "Ten hens sat in a pen. A big dog ran up to the pen. "
        "The hens ran in the hut. The dog did not get a hen.",
    ],
    26: [
        "Wes has a red van. He gets in the van and zips up the hill. "
        "Then he stops. A big cat sat on the van. "
        "Wes and the cat sat in the sun.",
    ],
}


async def _load_phonemes(db) -> list[Phoneme]:
    return list(
        (await db.execute(select(Phoneme).order_by(Phoneme.order))).scalars().all()
    )


def _allowed_at(phonemes: list[Phoneme], order: int) -> set[str]:
    """Spellings a child knows once they have reached `order`.

    Built from the mapping this script is about to write rather than from
    what is currently stored, so --check on a database that has not been
    backfilled yet still validates the content honestly. Stand-in objects
    are used rather than assigning onto the real rows, which would make
    the backfill below report that it had nothing to do.
    """
    return build_inventory(
        [
            SimpleNamespace(
                symbol=p.symbol,
                graphemes=GRAPHEMES_BY_ORDER.get(p.order),
                order=p.order,
                type=p.type,
            )
            for p in phonemes
            if p.order <= order
        ]
    )


def _validate(phonemes: list[Phoneme]) -> list[str]:
    """Every seeded string checked against the curriculum. Returns problems."""
    problems: list[str] = []
    for label, table in (("word", WORDS), ("sentence", SENTENCES), ("story", STORIES)):
        for order, entries in table.items():
            allowed = _allowed_at(phonemes, order)
            for entry in entries:
                if segment_content(entry, allowed) is None:
                    problems.append(
                        f"{label} at order {order} is not decodable there: {entry!r}"
                    )
    return problems


async def backfill_graphemes(db, phonemes: list[Phoneme]) -> int:
    changed = 0
    for phoneme in phonemes:
        spelling = GRAPHEMES_BY_ORDER.get(phoneme.order)
        if spelling and phoneme.graphemes != spelling:
            phoneme.graphemes = spelling
            changed += 1
    if changed:
        await db.commit()
    return changed


async def seed_content(db, phonemes: list[Phoneme]) -> int:
    by_order = {p.order: p for p in phonemes}

    existing = {
        (e.lesson_id, e.type, e.content.strip())
        for e in (
            await db.execute(select(Exercise).options(selectinload(Exercise.phonemes)))
        ).scalars().all()
    }

    added = 0
    for table, ex_type, difficulty in (
        (phoneme_exercises(), ExerciseType.PHONEME, 1),
        (WORDS, ExerciseType.WORD, 1),
        (SENTENCES, ExerciseType.SENTENCE, 2),
        (STORIES, ExerciseType.PARAGRAPH, 3),
    ):
        for order, entries in sorted(table.items()):
            phoneme = by_order.get(order)
            if phoneme is None:
                print(f"  ! no phoneme at order {order}, skipping its content")
                continue
            allowed = _allowed_at(phonemes, order)
            for content in entries:
                content = content.strip()
                if (phoneme.lesson_id, ex_type, content) in existing:
                    continue
                # _validate has already refused to let the script run
                # with content that will not segment here, so this is
                # the same answer, kept rather than recomputed later
                # against a phoneme table that cannot reproduce it.
                pieces = segment_content(content, allowed)
                exercise = Exercise(
                    lesson_id=phoneme.lesson_id,
                    content=content,
                    type=ex_type,
                    difficulty=difficulty,
                    graphemes=",".join(pieces) if pieces else None,
                )
                # Linking to the phoneme is not decoration: pronunciation
                # scores inherit phoneme_id from here, and without it the
                # attempt cannot be attributed to a sound — no mastery, no
                # collectible, and nothing for the quest's review slot to
                # find.
                exercise.phonemes = [phoneme]
                db.add(exercise)
                added += 1
    if added:
        await db.commit()
    return added


async def main(check_only: bool) -> int:
    async with AsyncSessionLocal() as db:
        phonemes = await _load_phonemes(db)
        if not phonemes:
            print("No phonemes in the database — seed the curriculum first.")
            return 1

        problems = _validate(phonemes)
        if problems:
            print(f"{len(problems)} undecodable entries:")
            for problem in problems:
                print(f"  - {problem}")
            return 1
        print(
            f"All {sum(len(v) for v in (*WORDS.values(), *SENTENCES.values(), *STORIES.values()))} "
            "seeded entries are decodable at the point they are introduced."
        )

        if check_only:
            return 0

        changed = await backfill_graphemes(db, phonemes)
        print(f"Spellings written for {changed} phonemes.")
        added = await seed_content(db, phonemes)
        print(f"Added {added} exercises.")
        return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the content without writing anything",
    )
    args = parser.parse_args()
    raise SystemExit(asyncio.run(main(args.check)))
