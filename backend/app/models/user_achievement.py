from sqlalchemy import Column, Integer, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship
from ..db.base_class import Base


class UserAchievement(Base):
    __tablename__ = "user_achievements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    gamification_id = Column(Integer, ForeignKey("gamification.id"), nullable=False)
    achieved_at = Column(DateTime, default=func.now())

    user = relationship("User", back_populates="achievements")
    gamification = relationship("Gamification", back_populates="user_achievements")
