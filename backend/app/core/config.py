import os
from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class BaseConfig(BaseSettings):
    PROJECT_NAME: str = "English Phonics App"
    VERSION: str = "0.1.0"
    ENV_STATE: str = os.getenv("ENV_STATE", "dev")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "supersecretkey")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 8
    DEBUG: bool = os.getenv("DEBUG", "true").lower() == "true"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_ignore_empty=True,
        extra="ignore",
    )


class GlobalConfig(BaseConfig):
    DATABASE_URL: Optional[str] = None
    DB_FORCE_ROLLBACK: bool = False
    AUDIO_STORAGE_URL: Optional[str] = None


class DevConfig(GlobalConfig):
    model_config = SettingsConfigDict(env_prefix="DEV_")


class TestConfig(GlobalConfig):
    model_config = SettingsConfigDict(env_prefix="TEST_")


class ProdConfig(GlobalConfig):
    model_config = SettingsConfigDict(env_prefix="PROD_")


@lru_cache()
def get_config(env_state: str) -> GlobalConfig:
    # Validate env_state
    if env_state not in {"dev", "test", "prod"}:
        raise ValueError(
            f"Invalid ENV_STATE: {env_state}. Must be 'dev', 'test', or 'prod'."
        )

    configs = {"dev": DevConfig, "test": TestConfig, "prod": ProdConfig}
    return configs[env_state]()


# Global config instance: Automatically uses ENV_STATE from env or default
config = get_config(os.getenv("ENV_STATE", "dev"))


# ... end of file
config = get_config(os.getenv("ENV_STATE", "dev"))
