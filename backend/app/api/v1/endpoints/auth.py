import hashlib
import secrets
from typing import Optional

from app.core.config import settings
from app.core.security import create_access_token
from app.crud.users import crud as crud_user
from app.crud.users import get_user_by_phone
from app.db.session import get_db
from app.models.auth_models import BiometricToken
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.auth import PasskeyLogin, PhoneLogin, Token
from app.schemas.user import UserRegister
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/auth", tags=["auth"])


def _hash_bio(raw: str) -> str:
    return hashlib.sha256(f"{raw}{settings.SECRET_KEY}".encode()).hexdigest()


async def _deactivate_biometric_tokens(db: AsyncSession, user_id: int) -> None:
    await db.execute(
        update(BiometricToken)
        .where(BiometricToken.user_id == user_id)
        .values(is_active=False)
    )


async def _issue_biometric(
    db: AsyncSession, user_id: int, device_id: Optional[str] = None
) -> str:
    await _deactivate_biometric_tokens(db, user_id)
    raw = secrets.token_urlsafe(32)
    db.add(
        BiometricToken(
            user_id=user_id,
            token_hash=_hash_bio(raw),
            device_id=(device_id or "")[:200],
            is_active=True,
        )
    )
    await db.flush()
    return raw


@router.post(
    "/register", response_model=Token, status_code=status.HTTP_201_CREATED
)
async def register(user_in: UserRegister, db: AsyncSession = Depends(get_db)):
    existing_user = await crud_user.get_by_phone(db=db, phone=user_in.phone_number)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Phone number already registered"
        )

    user = await crud_user.create_user(db=db, obj_in=user_in)

    bio_raw = await _issue_biometric(db, user.id)
    await db.commit()
    await db.refresh(user)

    access_token = create_access_token(subject=str(user.id))

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "biometric_token": bio_raw
    }


@router.post("/login", response_model=Token)
async def login(
    form_data: PhoneLogin,
    db: AsyncSession = Depends(get_db),
):
    user = await get_user_by_phone(db, form_data.phone_number)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect phone number",
            headers={"WWW-Authenticate": "Bearer"},
        )

    bio_raw = await _issue_biometric(db, user.id)
    await db.commit()

    access_token = create_access_token(subject=str(user.id))

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "biometric_token": bio_raw
    }


@router.post("/passkey-login", response_model=Token)
async def passkey_login(body: PasskeyLogin, db: AsyncSession = Depends(get_db)):
    h = _hash_bio(body.biometric_token.strip())
    r = await db.execute(
        select(BiometricToken).where(
            BiometricToken.token_hash == h,
            BiometricToken.is_active.is_(True),
        )
    )
    row = r.scalar_one_or_none()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired passkey sign-in.",
        )

    ur = await db.execute(select(User).where(User.id == row.user_id))
    user = ur.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account not available.",
        )

    new_raw = await _issue_biometric(db, user.id, row.device_id)
    await db.commit()

    access_token = create_access_token(subject=str(user.id))

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "biometric_token": new_raw,
    }
