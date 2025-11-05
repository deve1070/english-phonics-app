from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from app.database import Base


class Gamification(Base):
    __tablename__ = "gamification"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    xp = Column(Integer, default=0)
    streak = Column(Integer, default=0)
    badges = Column(String, default="")
    last_active = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="gamification")
