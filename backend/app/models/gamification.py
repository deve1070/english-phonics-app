from sqlalchemy import Column, DateTime, Integer, String, Text, func
from sqlalchemy.orm import relationship

from ..db.base import Base


class Gamification(Base):
    __tablename__ = "gamification"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(Text)
    points_required = Column(Integer, default=100)
    image_url = Column(String)
    created_at = Column(DateTime, default=func.now())

    user_achievements = relationship("UserAchievement", back_populates="gamification")
