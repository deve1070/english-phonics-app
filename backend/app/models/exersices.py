from enum import Enum

from app.database import Base
from sqlalchemy import Column, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship


class ExerciseType(str, Enum):
    WORD = "word"
    SENTENCE = "sentence"
    PHONEME = "phoneme"


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    lesson_id = Column(Integer, ForeignKey("lessons.id"))
    content = Column(Text, nullable=False)  # word, sentence, or phonetic symbol
    type = Column(
        Enum(ExerciseType), default=ExerciseType.WORD
    )  # word / sentence / phoneme
    audio_url = Column(String, nullable=True)

    lesson = relationship("Lesson", back_populates="exercises")
    pronunciation_scores = relationship("PronunciationScore", back_populates="exercise")
