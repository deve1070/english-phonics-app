import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from contextlib import asynccontextmanager

from fastapi import FastAPI

from .api import api_router
from .core.config import config
from .db.base_class import Base  # For metadata
from .db.session import engine  # Fixed: Import from db.session


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Create tables (use Alembic in prod)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("All tables created successfully")
    yield
    await engine.dispose()


app = FastAPI(
    title=config.PROJECT_NAME,
    version=config.VERSION,  # Fixed: Matches config.py
    lifespan=lifespan,  # Replaces @app.on_event
)

app.include_router(api_router, prefix="/api/v1")


@app.get("/")
async def root():
    return {"message": "Async FastAPI + SQLAlchemy ORM setup complete!"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, reload=config.DEBUG)  # Reload in dev
