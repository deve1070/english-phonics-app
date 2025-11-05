from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class BaseCofig(BaseSettings):
    PROJECT_NAME: str = "English Phonics App"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    ENV_STATE: Optional[str] = None


class GlobalCofig(BaseCofig):
    DATABASE_URL: Optional[str] = None
    DB_FORCE_ROLL_BACK: bool = False


class DevConfig(GlobalCofig):
    model_config = SettingsConfigDict(env_prefix="DEV_")


class TestConfig(GlobalCofig):
    model_config = SettingsConfigDict(env_prefix="TEST_")


class ProdCofig(GlobalCofig):
    model_config = SettingsConfigDict(env_prefix="PROD_")


@lru_cache()
def get_config(env_state: str):
    configs = {"dev": DevConfig, "test": TestConfig, "prod": ProdCofig}
    return configs[env_state]


config = get_config(BaseCofig().ENV_STATE)
