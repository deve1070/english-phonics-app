import asyncio
import os
import re
from app.db.session import AsyncSessionLocal
from app.models.phoneme import Phoneme
from sqlalchemy import select

def guess_filename(symbol, available_files):
    # Remove weird characters
    clean = symbol.lower()
    clean = re.sub(r'[^a-z0-9]', '', clean)
    
    # Try exact match without prefixes
    for f in available_files:
        name = f.replace('phoneme_', '').replace('.mp3', '')
        if clean == name:
            return f
            
    # Try to find a substring match
    if 'short' in clean or symbol in ['a', 'e', 'i', 'o', 'u']:
        if symbol == 'a': return 'phoneme_a_short.mp3'
        if symbol == 'e': return 'phoneme_e_short.mp3'
        if symbol == 'i' or symbol == 'ɪ': return 'phoneme_i_short.mp3'
        if symbol == 'o' or symbol == 'ɒ/ɔ': return 'phoneme_o_short.mp3'
        if symbol == 'u' or symbol == 'ʌ/ə': return 'phoneme_u_short.mp3'

    if 'long' in clean or 'eɪ' in symbol or 'iː' in symbol or 'aɪ' in symbol or 'oʊ' in symbol or 'uː' in symbol:
        if 'a' in symbol: return 'phoneme_a_long.mp3'
        if 'e' in symbol: return 'phoneme_ee.mp3'
        if 'i' in symbol: return 'phoneme_ie.mp3'
        if 'o' in symbol: return 'phoneme_o_long.mp3'
        if 'u' in symbol: return 'phoneme_u_long.mp3'

    for f in available_files:
        name = f.replace('phoneme_', '').replace('.mp3', '')
        # Handle 'th (voiced)' -> 'th'
        if name in clean:
            return f
            
    return None

async def main():
    directory = "uploads/audio_standardized"
    if not os.path.exists(directory):
        print(f"Directory {directory} not found")
        return
        
    available_files = [f for f in os.listdir(directory) if f.endswith('.mp3')]
    
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Phoneme))
        phonemes = result.scalars().all()
        
        updated_count = 0
        for p in phonemes:
            filename = guess_filename(p.symbol, available_files)
            if filename:
                p.audio_url = f"/audio_standardized/{filename}"
                updated_count += 1
                print(f"Mapped '{p.symbol}' -> {filename}")
            else:
                p.audio_url = None
                print(f"NO MAPPING for '{p.symbol}'")
                
        await session.commit()
        print(f"Updated {updated_count} phonemes.")

if __name__ == "__main__":
    asyncio.run(main())
