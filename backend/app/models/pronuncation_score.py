from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from ..db.base import Base


class PronunciationScore(Base):
    __tablename__ = "pronunciation_scores"

    id = Column(Integer, primary_key=True, index=True)
    exercise_id = Column(
        Integer, ForeignKey("exercises.id"), nullable=False, index=True
    )
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    # Nullable: populated when the exercise targets a specific phoneme so that
    # per-phoneme analytics (parents.py _compute_progress_summary) can group scores.
    phoneme_id = Column(
        Integer, ForeignKey("phonemes.id"), nullable=True, index=True
    )
    score = Column(Float, nullable=False)  # 0-100
    audio_url = Column(String)
    timestamp = Column(DateTime, default=func.now())

    exercise = relationship("Exercise", back_populates="scores")
    user = relationship("User", back_populates="scores")
    phoneme = relationship("Phoneme", foreign_keys=[phoneme_id])

