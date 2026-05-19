from datetime import UTC, datetime, timedelta
from typing import Optional

from app.core.config import settings
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from argon2 import PasswordHasher
from argon2.exceptions import HashingError, VerifyMismatchError
from fastapi import Depends, HTTPException, status
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
    OAuth2PasswordBearer,
)
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

oauth_scheme = OAuth2PasswordBearer(tokenUrl="token")
bearer_scheme = HTTPBearer()





def create_access_token(
    subject: str | None = None,
    data: dict | None = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Create a JWT access token.

    The 'sub' field is always the user's integer ID as a string.
    """
    if subject is not None:
        to_encode = {"sub": str(subject)}
    else:
        raise ValueError("subject must be provided")

    expire = datetime.now(UTC) + (
        expires_delta
        or timedelta(minutes=getattr(settings, "ACCESS_TOKEN_EXPIRE_MINUTES", 10080))
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> User:
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        sub: str = payload.get("sub")
        if sub is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # Look up by user ID
    result = await db.execute(select(User).where(User.id == int(sub)))
    user = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception
    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user


async def get_current_admin(
    current_user: User = Depends(get_current_active_user),
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Admin privileges required")
    return current_user


async def get_current_teacher_or_admin(
    current_user: User = Depends(get_current_active_user),
):
    if current_user.role not in [UserRole.ADMIN]:
        raise HTTPException(status_code=403, detail="Admin privileges required")
    return current_user


async def get_current_student(
    current_user: User = Depends(get_current_active_user),
):
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="Student access only")
    return current_user


