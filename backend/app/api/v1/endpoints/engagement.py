"""
Engagement endpoints (child-facing)
===================================
GET  /me/quest/today      — today's three tasks
GET  /me/streak           — streak, including freezes earned and spent
GET  /me/collection       — every phoneme sticker, locked and unlocked
POST /me/collection/seen  — acknowledge the celebration
GET  /me/recognition/round  — "which symbol says this sound?"
POST /me/recognition/round  — record a finished round
GET  /me/goal             — this week's goal, or the three on offer
POST /me/goal             — make the promise
GET  /me/promise/voice    — the grown-up's recording, once the week is kept
GET  /me/stories          — the decodable library

All of these are scoped to the calling child. There is no child_id
parameter anywhere by design: the only account that can read a child's
quest is that child. Parents reach the same underlying facts through
/parents/children/{id}/progress, which enforces ownership separately.
"""

from datetime import date
from pathlib import Path

from app.api.deps import get_db
from app.core.security import get_current_student
from app.models.enums import RecognitionMode
from app.models.phoneme import Phoneme
from app.models.user import User
from app.schemas.engagement import (
    CollectibleResponse,
    CollectionResponse,
    EarnedWeekResponse,
    GoalChoiceRequest,
    GoalOptionResponse,
    GoalResponse,
    PromiseResponse,
    QuestItemResponse,
    QuestResponse,
    RecognitionOption,
    RecognitionQuestionResponse,
    RecognitionRoundResponse,
    RecognitionRoundResult,
    RecognitionSummary,
    StoryListResponse,
    StoryResponse,
    StreakResponse,
)
from app.services import (
    collection_service,
    goal_service,
    promise_service,
    quest_service,
    recognition_service,
    story_service,
)
from app.services.recognition_service import ROUND_SIZE as RECOGNITION_ROUND_SIZE
from app.services.streak_service import streak_summary
from app.services.streak_service import week_start as streak_service_week_start
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/me", tags=["engagement"])


def _phoneme_audio_path(phoneme_id: int) -> str:
    """Where the client can fetch a sound.

    Relative to the API root, which is what the mobile client's HTTP base
    URL already points at. Must stay in step with the route in
    endpoints/phonemes.py — there is no reverse-URL helper in this app,
    and inventing one for a single link would cost more than it saves.
    """
    return f"/phonemes/{phoneme_id}/audio"


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

    # The two tracks stay separate all the way to the client: recognising a
    # sound never unlocks the creature, it only opens its eyes.
    recognised = await recognition_service.recognised_phoneme_ids(db, child.id)

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
            is_recognised=p.id in recognised,
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


# ── GET /me/recognition/round ────────────────────────────────────
@router.get("/recognition/round", response_model=RecognitionRoundResponse)
async def recognition_round(
    mode: RecognitionMode = RecognitionMode.EXPLORE,
    size: int = RECOGNITION_ROUND_SIZE,
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """A short round of "which symbol says this sound?".

    Each question carries its own answer. That is intentional: a
    six-year-old cannot be left waiting on the network to find out whether
    they were right, so the client marks it locally and posts the whole
    round afterwards. There is nothing to protect here — the app is not a
    competition and the device belongs to the child.

    In EXPLORE the client lets the child tap any symbol to hear it. Every
    option's audio is its own true sound in both modes; the app never
    plays a symbol the wrong sound in order to trick anyone.
    """
    questions = await recognition_service.build_round(
        db, child.id, mode=mode, size=max(1, min(size, 10))
    )
    return RecognitionRoundResponse(
        mode=mode,
        questions=[
            RecognitionQuestionResponse(
                target_phoneme_id=q.target.id,
                target_audio_url=_phoneme_audio_path(q.target.id),
                options=[
                    RecognitionOption(
                        phoneme_id=o.id,
                        symbol=o.symbol,
                        grapheme=(o.graphemes or "").split(",")[0] or o.symbol,
                        audio_url=_phoneme_audio_path(o.id),
                    )
                    for o in q.options
                ],
            )
            for q in questions
        ],
    )


# ── POST /me/recognition/round ───────────────────────────────────
@router.post("/recognition/round", response_model=RecognitionSummary)
async def submit_recognition_round(
    result: RecognitionRoundResult,
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """Record a finished round in one write.

    Batched so a dropped connection cannot cost a child a round they have
    already done.
    """
    before = await recognition_service.recognised_phoneme_ids(db, child.id)

    recorded = await recognition_service.record_answers(
        db,
        child.id,
        [
            recognition_service.SubmittedAnswer(
                phoneme_id=a.phoneme_id,
                chosen_phoneme_id=a.chosen_phoneme_id,
                mode=result.mode,
                option_count=a.option_count,
            )
            for a in result.answers
        ],
    )

    after = await recognition_service.recognised_phoneme_ids(db, child.id)
    return RecognitionSummary(
        recorded=recorded,
        newly_recognised=sorted(after - before),
        total_recognised=len(after),
    )


async def _promise_for(
    db: AsyncSession, child_id: int, is_complete: bool
) -> PromiseResponse | None:
    """This week's promise, with the recording sealed until it is earned.

    The url the child gets points back at this app rather than at the
    stored path: the file lives under uploads/ next to every other bit of
    audio, and only this route knows whether the week has been kept.
    """
    view = await promise_service.child_view(db, child_id, is_complete=is_complete)
    if view is None or view.is_empty:
        return None

    return PromiseResponse(
        text=view.text,
        parent_name=view.parent_name,
        has_voice=view.has_voice,
        voice_url="/me/promise/voice" if view.voice_url else None,
    )


# ── GET /me/promise/voice ────────────────────────────────────────
@router.get("/promise/voice")
async def my_promise_voice(
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """The parent's recording, once the week has been kept.

    Checked here as well as in the goal response, because this route can
    be reached directly. A child who has not finished gets a 404 rather
    than the file — the message is not lost, it is simply not theirs yet.
    """
    current = await goal_service.progress(db, child.id)
    view = await promise_service.child_view(
        db, child.id, is_complete=current is not None and current.is_complete
    )
    if view is None or view.voice_url is None:
        raise HTTPException(404, "No message to play yet.")

    path = Path("uploads") / view.voice_url.lstrip("/")
    if not path.exists():
        raise HTTPException(404, "The recording is missing.")

    def stream():
        with open(path, "rb") as f:
            yield from f

    return StreamingResponse(stream(), media_type="audio/mpeg")


# ── GET /me/goal ─────────────────────────────────────────────────
@router.get("/goal", response_model=GoalResponse)
async def my_goal(
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """This week's promise, or the three the child may choose from.

    One response for both states so the home screen makes a single call
    and the client never has to ask "has this child chosen yet?" before
    knowing what to draw.
    """
    earned = [
        EarnedWeekResponse(week_start=e.week_start, kind=e.kind)
        for e in await goal_service.earned_weeks(db, child.id)
    ]
    current = await goal_service.progress(db, child.id)

    # The goal's completion is the one thing that unseals the recording,
    # so the promise is read after it and never before.
    promise = await _promise_for(db, child.id, current is not None and current.is_complete)

    if current is None:
        options = await goal_service.options_for(db, child.id)
        return GoalResponse(
            week_start=streak_service_week_start(date.today()),
            choices=[
                GoalOptionResponse(kind=o.kind, target=o.target) for o in options
            ],
            earned_weeks=earned,
            promise=promise,
        )

    return GoalResponse(
        week_start=current.week_start,
        kind=current.kind,
        target=current.target,
        done=current.done,
        is_complete=current.is_complete,
        earned_weeks=earned,
        promise=promise,
    )


# ── POST /me/goal ────────────────────────────────────────────────
@router.post("/goal", response_model=GoalResponse)
async def choose_goal(
    choice: GoalChoiceRequest,
    db: AsyncSession = Depends(get_db),
    child: User = Depends(get_current_student),
):
    """Make this week's promise.

    The size comes from the server. Choosing twice in a week returns the
    first choice unchanged rather than erroring: from the child's side
    that is simply the goal they set, and there is nothing here worth
    showing them an error over.
    """
    await goal_service.choose(db, child.id, choice.kind)
    current = await goal_service.progress(db, child.id)
    earned = [
        EarnedWeekResponse(week_start=e.week_start, kind=e.kind)
        for e in await goal_service.earned_weeks(db, child.id)
    ]

    return GoalResponse(
        week_start=current.week_start,
        kind=current.kind,
        target=current.target,
        done=current.done,
        is_complete=current.is_complete,
        earned_weeks=earned,
    )


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
