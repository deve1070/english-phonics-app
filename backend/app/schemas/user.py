from typing import Optional

from pydantic import BaseModel, EmailStr
from pydantic_settings import SettingsConfigDict


class UserBase(BaseModel):
    name: str
    email: EmailStr


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None


class User(UserBase):
    id: int
    model_config = SettingsConfigDict({"from_attributes": True})
