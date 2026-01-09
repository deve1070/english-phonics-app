from sqlalchemy import Boolean, Column, DateTime, Integer, String, func
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import relationship

from ..db.base_class import Base
from .enums import UserRole


class User(Base, AsyncAttrs):
    __tablename__ = "users"

    @staticmethod
    def create_user_name(name: str, id: int) -> str:
        import re

        # sanitize: keep lowercase alphanumerics, replace spaces with hyphen
        base = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
        return f"{base}-{id}"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    user_name = Column(String, unique=True, index=True, nullable=False)
    role = Column(SQLEnum(UserRole), default=UserRole.STUDENT)
    is_active = Column(Boolean, default=True)
    age_group = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    progress = relationship(
        "Progress",
        back_populates="user",
        lazy="noload",
        collection_class=list,
    )

    scores = relationship(
        "PronunciationScore",
        back_populates="user",
        lazy="noload",
        collection_class=list,
    )
    achievements = relationship(
        "UserAchievement",
        back_populates="user",
        lazy="noload",
        collection_class=list,
    )
