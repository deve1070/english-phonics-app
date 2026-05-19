"""
Seed lessons/phonemes/exercises from phoneme.json.

Behavior:
- Preserves phoneme order exactly as listed in phoneme.json.
- Creates lesson order based on first appearance in that phoneme sequence.
- Seeds only WORD exercises that satisfy the current ordering constraint.
"""

import asyncio
import json
import logging
import re
from pathlib import Path
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

import app.models  # noqa: F401
from app.db.session import AsyncSessionLocal
from app.models.enums import ExerciseType, Level, PhonemeType
from app.models.exercise import Exercise
from app.models.lesson import Lesson
from app.models.phoneme import Phoneme

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger(__name__)

PHONEME_JSON_PATH = Path(__file__).resolve().parent / "phoneme.json"

PHONEME_TYPE_MAP: dict[str, PhonemeType] = {
    "alphabet": PhonemeType.ALPHABET,
    "long vowel": PhonemeType.LONG_VOWEL,
    "short vowel": PhonemeType.SHORT_VOWEL,
    "consonant blend": PhonemeType.CONSONANT_BLEND,
    "letter combination": PhonemeType.LETTER_COMBINATION,
    "r-controlled vowel": PhonemeType.R_CONTROLLED_VOWEL,
    "diphthong": PhonemeType.DIPHTHONG,
    "schwa": PhonemeType.SCHWA,
    "silent letters": PhonemeType.SILENT_LETTER,
    "suffix": PhonemeType.SUFFIX,
}

UNIT_LEVEL_MAP: dict[str, Level] = {
    "UNIT1": Level.LEVEL1,
    "UNIT2": Level.LEVEL1,
    "UNIT3": Level.LEVEL2,
    "UNIT4": Level.LEVEL2,
    "UNIT5": Level.LEVEL3,
    "UNIT6": Level.LEVEL3,
    "UNIT7": Level.LEVEL4,
    "UNIT8": Level.LEVEL5,
}


def load_phonemes() -> list[dict]:
    with PHONEME_JSON_PATH.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    phonemes = payload.get("phonemes", [])
    if not isinstance(phonemes, list):
        raise ValueError("Invalid phoneme.json: 'phonemes' must be a list.")
    return phonemes


def _build_allowed_graphemes(allowed_symbols: list[str]) -> set[str]:
    graphemes: set[str] = set()
    for symbol in allowed_symbols:
        normalized = re.sub(r"[^a-z]", "", (symbol or "").lower())
        if not normalized:
            continue
        graphemes.add(normalized)
        for char in normalized:
            graphemes.add(char)
    return graphemes


def _content_respects_allowed_graphemes(content: str, allowed_graphemes: set[str]) -> bool:
    words = re.findall(r"[a-z]+", (content or "").lower())
    if not words:
        return False

    max_len = max((len(g) for g in allowed_graphemes), default=1)
    for word in words:
        idx = 0
        while idx < len(word):
            matched = False
            max_window = min(max_len, len(word) - idx)
            for size in range(max_window, 0, -1):
                chunk = word[idx : idx + size]
                if chunk in allowed_graphemes:
                    idx += size
                    matched = True
                    break
            if not matched:
                return False
    return True


async def get_or_create_lesson(
    db: AsyncSession,
    unit: str,
    lesson_number: int,
    lesson_order: int,
) -> Lesson:
    level = UNIT_LEVEL_MAP[unit]
    result = await db.execute(select(Lesson).where(Lesson.order == lesson_order))
    lesson = result.scalar_one_or_none()
    if not lesson:
        lesson = Lesson(order=lesson_order, level=level)
        db.add(lesson)
        await db.flush()
        log.info(
            "  Created lesson: %s lesson %d (order=%d, level=%s)",
            unit,
            lesson_number,
            lesson_order,
            level.value,
        )
    return lesson


async def get_or_create_phoneme(
    db: AsyncSession,
    data: dict,
    lesson: Lesson,
    global_order: int,
) -> Optional[Phoneme]:
    result = await db.execute(select(Phoneme).where(Phoneme.symbol == data["symbol"]))
    phoneme = result.scalar_one_or_none()
    phoneme_type = PHONEME_TYPE_MAP.get((data.get("type") or "").strip().lower())
    if phoneme_type is None:
        log.warning(
            "  Unknown phoneme type '%s' for symbol '%s' — skipping",
            data.get("type"),
            data.get("symbol"),
        )
        return None

    if not phoneme:
        phoneme = Phoneme(
            symbol=data["symbol"],
            description=data.get("description", ""),
            audio_url=data.get("audio_url"),
            lesson_id=lesson.id,
            order=global_order,
            type=phoneme_type,
        )
        db.add(phoneme)
        await db.flush()
        log.info(
            "  Created phoneme: /%s/ (order=%d, type=%s)",
            data["symbol"],
            global_order,
            phoneme_type.value,
        )
    else:
        phoneme.description = data.get("description", phoneme.description)
        phoneme.audio_url = data.get("audio_url")
        phoneme.lesson_id = lesson.id
        phoneme.order = global_order
        phoneme.type = phoneme_type
        log.info("  Updated phoneme: /%s/ (order=%d)", data["symbol"], global_order)
    return phoneme


async def seed_exercises(
    db: AsyncSession,
    phoneme: Phoneme,
    word_list: list[str],
    allowed_symbols: list[str],
) -> None:
    allowed_graphemes = _build_allowed_graphemes(allowed_symbols)
    for word in word_list or []:
        word_text = (word or "").strip()
        if not word_text:
            continue
        if not _content_respects_allowed_graphemes(word_text, allowed_graphemes):
            log.info("    Skipping out-of-order exercise for /%s/: %s", phoneme.symbol, word)
            continue

        result = await db.execute(
            select(Exercise).where(
                Exercise.content == word_text,
                Exercise.lesson_id == phoneme.lesson_id,
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            continue

        exercise = Exercise(
            lesson_id=phoneme.lesson_id,
            content=word_text,
            type=ExerciseType.WORD,
            difficulty=1,
        )
        exercise.phonemes = [phoneme]
        db.add(exercise)


async def seed() -> None:
    phonemes = load_phonemes()
    log.info("Starting phoneme seed...")
    log.info("Total phonemes to process: %d", len(phonemes))

    lesson_sequence: dict[tuple[str, int], int] = {}
    next_lesson_order = 1
    for p in phonemes:
        key = (p["unit"], int(p["lesson"]))
        if key not in lesson_sequence:
            lesson_sequence[key] = next_lesson_order
            next_lesson_order += 1

    async with AsyncSessionLocal() as db:
        allowed_symbols_so_far: list[str] = []
        for global_order, data in enumerate(phonemes, start=1):
            unit = data["unit"]
            lesson_num = int(data["lesson"])
            lesson_order = lesson_sequence[(unit, lesson_num)]

            log.info(
                "Processing [%d/%d]: /%s/ (%s lesson=%d, lesson_order=%d)",
                global_order,
                len(phonemes),
                data["symbol"],
                unit,
                lesson_num,
                lesson_order,
            )

            lesson = await get_or_create_lesson(db, unit, lesson_num, lesson_order)
            phoneme = await get_or_create_phoneme(db, data, lesson, global_order)
            if not phoneme:
                continue

            allowed_symbols_so_far.append(phoneme.symbol)
            await seed_exercises(
                db,
                phoneme=phoneme,
                word_list=data.get("exercises", []),
                allowed_symbols=allowed_symbols_so_far,
            )

        await db.commit()

    log.info("")
    log.info("Seed complete.")
    log.info("Phoneme/lesson order now follows phoneme.json sequence exactly.")


if __name__ == "__main__":
    asyncio.run(seed())
