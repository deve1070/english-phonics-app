from functools import lru_cache
from typing import Literal, Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # ---------------------------
    # Core App
    # ---------------------------
    PROJECT_NAME: str = "English Phonics App"
    VERSION: str = "0.1.0"
    ENV_STATE: Literal["dev", "test", "prod"] = "dev"
    DEBUG: bool = True

    # ---------------------------
    # Security
    # ---------------------------
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # ---------------------------
    # Database
    # ---------------------------
    DATABASE_URL: str

    # ---------------------------
    # Azure Services
    # ---------------------------
    AZURE_OPENAI_API_KEY: Optional[str] = None
    AZURE_OPENAI_ENDPOINT: Optional[str] = None
    AZURE_OPENAI_DEPLOYMENT_NAME: Optional[str] = None
    AZURE_SPEECH_KEY: Optional[str] = None
    AZURE_SPEECH_REGION: Optional[str] = None

    # ---------------------------
    # Storage
    # ---------------------------
    AUDIO_STORAGE_URL: Optional[str] = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=True,
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
