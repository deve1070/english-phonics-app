from app.core.security import create_access_token, verify_password
from app.crud.users import crud as crud_user
from app.crud.users import get_user_by_email
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.subscription import Subscription
from app.schemas.auth import UserLogin
from app.schemas.user import UserCreate, UserResponse
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/auth", tags=["auth"])


class RefreshRequest(BaseModel):
    refresh_token: str


@router.post("/login", response_model=dict)
async def login(
    form_data: UserLogin,  # ← THIS WAS THE PROBLEM
    db: AsyncSession = Depends(get_db),
):
    user = await get_user_by_email(db, form_data.email)

    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": user.email})

    # Temporary: return refresh token same as access to support mobile flow
    return {
        "access_token": access_token,
        "refresh_token": access_token,
        "token_type": "bearer",
    }


@router.post("/refresh", response_model=dict)
async def refresh_token(payload: RefreshRequest):
    if not payload.refresh_token:
        raise HTTPException(status_code=401, detail="Missing refresh token")

    # Temporary lightweight refresh: issue a new access token from old token subject
    from app.core.config import settings
    from jose import JWTError, jwt

    try:
        decoded = jwt.decode(
            payload.refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        email = decoded.get("sub")
        if not email:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid refresh token") from exc

    access_token = create_access_token(data={"sub": email})
    return {
        "access_token": access_token,
        "refresh_token": payload.refresh_token,
        "token_type": "bearer",
    }


@router.post(
    "/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED
)
async def register(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    # Check if email already exists.
    existing_user = await crud_user.get_by_email(db=db, email=user_in.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered"
        )

    # Force role to STUDENT
    user_in.role = UserRole.STUDENT.value

    # Create user via CRUD (hashing + username generation)
    user = await crud_user.create_user(db=db, obj_in=user_in)

    # Auto-create a TRIAL subscription for the new user.
    trial_subscription = Subscription(
        user_id=user.id,
        status="TRIAL",
    )
    db.add(trial_subscription)
    await db.commit()
    await db.refresh(user)
    return user
