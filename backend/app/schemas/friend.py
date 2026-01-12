from datetime import datetime

from app.schemas.user import UserResponse
from pydantic import BaseModel, ConfigDict


class FriendRequestBase(BaseModel):
    receiver_id: int


class FriendRequestCreate(FriendRequestBase):
    pass


class FriendRequestUpdate(BaseModel):
    status: str


class FriendRequestResponse(FriendRequestBase):
    id: int
    sender: UserResponse
    receiver: UserResponse
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
