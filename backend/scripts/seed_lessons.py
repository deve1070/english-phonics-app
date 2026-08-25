# seed_lessons.py
# Run from backend: python seed_lessons.py
# Creates a default lesson (id=1) so phonemes and exercises can reference it.
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import asyncio

from app.db.session import AsyncSessionLocal
from app.models.lesson import Lesson
from app.models.enums import Level


async def seed_lessons():
    from sqlalchemy import select

    async with AsyncSessionLocal() as db:
        existing = await db.execute(select(Lesson).limit(1))
        if existing.scalar_one_or_none() is not None:
            print("Lessons already exist. Skipping seed.")
            return
        lesson = Lesson(order=1, level=Level.LEVEL1)
        db.add(lesson)
        await db.commit()
        await db.refresh(lesson)
        print(f"Created lesson: id={lesson.id}, order={lesson.order}, level={lesson.level}")


if __name__ == "__main__":
    asyncio.run(seed_lessons())
