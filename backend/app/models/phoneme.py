from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base import Base
from .enums import PhonemeType
from .exercise_phoneme import exercise_phoneme


class Phoneme(Base):
    __tablename__ = "phonemes"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String, unique=True, index=True, nullable=False)
    description = Column(Text)
    audio_url = Column(String)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False, index=True)
    order = Column(Integer, nullable=False, default=0)
    # Comma-separated spellings this sound may be written as, e.g. "c,k,ck"
    # for /k/. `symbol` is the sound; this is how it appears on the page.
    # Decodability checks need the spellings, and cannot reliably guess
    # them from an IPA symbol — see app/utils/graphemes.py.
    graphemes = Column(String, nullable=True)
    type = Column(SQLEnum(PhonemeType), default=PhonemeType.ALPHABET)
    created_at = Column(DateTime, default=func.now())

    lesson = relationship("Lesson", back_populates="phonemes")
    exercises = relationship(
        "Exercise",
        secondary=exercise_phoneme,
        back_populates="phonemes",
    )
