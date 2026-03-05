from app.core.config import settings
from openai import AzureOpenAI
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict

client = AzureOpenAI(
    api_version="2024-08-01-preview",
    azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
    api_key=settings.AZURE_OPENAI_API_KEY,
)


async def get_user_mastered_phonemes(
        db:AsyncSession, user_id:int,
        threshold:int=80
)->List[Dict]:
    """ Get Phonemes user has mastered(avg_score >= threshold) + current lesson phonemes."""
    masterd_query=text("""
                    SELECT p.id, p.symbol,AVG(ps.score) AS avg_score
                    FROM pronunciation_scores ps
                    JOIN exercise e ON )
