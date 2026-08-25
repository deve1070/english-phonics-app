import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import asyncio
from app.db.session import AsyncSessionLocal
from app.models.phoneme import Phoneme
from sqlalchemy import select

async def main():
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Phoneme))
        phonemes = result.scalars().all()
        for p in phonemes:
            print(f"ID: {p.id}, Symbol: '{p.symbol}', Audio: {p.audio_url}")

if __name__ == "__main__":
    asyncio.run(main())
