from sqlalchemy import Column, Integer, String, Text
from sqlalchemy.orm import relationship
from ..db.base_class import Base


class Gamification(Base):
    __tablename__ = "gamification"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)  # e.g., "Vowel Hero Badge"
    description = Column(Text)
    points_required = Column(Integer, default=100)
    image_url = Column(String)

    # Relationships (junction for many-to-many with User)
    user_achievements = relationship("UserAchievement", back_populates="gamification")
