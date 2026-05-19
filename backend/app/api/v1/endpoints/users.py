from typing import List, Optional

from app.core.security import (
    get_current_active_user,
    get_current_admin,
)
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ....crud import crud
from ....crud import user as user_crud
from ....db.session import get_db
from ....models.user import User as UserORM
from ....schemas.user import User, UserRegister, UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def read_current_user(
    *,
    current_user: UserORM = Depends(get_current_active_user),
) -> UserResponse:
    return current_user


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    *, db: AsyncSession = Depends(get_db), user_in: UserRegister
) -> UserResponse:
    try:
        user = await crud.user.create_user(db, obj_in=user_in)
    except HTTPException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"Error creating user: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error") from e
    return user


@router.get("/{user_id}", response_model=User)
async def read_user(*, db: AsyncSession = Depends(get_db), user_id: int) -> User:
    user = await crud.user.get_user(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.put("/me", response_model=UserResponse)
async def update_current_user(
    *,
    obj_in: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: UserORM = Depends(get_current_active_user),
):
    update_user = await crud.user.update(db=db, db_obj=current_user, obj_in=obj_in)
    return update_user


@router.put("/{id}", response_model=User)
async def update_user(
    *, id: int, user_in: UserUpdate, db: AsyncSession = Depends(get_db)
):
    db_user = await user_crud.get(db, id=id)
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    return await crud.user.update(db, db_obj=db_user, obj_in=user_in)


@router.get("/", response_model=List[User])
async def read_users(
    *,
    db: AsyncSession = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
    current_admin: UserORM = Depends(get_current_admin),
) -> List[User]:
    users = await user_crud.get_multi(db, skip=skip, limit=limit)
    return users


@router.delete("/{user_id}", response_model=Optional[User])
async def delete_user(
    *, db: AsyncSession = Depends(get_db), user_id: int
) -> Optional[User]:
    user = await crud.user.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    deleted = await crud.user.remove(db, id=user_id)
    return deleted
