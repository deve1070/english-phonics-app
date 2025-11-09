from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ....crud import crud
from ....db.session import get_db
from ....schemas.user import User, UserCreate, UserUpdate

router = APIRouter()


@router.post("/", response_model=User)
def create_user(*, db: Session = Depends(get_db), user_in: UserCreate) -> User:
    user = crud.get_by_email(db, email=user_in.email)
    if user:
        raise HTTPException(status_code=400, detail="Email already registered")
    user = crud.create(db, obj_in=user_in)
    return user


@router.get("/{user_id}", response_model=User)
def read_user(*, db: Session = Depends(get_db), user_id: int) -> User:
    user = crud.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.put("/{user_id}", response_model=User)
def update_user(
    *, db: Session = Depends(get_db), user_id: int, user_in: UserUpdate
) -> User:
    user = crud.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user = crud.update(db, db_obj=user, obj_in=user_in)
    return user


@router.get("/", response_model=List[User])
def read_users(
    *, db: Session = Depends(get_db), skip: int = 0, limit: int = 100
) -> List[User]:
    users = crud.get_multi(db, skip=skip, limit=limit)
    return users


@router.delete("/{user_id}", response_model=User)
def delete_user(*, db: Session = Depends(get_db), user_id: int) -> Optional[User]:
    user = crud.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user = crud.remove(db, id=user_id)
    return None
