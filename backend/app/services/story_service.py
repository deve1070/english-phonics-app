"""
Decodable stories.
==================
A story a child can read start to finish using only sounds they have
already mastered. Nothing else in a phonics app comes close to "I read a
whole book by myself" — it is the payoff the rest of the practice is for.

The gate is strict on purpose, and it is not the same gate the exercises
use. An exercise may reach one sound past the child (that is what the
quest's stretch slot is for), because an exercise is one word and a
stumble costs nothing. A story is a page: one unreadable word in the
middle and the child stops being a reader and starts being tested. So a
story unlocks only when every grapheme in it is one the child has
*mastered*, not merely met.

Stories are PARAGRAPH exercises. They are ordinary exercises in every
other respect — the child can record themselves reading one and be scored
on it exactly as with any other content — so nothing new was needed in
the schema, and prompt.md's rule that paragraph exercises get real-time
feedback continues to hold.
"""

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.enums import ExerciseType
from app.models.exercise import Exercise
from app.models.phoneme import Phoneme
from app.services.mastery_service import mastered_phoneme_ids
from app.utils.graphemes import stored_is_decodable, taught_spellings


@dataclass(frozen=True)
class StoryView:
    exercise_id: int
    content: str
    title: str
    word_count: int
    is_unlocked: bool
    # The sound that is standing in the way, for locked stories. Shown to
    # the child as "master /sh/ to open this" — a locked door with a
    # visible key is an invitation; one without is a wall.
    blocking_phoneme: str | None


def story_title(content: str) -> str:
    """First few words of the story, used as its name on the shelf.

    Generated content carries no title field and adding one would mean a
    schema change plus a regeneration of everything already stored. The
    opening words are what a child would call it anyway.
    """
    words = content.split()
    if not words:
        return "A story"
    head = " ".join(words[:4]).strip(".,!?;:")
    return head[:1].upper() + head[1:]


async def list_stories(db: AsyncSession, child_id: int) -> list[StoryView]:
    """Every story in the library, marked locked or open for this child."""
    stories = (
        await db.execute(
            select(Exercise)
            .options(selectinload(Exercise.phonemes))
            .where(Exercise.type == ExerciseType.PARAGRAPH)
            .order_by(Exercise.difficulty, Exercise.id)
        )
    ).scalars().all()
    if not stories:
        return []

    phonemes = (
        await db.execute(select(Phoneme).order_by(Phoneme.order))
    ).scalars().all()
    mastered_ids = await mastered_phoneme_ids(db, child_id)
    mastered = [p for p in phonemes if p.id in mastered_ids]
    allowed = taught_spellings(mastered)

    views: list[StoryView] = []
    for story in stories:
        unlocked = stored_is_decodable(story.graphemes, allowed)
        views.append(
            StoryView(
                exercise_id=story.id,
                content=story.content,
                title=story_title(story.content),
                word_count=len(story.content.split()),
                is_unlocked=unlocked,
                blocking_phoneme=(
                    None if unlocked else _next_missing_sound(story, phonemes, mastered)
                ),
            )
        )
    return views


def _next_missing_sound(
    story: Exercise, all_phonemes: list[Phoneme], mastered: list[Phoneme]
) -> str | None:
    """The earliest unmastered sound this story genuinely needs.

    A sound is needed if the story cannot be decoded without it — tested
    by handing the checker every phoneme in the curriculum *except* that
    one and seeing whether the text still comes apart.

    Returned in curriculum order, so the child is pointed at the next
    sound they were going to learn anyway rather than at whichever
    required sound happens to sit furthest along.
    """
    mastered_ids = {p.id for p in mastered}
    for phoneme in all_phonemes:
        if phoneme.id in mastered_ids:
            continue
        without = taught_spellings(
            [p for p in all_phonemes if p.id != phoneme.id]
        )
        if not stored_is_decodable(story.graphemes, without):
            return phoneme.symbol
    # No single sound is indispensable — the story is blocked by a
    # combination, or by a spelling the curriculum never teaches. Naming
    # one would be a promise the app cannot keep, so name none.
    return None
