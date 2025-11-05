from app.database import Base
from sqlalchemy import Column, DateTime, Integer, String, func
from sqlachemy.orm import relationship


class Challenge(Base):
    __tablename__ = "challenges"
    id = Column(Integer, primary_key=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    type = Column(String, default="daily")
    start_date = Column(DateTime, server_default=func.now())
    end_date = Column(DateTime)
    friend = relationship("Friend", back_populates="progress")
    user = relationship("User", back_populates="progress")
