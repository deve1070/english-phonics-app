from sqlalchemy import Column, ForeignKey, Integer, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base import Base
from .enums import ExerciseType
from .exercise_phoneme import exercise_phoneme


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False, index=True)
    content = Column(Text, nullable=False)
    type = Column(SQLEnum(ExerciseType), default=ExerciseType.WORD)
    difficulty = Column(Integer, default=1)

    lesson = relationship("Lesson", back_populates="exercises")
    scores = relationship("PronunciationScore", back_populates="exercise")
    phonemes = relationship(
        "Phoneme", secondary=exercise_phoneme, back_populates="exercises"
    )
    progress = relationship("Progress", back_populates="exercise")
