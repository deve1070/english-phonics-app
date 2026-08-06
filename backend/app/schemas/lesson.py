from datetime import datetime
from typing import List, Optional

from app.models.enums import ExerciseType, Level
from pydantic import BaseModel


# -------------------------------------------------------------------
# Phoneme summary — nested inside lesson detail response.
# Includes `order` so Flutter can sort phonemes correctly.
# -------------------------------------------------------------------
class PhonemeSummary(BaseModel):
    id: int
    symbol: str
    description: Optional[str] = None
    audio_url: Optional[str] = None
    order: int = 0
    type: Optional[str] = None

    # The spellings this sound is written with, comma separated: "a",
    # "sh", "ee,ea". This is what a child is shown.
    #
    # `symbol` is not, and cannot be. It holds a mix of letter names
    # ("Aa"), IPA ("ɪ", "dʒ", "kʰ", "ʌ/ə") and IPA-plus-spelling
    # ("ʃ (sh)"), so a client rendering it puts "D3" and "Kw" in front of
    # a child learning J and Q — and, for Y, whose symbol is stored as
    # "Jj", a confident and entirely wrong letter. Eight of the first
    # twenty-six sounds are affected.
    graphemes: Optional[str] = None

    model_config = {"from_attributes": True}


# -------------------------------------------------------------------
# Exercise summary — nested inside lesson exercises response.
# NOTE: no audio_url — Exercise model has no audio (TTS on demand).
# -------------------------------------------------------------------
class ExerciseSummary(BaseModel):
    id: int
    content: str
    type: ExerciseType
    difficulty: int = 1

    model_config = {"from_attributes": True}


# -------------------------------------------------------------------
# Lesson schemas
# -------------------------------------------------------------------
class LessonBase(BaseModel):
    order: int
    level: Level


class LessonCreate(LessonBase):
    pass


class LessonUpdate(BaseModel):
    order: Optional[int] = None
    level: Optional[Level] = None


# Flat response — used by list endpoint (no nested children, fast)
class LessonResponse(LessonBase):
    id: int
    created_at: Optional[datetime] = None
    total_exercises: int = 0
    completed_exercises: int = 0

    model_config = {"from_attributes": True}


# Detail response — used by GET /lessons/{id}
# Includes phonemes (sorted by order) and the inherited total_exercises count.
class LessonDetailResponse(LessonResponse):
    phonemes: List[PhonemeSummary] = []


# Exercises response — used by GET /lessons/{id}/exercises
class LessonExercisesResponse(BaseModel):
    lesson_id: int
    level: Level
    exercises: List[ExerciseSummary] = []

    model_config = {"from_attributes": True}
