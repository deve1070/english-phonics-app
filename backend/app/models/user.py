from app.models.teacher_student import teacher_student_association
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

        base = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
        return f"{base}-{id}"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    user_name = Column(String, unique=True, index=True, nullable=False)
    role: UserRole = Column(SQLEnum(UserRole), default=UserRole.STUDENT)
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

    taught_students = relationship(
        "User",
        secondary=teacher_student_association,
        primaryjoin=(teacher_student_association.c.teacher_id == id),
        secondaryjoin=(teacher_student_association.c.student_id == id),
        back_populates="teachers",
    )

    teachers = relationship(
        "User",
        secondary=teacher_student_association,
        primaryjoin=(teacher_student_association.c.student_id == id),
        secondaryjoin=(teacher_student_association.c.teacher_id == id),
        back_populates="taught_students",
    )
