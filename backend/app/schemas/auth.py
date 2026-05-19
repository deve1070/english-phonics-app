from typing import Optional

from pydantic import BaseModel


class Token(BaseModel):
    access_token: str
    token_type: str
    biometric_token: Optional[str] = None


class TokenData(BaseModel):
    user_id: Optional[str] = None


class PhoneLogin(BaseModel):
    phone_number: str


class PasskeyLogin(BaseModel):
    biometric_token: str
