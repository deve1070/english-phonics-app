from sqlalchemy import Column, DateTime, Integer, Enum as SQLEnum
from sqlalchemy import func
from sqlalchemy.orm import relationship

from ..db.base_class import Base
from .enums import Level


class Lesson(Base):
    __tablename__ = "lessons"

    id = Column(Integer, primary_key=True, index=True)
    order = Column(Integer, nullable=False, default=0)
    level = Column(SQLEnum(Level), nullable=False, default=Level.LEVEL1)
    # Use DB NOW() for created timestamp
    created_at = Column(DateTime, default=func.now())

    # Fixed: Standard property name "exercises" (no underscore), matching back_populates in Exercise
    exercises = relationship(
        "Exercise", back_populates="lesson", cascade="all, delete-orphan"
    )
    # Fixed: Standard property name "phonemes" (no underscore), assuming back_populates in Phoneme is "lessons"
    phonemes = relationship("Phoneme", back_populates="lessons")
    progress = relationship("Progress", back_populates="lesson")
