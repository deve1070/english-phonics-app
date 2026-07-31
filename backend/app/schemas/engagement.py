"""Response shapes for the child-facing engagement endpoints."""

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel

from app.models.enums import ExerciseType, QuestSlot


class QuestItemResponse(BaseModel):
    slot: QuestSlot
    exercise_id: int
    content: str
    type: ExerciseType
    completed: bool


class QuestResponse(BaseModel):
    quest_date: date
    items: List[QuestItemResponse]
    completed_count: int
    total_count: int
    is_complete: bool


class StreakResponse(BaseModel):
    days: int
    freezes_available: int
    # Dates a freeze is covering. The app says "we saved your streak" on
    # these rather than pretending the child practised.
    frozen_dates: List[date]


class CollectibleResponse(BaseModel):
    phoneme_id: int
    symbol: str
    order: int
    # The client draws each sticker procedurally from these two fields, so
    # ninety collectibles need no artwork and no asset download.
    phoneme_type: str
    is_unlocked: bool
    unlocked_at: Optional[datetime] = None
    is_new: bool = False


class CollectionResponse(BaseModel):
    total: int
    unlocked: int
    items: List[CollectibleResponse]
    # Ids the child has earned but never been shown. The app celebrates
    # these once and then POSTs /collection/seen.
    newly_unlocked: List[int]


class StoryResponse(BaseModel):
    exercise_id: int
    title: str
    word_count: int
    is_unlocked: bool
    blocking_phoneme: Optional[str] = None
    # Only sent for stories the child can actually read. Withholding the
    # text of a locked story is deliberate: it keeps a child from
    # struggling through something the app has already judged too hard.
    content: Optional[str] = None


class StoryListResponse(BaseModel):
    total: int
    unlocked: int
    stories: List[StoryResponse]
