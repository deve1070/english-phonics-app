from sqlalchemy import Column, DateTime, Integer, String, func, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.ext.asyncio import AsyncAttrs
from ..db.base_class import Base
from .enums import UserRole


class User(Base, AsyncAttrs):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    role = Column(SQLEnum(UserRole), default=UserRole.STUDENT)
    age_group = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    progress = relationship("Progress", back_populates="user")
    scores = relationship("PronuncationScore", back_populates="user")
    achievements = relationship("UserAchievement", back_populates="user")
