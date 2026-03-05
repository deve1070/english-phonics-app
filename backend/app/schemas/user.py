from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, PhoneNumber
from pydantic_settings import SettingsConfigDict


class UserBase(BaseModel):
    first_name: str
    father_name: str
    email: EmailStr
    age: int
    image_url: Optional[str] = None
    is_active: bool = True
    created_at: Optional[datetime] = None
    user_name: Optional[str] = None
    grade_level: Optional[int] = None
    school_name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)
    parent_phone_number: PhoneNumber = Field(
        ..., min_length=10, max_length=15, regex=r"^\+?\d{10,15}$"
    )


class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    father_name: Optional[str] = None
    image_url: Optional[str] = None
    grade_level: Optional[int] = None
    school_name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None


class UserResponse(BaseModel):
    id: int
    first_name: str
    father_name: str
    email: EmailStr
    age: int
    is_active: bool
    created_at: Optional[datetime] = None
    grade_level: Optional[int] = None
    school_name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)


class User(UserBase):
    id: int
    model_config = SettingsConfigDict({"from_attributes": True})
