from sqlalchemy import Column, ForeignKey, Integer, String, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base_class import Base
from .exercise_phoneme import (
    exercise_phoneme,
)
from .word_phoneme import word_phoneme


class Phoneme(Base):
    __tablename__ = "phonemes"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String, unique=True, index=True, nullable=False)
    description = Column(Text)
    audio_url = Column(String)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False)
    type = Column(
        SQLEnum("consonant", "vowel", name="phoneme_type"), default="consonant"
    )

    exercises = relationship(
        "Exercise",
        secondary=exercise_phoneme,
        back_populates="phonemes",
        cascade="all, delete",
    )
    lessons = relationship("Lesson", back_populates="phonemes", cascade="all, delete")

    words = relationship("Word", secondary=word_phoneme, back_populates="phonemes")
