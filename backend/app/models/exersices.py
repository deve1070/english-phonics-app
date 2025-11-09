from sqlalchemy import Column, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship
from sqlalchemy.types import Enum as SQLEnum

from ..db.base_class import Base
from .enums import ExerciseType


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    lesson_id = Column(Integer, ForeignKey("lessons.id"))
    content = Column(Text, nullable=False)  # word, sentence, or phonetic symbol
    type = Column(
        SQLEnum(ExerciseType), default=ExerciseType.WORD, nullable=False
    )  # Fixed: Use SQLEnum(YourEnum)
    audio_url = Column(String, nullable=True)

    pronunciation_scores = relationship("PronunciationScore", back_populates="exercise")
