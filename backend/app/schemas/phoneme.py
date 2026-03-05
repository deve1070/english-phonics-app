from typing import Optional

from app.models.enums import PhonemeType
from pydantic import BaseModel


class PhonemeBase(BaseModel):
    symbol: str
    description: Optional[str] = None
    type: PhonemeType
    lesson_id: int


class PhonemeCreate(PhonemeBase):
    audio_url: Optional[str] = None


class PhonemeUpdate(BaseModel):
    symbol: Optional[str] = None
    description: Optional[str] = None
    audio_url: Optional[str] = None
    type: Optional[PhonemeType] = None
    lesson_id: Optional[int] = None


class Phoneme(PhonemeBase):
    id: int
    audio_url: Optional[str] = None

    class Config:
        from_attributes = True
