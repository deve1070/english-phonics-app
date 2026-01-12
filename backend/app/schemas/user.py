from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field
from pydantic_settings import SettingsConfigDict


class UserBase(BaseModel):
    name: str
    email: EmailStr
    age_group: int
    is_active: bool = True
    role: Optional[str] = "STUDENT"
    created_at: Optional[datetime] = None
    user_name: Optional[str] = None
    grade_level: Optional[int] = None
    school_name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None


class UserResponse(UserBase):
    user_name: str
    model_config = ConfigDict(from_attributes=True)


class User(UserBase):
    id: int
    model_config = SettingsConfigDict({"from_attributes": True})
