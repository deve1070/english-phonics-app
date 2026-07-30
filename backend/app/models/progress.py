from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, UniqueConstraint, func
from sqlalchemy.orm import relationship

from ..db.base import Base


class Progress(Base):
    __tablename__ = "progress"
    __table_args__ = (
        # Prevents the race where two concurrent submissions for the same
        # (user, exercise) each see "no existing row" and both insert —
        # the upsert in crud_progress.py relies on this constraint to do
        # a single atomic INSERT ... ON CONFLICT DO UPDATE instead.
        UniqueConstraint("user_id", "exercise_id", name="uq_progress_user_exercise"),
    )

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
