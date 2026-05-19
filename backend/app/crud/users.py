import uuid
from typing import List, Optional


from app.models.enums import UserRole
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..models.user import User
from ..schemas.user import UserRegister, UserResponse, UserUpdate
from .base import CRUDBase


def _normalize_role(role: Optional[str]) -> Optional[UserRole]:
    """Convert API role string (STUDENT/ADMIN) to UserRole enum for DB (student/admin)."""
    if role is None:
        return None
    r = (role or "").strip().upper()
    if r == "STUDENT":
        return UserRole.STUDENT
    if r == "ADMIN":
        return UserRole.ADMIN
    if r == "PARENT":
        return UserRole.PARENT
    return None


class CRUDUser(CRUDBase[User, UserRegister, UserUpdate]):
    async def get_by_phone(self, db: AsyncSession, *, phone: Optional[str]) -> Optional[User]:
        if phone is None:
            return None
        result = await db.execute(select(User).filter(User.phone_number == phone))
        return result.scalar_one_or_none()

    async def get_user(self, db: AsyncSession, *, id: int) -> Optional[UserResponse]:
        result = await db.execute(
            select(self.model)
            .options(
                selectinload(self.model.scores),
                selectinload(self.model.achievements),
                selectinload(self.model.progress),
            )
            .filter(self.model.id == id)
        )
        return result.scalar_one_or_none()

    async def create_user(
        self, db: AsyncSession, *, obj_in: UserRegister
    ) -> UserResponse:

        existing = await self.get_by_phone(db, phone=obj_in.phone_number)

        if existing:
            if existing.is_active:
                raise HTTPException(status_code=400, detail="Phone number already registered")

            existing.name = obj_in.name or existing.name
            existing.role = _normalize_role(obj_in.role) or existing.role
            existing.is_active = True

            if not existing.user_name:
                existing.user_name = User.create_user_name(existing.name, existing.id)

            db.add(existing)
            await db.commit()
            await db.refresh(existing)
            return existing

        create_data = obj_in.model_dump()
        create_data["role"] = (
            _normalize_role(create_data.get("role")) or UserRole.STUDENT
        )

        db_obj = User(**create_data)
        db_obj.user_name = f"temp-{uuid.uuid4().hex}"

        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)

        db_obj.user_name = User.create_user_name(db_obj.name, db_obj.id)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)

        return db_obj

    async def update(
        self, db: AsyncSession, *, db_obj: User, obj_in: UserUpdate
    ) -> User:
        if obj_in.phone_number:
            existing = await self.get_by_phone(db, phone=obj_in.phone_number)
            if existing and existing.id != db_obj.id:
                raise ValueError("Phone number already registered")
        return await super().update(db, db_obj=db_obj, obj_in=obj_in)

    async def get_multi(
        self, db: AsyncSession, *, skip=0, limit=100
    ) -> List[UserResponse]:
        result = await db.execute(
            select(self.model)
            .options(
                selectinload(self.model.progress),
                selectinload(self.model.scores),
                selectinload(self.model.achievements),
            )
            .where(self.model.is_active == True)
            .offset(skip)
            .limit(limit)
        )
        users = result.scalars().all()
        for u in users:
            for rel in ("progress", "scores", "achievements"):
                try:
                    if getattr(u, rel) is None:
                        setattr(u, rel, [])
                except Exception:
                    setattr(u, rel, [])
        return users

    async def remove(self, db: AsyncSession, *, id: int) -> Optional[User]:
        return await super().remove(db, id=id)


crud = CRUDUser(User)


async def get_user_by_phone(db: AsyncSession, phone: str) -> Optional[User]:
    return await crud.get_by_phone(db, phone=phone)
