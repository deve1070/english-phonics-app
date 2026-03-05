from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, func
from sqlalchemy.orm import relationship

from ..db.base import Base


class Progress(Base):
    __tablename__ = "progress"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False, index=True)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), index=True)
    completed = Column(Boolean, default=False)
    score = Column(Float, default=0.0)
    attempts = Column(Integer, default=0)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="progress")
    lesson = relationship("Lesson", back_populates="progress")
    exercise = relationship("Exercise", back_populates="progress")
