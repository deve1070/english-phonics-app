from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from ..db.base_class import Base


class PronunciationScore(Base):
    __tablename__ = "pronunciation_scores"

    id = Column(Integer, primary_key=True, index=True)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Float, nullable=False)  # 0-100
    audio_url = Column(String)  # User recording
    timestamp = Column(DateTime, default=func.utcnow)

    # Relationships
    exercise = relationship("Exercise", back_populates="scores")
    user = relationship("User", back_populates="scores")
