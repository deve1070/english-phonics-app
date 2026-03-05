from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from ..core.config import settings

raw_url = settings.DATABASE_URL
if not raw_url or not raw_url.strip():
    raise ValueError("DATABASE_URL is not set in the configuration.")

DATABASE_URL = raw_url.replace("postgresql://", "postgresql+asyncpg://")
engine = create_async_engine(DATABASE_URL, echo=settings.DEBUG)

AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_db() -> AsyncGenerator:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
