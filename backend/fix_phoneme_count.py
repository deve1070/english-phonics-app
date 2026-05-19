import asyncio
import json
from app.db.session import AsyncSessionLocal
from app.models.phoneme import Phoneme
from sqlalchemy import select, delete

async def main():
    with open('phoneme.json') as f:
        data = json.load(f)
    valid_ids = [p['id'] for p in data['phonemes']]
    
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Phoneme))
        db_phonemes = result.scalars().all()
        
        for p in db_phonemes:
            if p.id not in valid_ids:
                print(f"Deleting extra phoneme: ID={p.id}, Symbol={p.symbol}")
                await session.delete(p)
                
        await session.commit()
        
        # Verify count
        result = await session.execute(select(Phoneme))
        print(f"Final phoneme count: {len(result.scalars().all())}")

if __name__ == "__main__":
    asyncio.run(main())
