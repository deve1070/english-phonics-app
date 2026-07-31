"""
Engagement endpoints (child-facing)
===================================
GET  /me/quest/today      — today's three tasks
GET  /me/streak           — streak, including freezes earned and spent
GET  /me/collection       — every phoneme sticker, locked and unlocked
POST /me/collection/seen  — acknowledge the celebration
GET  /me/stories          — the decodable library

All of these are scoped to the calling child. There is no child_id
parameter anywhere by design: the only account that can read a child's
quest is that child. Parents reach the same underlying facts through
/parents/children/{id}/progress, which enforces ownership separately.
"""

from datetime import date

from app.api.deps import get_db
from app.core.security import get_current_student
from app.models.phoneme import Phoneme
from app.models.user import User
from app.schemas.engagement import (
    CollectibleResponse,
    CollectionResponse,
    QuestItemResponse,
    QuestResponse,
    StoryListResponse,
    StoryResponse,
    StreakResponse,
)
from app.services import collection_service, quest_service, story_service
from app.services.streak_service import streak_summary
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/me", tags=["engagement"])


# ── GET /me/quest/today ──────────────────────────────────────────
@router.get("/quest/today", response_model=QuestResponse)
async def todays_quest(
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """The child's three tasks for today, fixed for the day once asked for.

    May return fewer than three items when the curriculum has no suitable
    exercise for a slot — with generated content missing this is the
    normal case, not an error. The client renders whatever arrives.
    """
    quest = await quest_service.get_or_create_today(db, child.id)
    return QuestResponse(
        quest_date=quest.quest_date,
        items=[
            QuestItemResponse(
                slot=item.slot,
                exercise_id=item.exercise.id,
                content=item.exercise.content,
                type=item.exercise.type,
                completed=item.completed,
            )
            for item in quest.items
        ],
        completed_count=quest.completed_count,
        total_count=len(quest.items),
        is_complete=quest.is_complete,
    )


# ── GET /me/streak ───────────────────────────────────────────────
@router.get("/streak", response_model=StreakResponse)
async def my_streak(
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    summary = await streak_summary(db, child.id)
    return StreakResponse(
        days=summary.days,
        freezes_available=summary.freezes_available,
        frozen_dates=summary.frozen_dates,
    )


# ── GET /me/collection ───────────────────────────────────────────
@router.get("/collection", response_model=CollectionResponse)
async def my_collection(
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """Every phoneme as a collectible, with the earned ones marked.

    Locked entries are returned too, and deliberately: a shelf with
    visible gaps is what makes a collection worth completing. An empty
    shelf that fills in from nothing shows the child no goal.
    """
    pending = await collection_service.sync_unlocks(db, child.id)
    unlocks = await collection_service.all_unlocks(db, child.id)
    pending_ids = {u.phoneme_id for u in pending}

    phonemes = (
        await db.execute(select(Phoneme).order_by(Phoneme.order))
    ).scalars().all()

    items = [
        CollectibleResponse(
            phoneme_id=p.id,
            symbol=p.symbol,
            order=p.order,
            phoneme_type=p.type.value if p.type else "alphabet",
            is_unlocked=p.id in unlocks,
            unlocked_at=unlocks[p.id].unlocked_at if p.id in unlocks else None,
            is_new=p.id in pending_ids,
        )
        for p in phonemes
    ]

    return CollectionResponse(
        total=len(items),
        unlocked=len(unlocks),
        items=items,
        newly_unlocked=sorted(pending_ids),
    )


# ── POST /me/collection/seen ─────────────────────────────────────
@router.post("/collection/seen")
async def mark_collection_seen(
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """Acknowledge that the child has been shown their new stickers."""
    count = await collection_service.mark_seen(db, child.id)
    return {"acknowledged": count}


# ── GET /me/stories ──────────────────────────────────────────────
@router.get("/stories", response_model=StoryListResponse)
async def my_stories(
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    stories = await story_service.list_stories(db, child.id)
    return StoryListResponse(
        total=len(stories),
        unlocked=sum(1 for s in stories if s.is_unlocked),
        stories=[
            StoryResponse(
                exercise_id=s.exercise_id,
                title=s.title,
                word_count=s.word_count,
                is_unlocked=s.is_unlocked,
                blocking_phoneme=s.blocking_phoneme,
                content=s.content if s.is_unlocked else None,
            )
            for s in stories
        ],
    )
