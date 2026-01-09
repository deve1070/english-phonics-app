from sqlalchemy import Column, ForeignKey, Integer, String, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base_class import Base
from .enums import ExerciseType
from .exercise_phoneme import exercise_phoneme


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False)
    content = Column(Text, nullable=False)  # e.g., word list or sentence
    type = Column(SQLEnum(ExerciseType), default=ExerciseType.WORD)
    audio_url = Column(String)
    word_id = Column(
        Integer, ForeignKey("words.id"), nullable=True
    )  # Optional FK for word-specific exercises
    difficulty = Column(Integer, default=1)

    # Relationships (symmetric back_populates)
    lesson = relationship("Lesson", back_populates="exercises")
    scores = relationship("PronunciationScore", back_populates="exercise")
    phonemes = relationship(
        "Phoneme", secondary=exercise_phoneme, back_populates="exercises"
    )
    word = relationship(
        "Word", back_populates="exercises", foreign_keys=[word_id]
    )  # Fixed: foreign_keys for clarity
    # Progress entries for this exercise
    progress = relationship("Progress", back_populates="exercise")
