"""
Exercise Generation Service
============================
Generates phonics exercises using Azure OpenAI, enforcing the phoneme
ordering rule: all content in exercises for phoneme N may only use
phonemes with order <= N.

Flow:
  1. Caller passes target phoneme + all prior phonemes (order <= N).
  2. We build a prompt listing only the allowed phonemes.
  3. Azure OpenAI returns a structured JSON list of exercises.
  4. We validate + save them via crud_exercise.bulk_create().
  5. Saved Exercise objects (with IDs) are returned to the caller.
"""

import json
import logging
import re
from typing import List

from app.core.config import settings
from app.crud.crud_exercise import crud_exercise
from app.models.enums import ExerciseType
from app.models.exercise import Exercise
from app.models.phoneme import Phoneme
from openai import AsyncAzureOpenAI
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

# ------------------------------------------------------------------
# Async Azure OpenAI client (fixes original sync-in-async bug)
#
# Built lazily (not at import time) so the app can still start up when
# Azure OpenAI credentials aren't configured (they're Optional in
# Settings) — the error only surfaces when generation is actually
# attempted, not on every app boot.
# ------------------------------------------------------------------
_client: AsyncAzureOpenAI | None = None


def _get_client() -> AsyncAzureOpenAI:
    global _client
    if _client is None:
        if not settings.AZURE_OPENAI_ENDPOINT or not settings.AZURE_OPENAI_API_KEY:
            raise RuntimeError(
                "AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_KEY are not configured. "
                "Exercise generation is unavailable until these are set."
            )
        _client = AsyncAzureOpenAI(
            api_version=settings.AZURE_OPENAI_API_VERSION,
            azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
            api_key=settings.AZURE_OPENAI_API_KEY,
        )
    return _client

# How many exercises to generate per type by default
DEFAULT_COUNTS = {
    ExerciseType.PHONEME: 0,
    ExerciseType.WORD: 5,
    ExerciseType.SENTENCE: 0,
    ExerciseType.PARAGRAPH: 0,
}


def _build_allowed_graphemes(allowed_phonemes: List[Phoneme]) -> set[str]:
    """
    Convert allowed phoneme symbols into a coarse grapheme allow-list.
    This is a lightweight guardrail to filter obvious LLM hallucinations.
    """
    graphemes: set[str] = set()
    for phoneme in allowed_phonemes:
        symbol = (phoneme.symbol or "").strip().lower()
        normalized = re.sub(r"[^a-z]", "", symbol)
        if not normalized:
            continue
        graphemes.add(normalized)
        for char in normalized:
            graphemes.add(char)
    return graphemes


def _content_respects_allowed_graphemes(content: str, allowed_graphemes: set[str]) -> bool:
    # Split into alphabetic words and greedily match longest known graphemes.
    words = re.findall(r"[a-z]+", content.lower())
    if not words:
        return True

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


def _build_prompt(
    target_phoneme: Phoneme,
    allowed_phonemes: List[Phoneme],
) -> str:
    """
    Build the system + user prompt for exercise generation.

    The allowed_phonemes list contains every phoneme with order <=
    target_phoneme.order, including the target itself. This is the
    complete set of sounds the child has already been taught.
    """
    allowed_symbols = ", ".join(
        f"/{p.symbol}/" for p in sorted(allowed_phonemes, key=lambda p: p.order)
    )
    counts = DEFAULT_COUNTS

    return f"""You are a phonics curriculum designer for young children (ages 4-8).

TARGET PHONEME: /{target_phoneme.symbol}/ ({target_phoneme.description or target_phoneme.type.value})

ALLOWED PHONEMES (the child has only learned these so far): {allowed_symbols}

STRICT RULE: Every word in every exercise must ONLY contain sounds from the allowed phonemes list above.
Do NOT use any phoneme the child has not yet learned. For example, if /t/ is not in the allowed list,
no word containing the /t/ sound may appear anywhere.

Generate the following exercises:
- {counts[ExerciseType.PHONEME]} PHONEME exercises: single phoneme sound practice (just the symbol or a minimal pair)
- {counts[ExerciseType.WORD]} WORD exercises: single words that prominently feature /{target_phoneme.symbol}/
- {counts[ExerciseType.SENTENCE]} SENTENCE exercises: short simple sentences (4-6 words)
- {counts[ExerciseType.PARAGRAPH]} PARAGRAPH exercise: 2-3 short sentences forming a mini story

Respond ONLY with a valid JSON array. No markdown, no explanation, no extra text.
Each item must have exactly these fields:
  "type":       one of "WORD", "PHONEME", "SENTENCE", "PARAGRAPH"
  "content":    the exercise text (string)
  "difficulty": integer 1 (easiest) to 3 (hardest)

Example format:
[
  {{"type": "PHONEME", "content": "/æ/", "difficulty": 1}},
  {{"type": "WORD", "content": "cat", "difficulty": 1}},
  {{"type": "SENTENCE", "content": "The cat sat.", "difficulty": 2}},
  {{"type": "PARAGRAPH", "content": "A cat sat on a mat. The cat had a nap.", "difficulty": 3}}
]"""


def _parse_response(
    raw: str, lesson_id: int, allowed_phonemes: List[Phoneme]
) -> List[dict]:
    """
    Parse and validate the JSON returned by Azure OpenAI.
    Returns a list of dicts ready for bulk_create.
    Skips any malformed items with a warning rather than crashing.
    """
    valid_types = {e.value for e in ExerciseType}

    try:
        items = json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.error("Azure OpenAI returned non-JSON: %s", raw[:300])
        raise ValueError(f"Exercise generation returned invalid JSON: {exc}") from exc

    if not isinstance(items, list):
        raise ValueError("Expected a JSON array from exercise generation.")

    parsed = []
    allowed_graphemes = _build_allowed_graphemes(allowed_phonemes)
    for item in items:
        raw_type = item.get("type", "").upper()
        content = item.get("content", "").strip()
        difficulty = item.get("difficulty", 1)

        if raw_type not in valid_types:
            logger.warning("Skipping exercise with unknown type: %s", raw_type)
            continue
        if not content:
            logger.warning("Skipping exercise with empty content.")
            continue
        if not isinstance(difficulty, int) or not (1 <= difficulty <= 3):
            difficulty = 1
        if raw_type in {
            ExerciseType.WORD.value,
            ExerciseType.SENTENCE.value,
            ExerciseType.PARAGRAPH.value,
        } and not _content_respects_allowed_graphemes(content, allowed_graphemes):
            logger.warning(
                "Skipping generated content with out-of-scope graphemes: %s", content
            )
            continue

        parsed.append(
            {
                "lesson_id": lesson_id,
                "content": content,
                "type": ExerciseType(raw_type),
                "difficulty": difficulty,
            }
        )

    return parsed


async def generate_exercises_for_phoneme(
    db: AsyncSession,
    *,
    target_phoneme: Phoneme,
    allowed_phonemes: List[Phoneme],
) -> List[Exercise]:
    """
    Main entry point.

    Parameters
    ----------
    db               : async DB session
    target_phoneme   : the Phoneme the child is currently learning
    allowed_phonemes : all Phoneme objects with order <= target_phoneme.order
                       (fetched by the caller / endpoint before invoking this)

    Returns
    -------
    List of saved Exercise objects with DB-assigned IDs.
    """
    prompt = _build_prompt(target_phoneme, allowed_phonemes)

    logger.info(
        "Generating exercises for phoneme /%s/ (lesson_id=%d)",
        target_phoneme.symbol,
        target_phoneme.lesson_id,
    )

    try:
        response = await _get_client().chat.completions.create(
            model=settings.AZURE_OPENAI_DEPLOYMENT_NAME,  # deployment name, e.g. "gpt-4o"
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7,
            max_tokens=1000,
        )
    except Exception as exc:
        logger.error("Azure OpenAI call failed: %s", exc)
        raise RuntimeError(f"Exercise generation failed: {exc}") from exc

    raw_content = response.choices[0].message.content or ""
    exercises_data = _parse_response(
        raw_content,
        lesson_id=target_phoneme.lesson_id,
        allowed_phonemes=allowed_phonemes,
    )

    if not exercises_data:
        raise ValueError(
            f"No valid exercises could be parsed for phoneme /{target_phoneme.symbol}/."
        )

    saved = await crud_exercise.bulk_create(
        db,
        exercises_data=exercises_data,
        phoneme=target_phoneme,
    )

    logger.info(
        "Saved %d exercises for phoneme /%s/",
        len(saved),
        target_phoneme.symbol,
    )
    return saved
