from typing import List

from app.core.security import get_current_student
from app.crud.friend import friend_crud
from app.db.session import get_db
from app.models.enums import FriendRequestStatus
from app.models.user import User
from app.schemas.friend import FriendRequestResponse, FriendRequestUpdate
from app.schemas.user import UserResponse
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/friends", tags=["friends"])


@router.post(
    "/request",
    response_model=FriendRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def send_friend_request(
    receiver_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_student),
):
    return await friend_crud.send_friend_request(
        db, sender_id=current_user.id, receiver_id=receiver_id
    )


@router.put("/requests/{request_id}", response_model=List[FriendRequestResponse])
async def respond_to_friend_request(
    request_id: int,
    obj_in: FriendRequestUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_student),
):
    status = FriendRequestStatus(obj_in.status)
    success = await friend_crud.respond_to_friend_request(
        db, request_id=request_id, status=status
    )
    if not success:
        return []
    return await friend_crud.get_friends(db, user_id=current_user.id)
    # return await friend_crud.get_friend_requests(db, user_id=current_user.id)


@router.get("/requests/pending", response_model=List[FriendRequestResponse])
async def get_friend_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_student),
):
    return await friend_crud.get_friend_requests(db, user_id=current_user.id)


@router.get("/friends", response_model=List[UserResponse])
async def get_friends(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_student),
):
    return await friend_crud.get_friends(db, user_id=current_user.id)


@router.get("/recommend", response_model=List[UserResponse])
async def recommend_friends(
    db: AsyncSession = Depends(get_db),
    current_student: User = Depends(get_current_student),
):
    return await friend_crud.recommend_friends(current_student, db)
