import asyncio
from app.db.session import AsyncSessionLocal
from app.models.phoneme import Phoneme
from sqlalchemy import select

async def main():
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Phoneme).filter(Phoneme.audio_url == None))
        missing = result.scalars().all()
        
        for p in missing:
            if p.symbol == 'A':
                p.audio_url = '/audio_standardized/phoneme_a_short.mp3'
            elif p.symbol == 'ɪ':
                p.audio_url = '/audio_standardized/phoneme_i_short.mp3'
            elif p.symbol == 'ɒ/ɔ':
                p.audio_url = '/audio_standardized/phoneme_o_short.mp3'
            elif p.symbol == 'ʌ/ə':
                p.audio_url = '/audio_standardized/phoneme_u_short.mp3'
            else:
                p.audio_url = '/audio_standardized/phoneme_e.mp3' # default fallback
            print(f"Fixed mapping for {p.symbol}")
            
        await session.commit()
        
        result = await session.execute(select(Phoneme))
        total = len(result.scalars().all())
        print(f"Total phonemes in DB: {total}")

if __name__ == "__main__":
    asyncio.run(main())
