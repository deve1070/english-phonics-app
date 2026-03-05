from app.core.security import create_access_token, verify_password
from app.crud.users import crud as crud_user
from app.crud.users import get_user_by_email
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.subscription import Subscription
from app.models.user import UserCreate, UserResponse, UserUpdate
from app.schemas.auth import UserLogin
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=dict)
async def login(form_data: UserLogin = Depends(), db: AsyncSession = Depends(get_db)):
    user = await get_user_by_email(db, form_data.email)
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}


@router.post(
    "/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED
)
async def register(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    """
    Public registration endpoint.
    -Create a STUDENT user.
    -Autho-create a TRIAL subscription
    -No auth required.
    """
    # Check if email already exists.
    existing_user = await crud_user.get_by_email(db=db, email=user_in.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUESt, detail="Email already registered"
        )

    # Force role to STUDENT
    user_in.role = UserRole.STUDENT

    # Create the user(your CRUD handles hashing,username,generation,etc.)
    user = await crud_user.create(db=db, ojb_in=user_in)

    # Auto-create a TRIAL subscription for the new user.
    trail_subscription = Subscription(
        user_id=user.id,
        status="TRIAL",
    )
    db.add(trail_subscription)
    await db.commit()
    await db.refresh(user)
    return user
