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
    phone_number = Column(String(20), nullable=True, unique=True, index=True)
    user_name = Column(String, unique=True, index=True, nullable=False)
    role = Column(
        SQLEnum(UserRole, values_callable=lambda x: [e.value for e in x]),
        default=UserRole.STUDENT,
    )
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    progress = relationship("Progress", back_populates="user", lazy="noload")
    scores = relationship("PronunciationScore", back_populates="user", lazy="noload")

