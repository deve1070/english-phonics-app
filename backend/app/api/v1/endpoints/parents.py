"""
app/api/v1/endpoints/parents.py
================================
Parent role endpoints.

Authentication:
  - All /parents/* routes require role=PARENT (get_current_parent)
  - Child-login returns a short-lived child token used by the Flutter
    kid UI; the parent token is unaffected.

Endpoints:
  POST  /parents/register              → parent + first child signup
  POST  /parents/children              → add another child
  GET   /parents/children              → list all children
  GET   /parents/dashboard             → all-children summary
  GET   /parents/children/{id}/progress → full analytics
  GET   /parents/children/{id}/weekly-report → AI-generated report
  PUT   /parents/children/{id}/goals   → set learning goals
  GET   /parents/children/{id}/screen-time → today's usage
  POST  /parents/children/{id}/end-session → force end session
  POST  /parents/child-login/{id}      → get child token for Flutter
"""

import json
from datetime import datetime, timedelta, timezone
from typing import List

from app.api.deps import get_db
from app.core.security import (
    create_access_token,
    get_current_active_user,
)
from app.models.parent import (
    LearningGoal,
    ParentChildLink,
    ScreenTimeLog,
    WeeklyReport,
)
from app.models.phoneme import Phoneme
from app.models.progress import Progress
from app.models.pronuncation_score import PronunciationScore
from app.models.user import User, UserRole
from app.schemas.schemas_parent import (
    ChildCreate,
    ChildProgressResponse,
    ChildResponse,
    ChildSummary,
    LearningGoalResponse,
    LearningGoalUpdate,
    ParentDashboardResponse,
    ParentRegister,
    ParentRegisterResponse,
    PhonemeProgress,
    ScreenTimeTodayResponse,
    SessionEndRequest,
    WeeklyReportResponse,
)
from app.services.weekly_report_service import generate_weekly_report
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/parents", tags=["parents"])


def _utc_naive(dt: datetime) -> datetime:
    """Naive UTC for TIMESTAMP WITHOUT TIME ZONE columns; asyncpg rejects tz-aware binds."""
    if dt.tzinfo is None:
        return dt
    return dt.astimezone(timezone.utc).replace(tzinfo=None)


# ── Dependency: current user must be PARENT ───────────────────────
async def get_current_parent(
    current_user: User = Depends(get_current_active_user),
) -> User:
    if current_user.role != UserRole.PARENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access restricted to parent accounts.",
        )
    return current_user


# ── Dependency: get child and verify ownership ────────────────────
async def get_owned_child(
    child_id: int,
    parent: User = Depends(get_current_parent),
    db: AsyncSession = Depends(get_db),
) -> User:
    result = await db.execute(
        select(ParentChildLink).where(
            ParentChildLink.parent_id == parent.id,
            ParentChildLink.child_id == child_id,
        )
    )
    link = result.scalar_one_or_none()
    if not link:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Child not found or not linked to this parent.",
        )
    child_result = await db.execute(select(User).where(User.id == child_id))
    child = child_result.scalar_one_or_none()
    if not child:
        raise HTTPException(status_code=404, detail="Child account not found.")
    return child


async def get_child_for_parent_switch(
    child_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    For child-login: accept the parent's token (verify parent–child link), or the
    child's own token when child_id matches (refresh / clients that still hold
    the kid JWT when opening the learning view).
    """
    if current_user.role == UserRole.PARENT:
        result = await db.execute(
            select(ParentChildLink).where(
                ParentChildLink.parent_id == current_user.id,
                ParentChildLink.child_id == child_id,
            )
        )
        link = result.scalar_one_or_none()
        if not link:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Child not found or not linked to this parent.",
            )
        child_result = await db.execute(select(User).where(User.id == child_id))
        child = child_result.scalar_one_or_none()
        if not child:
            raise HTTPException(status_code=404, detail="Child account not found.")
        return child

    if current_user.role == UserRole.STUDENT and current_user.id == child_id:
        return current_user

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=(
            "Use the parent's access token to open a child's profile, or sign in as "
            "that child when requesting child-login for the same account."
        ),
    )


# ── POST /parents/register ────────────────────────────────────────
@router.post(
    "/register",
    response_model=ParentRegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_parent(
    body: ParentRegister,
    db: AsyncSession = Depends(get_db),
):
    """
    Single-step parent + child registration.
    Creates the parent account, the child account, and links them.
    Returns an access token for the parent immediately.
    """
    # Check parent phone not taken
    existing = await db.execute(select(User).where(User.phone_number == body.phone_number))
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=400, detail="An account with this phone number already exists."
        )

    # Create parent user
    parent = User(
        name=body.name,
        phone_number=body.phone_number,
        role=UserRole.PARENT,
        is_active=True,
    )
    db.add(parent)
    await db.flush()  # get parent.id

    # Create child user
    child_user = await _create_child_user(db, body.child)

    # Link parent to child
    link = ParentChildLink(
        parent_id=parent.id,
        child_id=child_user.id,
        is_primary=True,
        nickname=body.child.nickname,
    )
    db.add(link)

    # Create default learning goals for the child
    goal = LearningGoal(
        child_id=child_user.id,
        daily_minutes_target=15,
        lessons_per_week=3,
        max_daily_minutes=30,
    )
    db.add(goal)

    await db.commit()
    await db.refresh(parent)
    await db.refresh(child_user)

    token = create_access_token(subject=str(parent.id))

    return ParentRegisterResponse(
        parent_id=parent.id,
        parent_phone=parent.phone_number,
        child=ChildResponse(
            id=child_user.id,
            name=child_user.name,
            user_name=child_user.user_name,
            is_active=child_user.is_active,
            nickname=body.child.nickname,
        ),
        access_token=token,
    )


# ── POST /parents/children ────────────────────────────────────────
@router.post("/children", response_model=ChildResponse, status_code=201)
async def add_child(
    body: ChildCreate,
    parent: User = Depends(get_current_parent),
    db: AsyncSession = Depends(get_db),
):
    """Add another child to an existing parent account."""
    child_user = await _create_child_user(db, body)
    link = ParentChildLink(
        parent_id=parent.id,
        child_id=child_user.id,
        is_primary=False,
        nickname=body.nickname,
    )
    db.add(link)
    goal = LearningGoal(
        child_id=child_user.id,
        daily_minutes_target=15,
        lessons_per_week=3,
        max_daily_minutes=30,
    )
    db.add(goal)
    await db.commit()
    await db.refresh(child_user)
    return ChildResponse(
        id=child_user.id,
        name=child_user.name,
        user_name=child_user.user_name,
        is_active=child_user.is_active,
        nickname=body.nickname,
    )


# ── GET /parents/children ─────────────────────────────────────────
@router.get("/children", response_model=List[ChildResponse])
async def list_children(
    parent: User = Depends(get_current_parent),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ParentChildLink, User)
        .join(User, User.id == ParentChildLink.child_id)
        .where(ParentChildLink.parent_id == parent.id)
        .order_by(ParentChildLink.created_at)
    )
    rows = result.all()
    return [
        ChildResponse(
            id=u.id,
            name=u.name,
            user_name=u.user_name,
            is_active=u.is_active,
            nickname=link.nickname,
        )
        for link, u in rows
    ]


# ── GET /parents/dashboard ────────────────────────────────────────
@router.get("/dashboard", response_model=ParentDashboardResponse)
async def parent_dashboard(
    parent: User = Depends(get_current_parent),
    db: AsyncSession = Depends(get_db),
):
    """High-level summary of all children for the parent home screen."""
    links_result = await db.execute(
        select(ParentChildLink, User)
        .join(User, User.id == ParentChildLink.child_id)
        .where(ParentChildLink.parent_id == parent.id)
    )
    rows = links_result.all()

    children_summaries = []
    for link, child in rows:
        screen = await _screen_time_today(db, child.id)
        progress = await _compute_progress_summary(db, child.id)
        children_summaries.append(
            ChildSummary(
                child_id=child.id,
                child_name=child.name,
                nickname=link.nickname,
                lessons_completed=progress["lessons_completed"],
                total_lessons=progress["total_lessons"],
                overall_progress_pct=progress["overall_progress_pct"],
                minutes_today=screen.minutes_used_today,
                max_daily_minutes=screen.max_daily_minutes,
                is_limit_reached=screen.is_limit_reached,
                streak_days=0,  # TODO: wire streak service
                last_active=progress["last_active"],
            )
        )

    return ParentDashboardResponse(
        parent_name=parent.name,
        total_children=len(children_summaries),
        children=children_summaries,
    )


# ── GET /parents/children/{id}/progress ──────────────────────────
@router.get("/children/{child_id}/progress", response_model=ChildProgressResponse)
async def child_progress(
    child: User = Depends(get_owned_child),
    db: AsyncSession = Depends(get_db),
):
    """Full learning analytics for one child."""
    scores_result = await db.execute(
        select(PronunciationScore).where(PronunciationScore.user_id == child.id)
    )
    scores = scores_result.scalars().all()

    phonemes_result = await db.execute(select(Phoneme).order_by(Phoneme.order))
    all_phonemes = phonemes_result.scalars().all()

    # Per-phoneme stats
    phoneme_map: dict[int, list[float]] = {}
    for s in scores:
        phoneme_map.setdefault(s.phoneme_id, []).append(s.score)

    phoneme_progress = []
    for p in all_phonemes:
        attempts_scores = phoneme_map.get(p.id, [])
        avg = sum(attempts_scores) / len(attempts_scores) if attempts_scores else None
        phoneme_progress.append(
            PhonemeProgress(
                phoneme_id=p.id,
                symbol=p.symbol,
                order=p.order,
                is_mastered=bool(avg and avg >= 80),
                avg_score=round(avg, 1) if avg else None,
                attempts=len(attempts_scores),
            )
        )

    summary = await _compute_progress_summary(db, child.id)
    avg_overall = sum(s.score for s in scores) / len(scores) if scores else None
    screen = await _screen_time_this_week(db, child.id)

    return ChildProgressResponse(
        child_id=child.id,
        child_name=child.name,
        lessons_completed=summary["lessons_completed"],
        total_lessons=summary["total_lessons"],
        exercises_completed=summary["exercises_completed"],
        total_exercises=summary["total_exercises"],
        avg_pronunciation_score=round(avg_overall, 1) if avg_overall else None,
        streak_days=0,
        minutes_this_week=screen,
        phoneme_progress=phoneme_progress,
        last_active=summary["last_active"],
    )


# ── GET /parents/children/{id}/weekly-report ─────────────────────
@router.get("/children/{child_id}/weekly-report", response_model=WeeklyReportResponse)
async def get_weekly_report(
    child: User = Depends(get_owned_child),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns this week's AI-generated report.
    If not generated yet (e.g. it's Monday morning), generates it now.
    Reports are cached — re-reading the same week returns the cached version.
    """
    monday = _current_week_monday()
    result = await db.execute(
        select(WeeklyReport).where(
            WeeklyReport.child_id == child.id,
            WeeklyReport.week_start == monday,
        )
    )
    report = result.scalar_one_or_none()

    if not report:
        report = await generate_weekly_report(db, child_id=child.id, week_start=monday)

    return WeeklyReportResponse(
        week_start=report.week_start,
        summary_text=report.summary_text,
        phonemes_mastered=json.loads(report.phonemes_mastered or "[]"),
        phonemes_struggling=json.loads(report.phonemes_struggling or "[]"),
        avg_pronunciation_score=report.avg_pronunciation_score,
        sessions_completed=report.sessions_completed,
        total_minutes=report.total_minutes,
        recommended_focus=report.recommended_focus,
        encouragement_message=report.encouragement_message,
        generated_at=report.generated_at,
    )


# ── PUT /parents/children/{id}/goals ─────────────────────────────
@router.put("/children/{child_id}/goals", response_model=LearningGoalResponse)
async def update_goals(
    body: LearningGoalUpdate,
    child: User = Depends(get_owned_child),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(LearningGoal).where(LearningGoal.child_id == child.id)
    )
    goal = result.scalar_one_or_none()
    if not goal:
        goal = LearningGoal(child_id=child.id)
        db.add(goal)

    if body.daily_minutes_target is not None:
        goal.daily_minutes_target = body.daily_minutes_target
    if body.lessons_per_week is not None:
        goal.lessons_per_week = body.lessons_per_week
    if body.max_daily_minutes is not None:
        goal.max_daily_minutes = body.max_daily_minutes

    await db.commit()
    await db.refresh(goal)
    return goal


# ── GET /parents/children/{id}/screen-time ───────────────────────
@router.get("/children/{child_id}/screen-time", response_model=ScreenTimeTodayResponse)
async def screen_time_today(
    child: User = Depends(get_owned_child),
    db: AsyncSession = Depends(get_db),
):
    return await _screen_time_today(db, child.id)


# ── POST /parents/children/{id}/end-session ──────────────────────
@router.post("/children/{child_id}/end-session", status_code=200)
async def end_child_session(
    body: SessionEndRequest,
    child: User = Depends(get_owned_child),
    db: AsyncSession = Depends(get_db),
):
    """
    Parent force-ends the child's current session.
    The Flutter child app listens for a signal and navigates to a
    'session ended by parent' screen.
    Sets a flag in the session log so Flutter can poll this.
    """
    result = await db.execute(
        select(ScreenTimeLog).where(
            ScreenTimeLog.child_id == child.id,
            ScreenTimeLog.session_end == None,
        )
    )
    active = result.scalar_one_or_none()
    if active:
        now = _utc_naive(datetime.now(timezone.utc))
        active.session_end = now
        active.duration_mins = (now - active.session_start).total_seconds() / 60
        await db.commit()
    return {"message": "Session ended."}


# ── POST /parents/child-login/{id} ───────────────────────────────
@router.post("/child-login/{child_id}")
async def child_login(
    child: User = Depends(get_child_for_parent_switch),
):
    """
    Returns a short-lived access token for the child account.
    The parent uses this to switch into the child's learning view
    without the child needing to log in separately.
    Token expires in 2 hours (a single learning session).
    """
    token = create_access_token(
        subject=str(child.id),
        expires_delta=timedelta(hours=2),
    )
    return {
        "access_token": token,
        "token_type": "bearer",
        "child_id": child.id,
        "child_name": child.name,
        "expires_in_seconds": 7200,
    }


# ── Internal helpers ──────────────────────────────────────────────
async def _create_child_user(db: AsyncSession, body: ChildCreate) -> User:
    existing = await db.execute(select(User).where(User.user_name == body.user_name))
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail=f"Username '{body.user_name}' is already taken.",
        )
    child = User(
        name=body.name,
        user_name=body.user_name,
        role=UserRole.STUDENT,
        is_active=True,
    )
    db.add(child)
    await db.flush()
    return child


async def _compute_progress_summary(db: AsyncSession, child_id: int) -> dict:
    from app.models.exercise import Exercise
    from app.models.lesson import Lesson

    lessons_result = await db.execute(select(func.count()).select_from(Lesson))
    total_lessons = lessons_result.scalar() or 0

    exercises_result = await db.execute(select(func.count()).select_from(Exercise))
    total_exercises = exercises_result.scalar() or 0

    completed_ex = await db.execute(
        select(func.count())
        .select_from(Progress)
        .where(
            Progress.user_id == child_id,
            Progress.completed == True,  # noqa: E712
        )
    )
    exercises_completed = completed_ex.scalar() or 0

    # Count lessons where all exercises are completed
    # Simplified: count distinct lesson IDs that have at least one completed exercise
    completed_lessons_result = await db.execute(
        select(func.count(func.distinct(Exercise.lesson_id)))
        .join(Progress, Progress.exercise_id == Exercise.id)
        .where(
            Progress.user_id == child_id,
            Progress.completed == True,  # noqa: E712
        )
    )
    lessons_completed = completed_lessons_result.scalar() or 0

    progress_pct = (
        round(exercises_completed / total_exercises * 100, 1)
        if total_exercises
        else 0.0
    )

    last_score = await db.execute(
        select(PronunciationScore.timestamp)
        .where(PronunciationScore.user_id == child_id)
        .order_by(PronunciationScore.timestamp.desc())
        .limit(1)
    )
    last_active = last_score.scalar_one_or_none()

    return {
        "lessons_completed": lessons_completed,
        "total_lessons": total_lessons,
        "exercises_completed": exercises_completed,
        "total_exercises": total_exercises,
        "overall_progress_pct": progress_pct,
        "last_active": last_active,
    }


async def _screen_time_today(
    db: AsyncSession, child_id: int
) -> ScreenTimeTodayResponse:
    today_start = _utc_naive(
        datetime.now(timezone.utc).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
    )
    result = await db.execute(
        select(ScreenTimeLog).where(
            ScreenTimeLog.child_id == child_id,
            ScreenTimeLog.session_start >= today_start,
        )
    )
    logs = result.scalars().all()
    total_mins = sum(
        (log.duration_mins or 0) for log in logs if log.session_end is not None
    )
    sessions = len([l for l in logs if l.session_end is not None])

    goal_result = await db.execute(
        select(LearningGoal).where(LearningGoal.child_id == child_id)
    )
    goal = goal_result.scalar_one_or_none()
    max_mins = goal.max_daily_minutes if goal else 30

    return ScreenTimeTodayResponse(
        minutes_used_today=round(total_mins, 1),
        max_daily_minutes=max_mins,
        is_limit_reached=total_mins >= max_mins,
        sessions_today=sessions,
    )


async def _screen_time_this_week(db: AsyncSession, child_id: int) -> float:
    week_start = _current_week_monday()
    result = await db.execute(
        select(ScreenTimeLog).where(
            ScreenTimeLog.child_id == child_id,
            ScreenTimeLog.session_start >= week_start,
            ScreenTimeLog.session_end != None,
        )
    )
    logs = result.scalars().all()
    return round(sum(log.duration_mins or 0 for log in logs), 1)


def _current_week_monday() -> datetime:
    today = datetime.now(timezone.utc)
    days_since_monday = today.weekday()
    monday = today - timedelta(days=days_since_monday)
    monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    return _utc_naive(monday)
