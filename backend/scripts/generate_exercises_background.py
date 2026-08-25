import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import asyncio
from sqlalchemy import select, delete, text
from app.db.session import AsyncSessionLocal
from app.models.phoneme import Phoneme
from app.models.exercise import Exercise
from app.services.exercise_generation_service import generate_exercises_for_phoneme

async def main():
    async with AsyncSessionLocal() as session:
        print("Fetching all phonemes...")
        result = await session.execute(select(Phoneme).order_by(Phoneme.order))
        phonemes = result.scalars().all()
        
        # We already deleted them in the last script run, but let's be safe
        await session.execute(text("DELETE FROM exercise_phoneme"))
        await session.execute(delete(Exercise))
        await session.commit()
        
        for p in phonemes:
            print(f"Generating exercises for {p.symbol} (order={p.order})...")
            allowed_res = await session.execute(
                select(Phoneme).filter(Phoneme.order <= p.order)
            )
            allowed_phonemes = allowed_res.scalars().all()
            
            try:
                await generate_exercises_for_phoneme(
                    session,
                    target_phoneme=p,
                    allowed_phonemes=allowed_phonemes
                )
                print(f"Successfully generated for {p.symbol}")
            except Exception as e:
                print(f"Failed generating for {p.symbol}: {str(e)}")
            
            await asyncio.sleep(1)

if __name__ == "__main__":
    asyncio.run(main())
