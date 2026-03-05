from pydantic import BaseModel
from datetime import datetime


class PronunciationScoreBase(BaseModel):
    score: int
    audio_url: str


class PronunciationScoreCreate(PronunciationScoreBase):
    exercise_id: int
    user_id: int


class PronunciationScore(PronunciationScoreBase):
    id: int
    exercise_id: int
    user_id: int
    timestamp: datetime

    class Config:
        from_attributes = True
