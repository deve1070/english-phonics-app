from app import models
from app.database import engine
from fastapi import FastAPI

app = FastAPI()


@app.on_event("startup")
async def on_startup():
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)
    print("All tables created successfully")


@app.get("/")
async def root():
    return {"message": "Asynch FastAPI  + SQLAlchemy ORM setup complete!"}
