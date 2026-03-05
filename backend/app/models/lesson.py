from sqlalchemy import Column, DateTime, Integer, func
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base import Base
from .enums import Level


class Lesson(Base):
    __tablename__ = "lessons"

    id = Column(Integer, primary_key=True, index=True)
    order = Column(Integer, nullable=False, default=0)
    level = Column(SQLEnum(Level), nullable=False, default=Level.LEVEL1)
    created_at = Column(DateTime, default=func.now())

    exercises = relationship(
        "Exercise", back_populates="lesson", cascade="all, delete-orphan"
    )
    phonemes = relationship("Phoneme", back_populates="lesson")
    progress = relationship("Progress", back_populates="lesson")
