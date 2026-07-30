from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.config import settings
from app.db.base import Base
from app.db.session import engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: only auto-create tables in dev/test. In prod, schema is
    # owned by Alembic migrations — running create_all there risks
    # masking a missing migration or drifting from what Alembic thinks
    # the schema looks like.
    if settings.ENV_STATE in ("dev", "test"):
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()
