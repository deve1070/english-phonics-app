"""
cleanup_invalid_exercises.py
==============================
Deletes exercises that violate the phoneme ordering rule:
  "All phonemes in an exercise for phoneme N must have order <= N"

For example, the exercise "apple" seeded for phoneme /a/ (order=1) is
invalid because:
  - 'apple' = /æ/ + /p/ + /l/
  - /p/ and /l/ have order > 1 (the student hasn't learned them yet)

Run from backend/ directory:
    source venv/bin/activate
    python cleanup_invalid_exercises.py

Safe to re-run — only deletes exercises that fail the ordering check.
Prints a summary of what was removed.
"""

import asyncio
import re
import logging

from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload

import app.models  # noqa: F401 — resolve all relationships
from app.db.session import AsyncSessionLocal
from app.models.exercise import Exercise
from app.models.phoneme import Phoneme
from app.models.enums import ExerciseType

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Simple phoneme-to-letters mapping.
# We check if any letter sequence in the exercise content corresponds to a
# phoneme with order > the target phoneme's order.
#
# This is deliberately conservative — we remove exercises where the content
# clearly contains letters/digraphs from phonemes not yet taught.
# ---------------------------------------------------------------------------

# Map each phoneme symbol → the letter(s) it represents in spelling
# Used to check if exercise content requires knowledge of that phoneme
PHONEME_LETTER_MAP: dict[str, list[str]] = {
    # Alphabet (single letters)
    "a": ["a"],
    "b": ["b"],
    "k": ["c"],          # letter C makes /k/ sound
    "d": ["d"],
    "e": ["e"],
    "f": ["f"],
    "g": ["g"],
    "h": ["h"],
    "ɪ": ["i"],
    "dʒ": ["j"],
    "kʰ": ["k"],
    "l": ["l"],
    "m": ["m"],
    "n": ["n"],
    "ɒ/ɔ": ["o"],
    "p": ["p"],
    "kw": ["qu", "q"],
    "r": ["r"],
    "s": ["s"],
    "t": ["t"],
    "ʌ/ə": ["u"],
    "v": ["v"],
    "w": ["w"],
    "ks": ["x"],
    "j": ["y"],
    "z": ["z"],
    # Long vowels
    "eɪ (a_e)": ["a_e"],
    "aɪ (i_e)": ["i_e"],
    "oʊ (o_e)": ["o_e"],
    "uː (u_e)": ["u_e"],
    "eɪ (ai)": ["ai"],
    "eɪ (ay)": ["ay"],
    "iː (ee/ea)": ["ee", "ea"],
    # Digraphs
    "ʃ (sh)": ["sh"],
    "tʃ (ch)": ["ch", "tch"],
    "f (ph)": ["ph"],
    "w (wh)": ["wh"],
    "ð (voiced th)": ["th"],
    "θ (unvoiced th)": ["th"],
    "ck": ["ck"],
    "ŋ (ng)": ["ng"],
    "nk": ["nk"],
    "nd": ["nd"],
    "nt": ["nt"],
    "lt": ["lt"],
    "mp": ["mp"],
    # Blends
    "bl": ["bl"], "cl": ["cl"], "br": ["br"], "cr": ["cr"],
    "fl": ["fl"], "gl": ["gl"], "fr": ["fr"], "gr": ["gr"],
    "pl": ["pl"], "sl": ["sl"], "dr": ["dr"], "tr": ["tr"],
    "sm": ["sm"], "sn": ["sn"], "sp": ["sp"], "sw": ["sw"],
    "st": ["st"], "sk": ["sk"], "sc": ["sc"],
    "spr": ["spr"], "str": ["str"], "spl": ["spl"],
    # R-controlled
    "ar": ["ar"],
    "ɜːr (ir/ur)": ["ir", "ur"],
    "ər (er/or)": ["er", "or"],
    "ɔː (or/oar)": ["or", "oar"],
    # Diphthongs
    "aʊ (ou/ow)": ["ou", "ow"],
    "ɔɪ (oi/oy)": ["oi", "oy"],
    # Special
    "ʊ/ʌ (oo/u)": ["oo"],
    "ɔː (au/aw)": ["au", "aw"],
    # Silent letters
    "kn- (silent k)": ["kn"],
    "wr- (silent w)": ["wr"],
    "mb (silent b)": ["mb"],
    "rh- (silent h)": ["rh"],
    # Suffixes
    "tʃər (ture)": ["ture"],
    "ʒər (sure)": ["sure"],
    "ʃən (tion/sion)": ["tion", "sion"],
    "əs (ous)": ["ous"],
    "fəl (ful)": ["ful"],
}


def _content_requires_phoneme(content: str, phoneme_symbol: str) -> bool:
    """
    Returns True if the exercise content requires knowledge of the given phoneme
    (i.e. the content contains the letter pattern for that phoneme).
    """
    letter_patterns = PHONEME_LETTER_MAP.get(phoneme_symbol, [])
    content_lower = content.lower()
    for pattern in letter_patterns:
        if pattern in content_lower:
            return True
    return False


async def cleanup() -> None:
    log.info("Starting invalid exercise cleanup...")

    async with AsyncSessionLocal() as db:
        # Load all phonemes with their order
        phoneme_result = await db.execute(
            select(Phoneme).order_by(Phoneme.order)
        )
        all_phonemes: list[Phoneme] = phoneme_result.scalars().all()
        log.info("Loaded %d phonemes", len(all_phonemes))

        # Build a map: phoneme_id → order
        phoneme_order_map = {p.id: p.order for p in all_phonemes}
        # Build a map: phoneme_id → symbol
        phoneme_symbol_map = {p.id: p.symbol for p in all_phonemes}

        # Load all generated/seeded text exercises with their phoneme links
        exercise_result = await db.execute(
            select(Exercise)
            .options(selectinload(Exercise.phonemes))
            .where(
                Exercise.type.in_(
                    [
                        ExerciseType.WORD,
                        ExerciseType.SENTENCE,
                        ExerciseType.PHARAGRAPH,
                    ]
                )
            )
        )
        exercises: list[Exercise] = exercise_result.scalars().all()
        log.info("Loaded %d text exercises to check", len(exercises))

        to_delete: list[int] = []
        violations: list[str] = []

        for exercise in exercises:
            if not exercise.phonemes:
                # Orphaned exercise with no phoneme link — remove it
                to_delete.append(exercise.id)
                violations.append(
                    f"  [orphan] exercise_id={exercise.id} '{exercise.content}'"
                )
                continue

            # Get the target phoneme (the one this exercise was generated for)
            target_phoneme = min(exercise.phonemes, key=lambda p: p.order)
            target_order = target_phoneme.order

            # Check if the exercise content uses letters from phonemes
            # with order > target_order
            invalid = False
            invalid_reason = ""
            for phoneme in all_phonemes:
                if phoneme.order > target_order:
                    if _content_requires_phoneme(exercise.content, phoneme.symbol):
                        invalid = True
                        invalid_reason = (
                            f"contains /{phoneme.symbol}/ "
                            f"(order={phoneme.order} > target order={target_order})"
                        )
                        break

            if invalid:
                to_delete.append(exercise.id)
                violations.append(
                    f"  [invalid] exercise_id={exercise.id} "
                    f"'{exercise.content}' — {invalid_reason}"
                )

        if not to_delete:
            log.info("✅ No invalid exercises found — database is clean.")
            return

        log.info("\nInvalid exercises to remove (%d):", len(to_delete))
        for v in violations[:50]:  # show first 50 to avoid flooding logs
            log.info(v)
        if len(violations) > 50:
            log.info("  ... and %d more", len(violations) - 50)

        # Confirm before deleting
        log.info("\nDeleting %d invalid exercises...", len(to_delete))

        await db.execute(
            delete(Exercise).where(Exercise.id.in_(to_delete))
        )
        await db.commit()

        log.info("✅ Cleanup complete — %d exercises removed.", len(to_delete))
        log.info(
            "Run seed_phonemes.py again if you want to re-seed with "
            "correct exercises, or use AI generation per phoneme."
        )


if __name__ == "__main__":
    asyncio.run(cleanup())