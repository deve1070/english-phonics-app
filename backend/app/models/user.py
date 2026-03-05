from app.models.friend import friends_association
from sqlalchemy import Boolean, Column, DateTime, Integer, String, func
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import relationship, validates

from ..db.base import Base
from .enums import UserRole


class User(Base, AsyncAttrs):
    __tablename__ = "users"

    @staticmethod
    def create_user_name(name: str, id: int) -> str:
        import re

        base = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
        return f"{base}-{id}"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(
        String, index=True, nullable=False
    )  # Removed unique (names can repeat)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    user_name = Column(String, unique=True, index=True, nullable=False)
    role = Column(
        SQLEnum(UserRole, values_callable=lambda x: [e.value for e in x]),
        default=UserRole.STUDENT,
    )
    is_active = Column(Boolean, default=True)
    age_group = Column(Integer)
    grade_level = Column(Integer, nullable=True)
    school_name = Column(String, nullable=True)
    city = Column(String, nullable=True)
    country = Column(String, nullable=True)
    total_points = Column(Integer, default=0)  # Added for gamification
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    progress = relationship("Progress", back_populates="user", lazy="noload")
    scores = relationship("PronunciationScore", back_populates="user", lazy="noload")
    achievements = relationship("UserAchievement", back_populates="user", lazy="noload")
    friends = relationship(
        "User",
        secondary=friends_association,
        primaryjoin=(friends_association.c.user_id == id),
        secondaryjoin=(friends_association.c.friend_id == id),
        back_populates="friends",
    )
    subscription = relationship(
        "Subscription", back_populates="user", uselist=False
    )  # Added

    @validates("grade_level")
    def validate_grade_level(self, key, value):
        if value is not None and value > 12:
            raise ValueError("grade_level must be <= 12")
        return value
