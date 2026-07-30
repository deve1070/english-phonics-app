import asyncio
from sqlalchemy import delete
from app.db.session import AsyncSessionLocal
from app.models.exercise import Exercise
from app.models.phoneme import Phoneme
from seed_phonemes import seed

from sqlalchemy import text

async def run():
    async with AsyncSessionLocal() as db:
        print("Wiping existing exercises and phonemes...")
        await db.execute(text("TRUNCATE TABLE exercise_phoneme, exercises, phonemes, lessons CASCADE;"))
        await db.commit()
    print("Re-seeding phonemes...")
    await seed()

if __name__ == "__main__":
    asyncio.run(run())
