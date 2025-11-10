from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from ....crud import crud
from ....db.session import get_db
from ....schemas.user import User, UserCreate, UserUpdate

router = APIRouter()


@router.post("/", response_model=User)
async def create_user(
    *, db: AsyncSession = Depends(get_db), user_in: UserCreate
) -> User:
    user = await crud.get_by_email(db, email=user_in.email)
    if user:
        raise HTTPException(status_code=400, detail="Email already registered")
    user = await crud.create(db, obj_in=user_in)
    return user


@router.get("/{user_id}", response_model=User)
async def read_user(*, db: AsyncSession = Depends(get_db), user_id: int) -> User:
    user = await crud.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.put("/{user_id}", response_model=User)
async def update_user(
    *, db: AsyncSession = Depends(get_db), user_id: int, user_in: UserUpdate
) -> User:
    user = await crud.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user = crud.update(db, db_obj=user, obj_in=user_in)
    return user


@router.get("/", response_model=List[User])
async def read_users(
    *, db: AsyncSession = Depends(get_db), skip: int = 0, limit: int = 100
) -> List[User]:
    users = await crud.get_multi(db, skip=skip, limit=limit)
    return users


@router.delete("/{user_id}", response_model=User)
async def delete_user(
    *, db: AsyncSession = Depends(get_db), user_id: int
) -> Optional[User]:
    user = await crud.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user = crud.remove(db, id=user_id)
    return None
