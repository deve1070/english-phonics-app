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
    type = Column(SQLEnum(PhonemeType), default=PhonemeType.ALPHABET)
    created_at = Column(DateTime, default=func.now())

    lesson = relationship("Lesson", back_populates="phonemes")
    exercises = relationship(
        "Exercise",
        secondary=exercise_phoneme,
        back_populates="phonemes",
    )
