import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

import app.models  # noqa: F401 - register all models before API so SQLAlchemy can resolve relationships (e.g. User -> Subscription)
from .api import api_router
from .core.config import settings
from .core.lifespan import lifespan

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan,
)

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mounted at "/audio" (not "/static") because save_audio_file() in
# app/utils/audio.py returns URLs like "/audio/<filename>" — this was
# previously mismatched, so any client hitting the audio_url directly
# (rather than through a dedicated streaming endpoint) would 404.
app.mount("/audio", StaticFiles(directory="uploads/audio"), name="audio")
app.mount(
    "/audio_standardized",
    StaticFiles(directory="uploads/audio_standardized"),
    name="audio_standardized",
)
app.include_router(api_router, prefix="/api/v1")


@app.get("/")
async def root():
    return {"message": "Async FastAPI + SQLAlchemy ORM setup complete!"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, reload=settings.DEBUG)
