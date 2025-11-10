from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, func
from sqlalchemy.orm import relationship

from ..db.base_class import Base


class Progress(Base):
    __tablename__ = "progress"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False)
    exercise_id = Column(Integer, ForeignKey("exercises.id"))
    completed = Column(Boolean, default=False)
    score = Column(Float, default=0.0)
    attempts = Column(Integer, default=0)
    updated_at = Column(DateTime, default=func.utcnow(), onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="progress")
    lesson = relationship("Lesson", back_populates="progress")
    exercise = relationship("Exercise", back_populates="progress")
