from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class PronunciationScoreBase(BaseModel):
    score: int
    audio_url: Optional[str] = None


class PronunciationScoreCreate(PronunciationScoreBase):
    exercise_id: int
    user_id: int


class PronunciationScoreUpdate(PronunciationScoreBase):
    pass


class PronunciationScore(PronunciationScoreBase):
    id: int
    exercise_id: int
    user_id: int
    timestamp: datetime

    class Config:
        from_attributes = True
