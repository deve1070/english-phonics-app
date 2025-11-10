from sqlalchemy import Column, ForeignKey, Integer, String, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base_class import Base
from .enums import ExerciseType  # Enum: 'word', 'sentence', 'phoneme', 'blending'


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False)
    content = Column(Text, nullable=False)  # e.g., word list or sentence
    type = Column(SQLEnum(ExerciseType), default=ExerciseType.WORD)
    audio_url = Column(String)
    difficulty = Column(Integer, default=1)

    # Relationships
    lesson = relationship("Lesson", back_populates="exercises")
    scores = relationship("PronunciationScore", back_populates="exercise")
    phonemes = relationship(
        "Phoneme", secondary="exercise_phonemes", back_populates="exercises"
    )
    word = relationship("Word", back_populates="exercises")  # If type='word'
