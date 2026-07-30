from datetime import datetime
from enum import Enum as PyEnum
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class UserBase(BaseModel):
    name: str
    phone_number: Optional[str] = None
    is_active: bool = True
    role: Optional[str] = "STUDENT"
    created_at: Optional[datetime] = None
    user_name: Optional[str] = None

    @field_validator("role", mode="before")
    @classmethod
    def role_to_str(cls, v):
        if v is None:
            return None
        if isinstance(v, PyEnum):
            return v.value
        return v


class UserRegister(UserBase):
    """Phone sign-up."""
    phone_number: str = Field(..., min_length=9)


class UserUpdate(BaseModel):
    name: Optional[str] = None
    phone_number: Optional[str] = None


class UserResponse(UserBase):
    id: int
    user_name: str
    model_config = ConfigDict(from_attributes=True)


class User(UserBase):
    id: int
    model_config = ConfigDict(from_attributes=True)
