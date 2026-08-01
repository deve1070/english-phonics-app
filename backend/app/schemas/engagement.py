"""Response shapes for the child-facing engagement endpoints."""

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel

from app.models.enums import ExerciseType, QuestSlot, RecognitionMode


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
    # The recognition track's own reward. The creature opens its eyes when
    # the child can pick this sound out of four, and only turns full colour
    # when they can say it — two visible stages for two separate skills,
    # neither standing in for the other.
    is_recognised: bool = False


class CollectionResponse(BaseModel):
    total: int
    unlocked: int
    items: List[CollectibleResponse]
    # Ids the child has earned but never been shown. The app celebrates
    # these once and then POSTs /collection/seen.
    newly_unlocked: List[int]


class RecognitionOption(BaseModel):
    phoneme_id: int
    symbol: str
    # What the child actually looks at. The symbol may be IPA; the
    # grapheme is the spelling, and the spelling is what has to be learnt.
    grapheme: str
    audio_url: str


class RecognitionQuestionResponse(BaseModel):
    target_phoneme_id: int
    target_audio_url: str
    options: List[RecognitionOption]


class RecognitionRoundResponse(BaseModel):
    mode: RecognitionMode
    questions: List[RecognitionQuestionResponse]


class RecognitionAnswerRequest(BaseModel):
    phoneme_id: int
    # Null when the child left without answering. Recorded, never counted
    # as wrong.
    chosen_phoneme_id: Optional[int] = None
    option_count: int = 2


class RecognitionRoundResult(BaseModel):
    mode: RecognitionMode
    answers: List[RecognitionAnswerRequest]


class RecognitionSummary(BaseModel):
    recorded: int
    # Sounds that crossed into "recognised" because of this round, so the
    # app can show the creature opening its eyes at the moment it happens.
    newly_recognised: List[int]
    total_recognised: int


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
