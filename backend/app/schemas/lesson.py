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

    model_config = {"from_attributes": True}


# Detail response — used by GET /lessons/{id}
# Includes phonemes (sorted by order) and a derived exercise count.
class LessonDetailResponse(LessonResponse):
    phonemes: List[PhonemeSummary] = []
    exercise_count: int = 0


# Exercises response — used by GET /lessons/{id}/exercises
class LessonExercisesResponse(BaseModel):
    lesson_id: int
    level: Level
    exercises: List[ExerciseSummary] = []

    model_config = {"from_attributes": True}
