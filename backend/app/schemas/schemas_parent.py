"""app/schemas/parent.py"""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr


# ── Child registration (by parent) ───────────────────────────────
class ChildCreate(BaseModel):
    name: str
    user_name: str
    nickname: Optional[str] = None  # parent's display name for this child


class ChildResponse(BaseModel):
    id: int
    name: str
    user_name: str
    is_active: bool
    nickname: Optional[str] = None

    model_config = {"from_attributes": True}


# ── Parent registration ───────────────────────────────────────────
class ParentRegister(BaseModel):
    # Parent account
    name: str
    phone_number: str
    # First child (required — you can't be a parent without a child)
    child: ChildCreate


class ParentRegisterResponse(BaseModel):
    parent_id: int
    parent_phone: str
    child: ChildResponse
    access_token: str
    token_type: str = "bearer"
    biometric_token: str


# ── Learning goals ────────────────────────────────────────────────
class LearningGoalUpdate(BaseModel):
    daily_minutes_target: Optional[int] = None
    lessons_per_week: Optional[int] = None
    max_daily_minutes: Optional[int] = None


class LearningGoalResponse(BaseModel):
    daily_minutes_target: int
    lessons_per_week: int
    max_daily_minutes: int
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Screen time ───────────────────────────────────────────────────
class SessionStartRequest(BaseModel):
    child_id: int


class SessionStartResponse(BaseModel):
    session_id: int
    session_start: datetime

    model_config = {"from_attributes": True}


class SessionEndRequest(BaseModel):
    child_id: int
    session_start: datetime  # sent from Flutter


class ScreenTimeTodayResponse(BaseModel):
    minutes_used_today: float
    max_daily_minutes: int
    is_limit_reached: bool
    sessions_today: int


# ── Child progress analytics ──────────────────────────────────────
class PhonemeProgress(BaseModel):
    phoneme_id: int
    symbol: str
    order: int
    is_mastered: bool  # avg pronunciation score >= 80
    avg_score: Optional[float]
    attempts: int


class ChildProgressResponse(BaseModel):
    child_id: int
    child_name: str
    lessons_completed: int
    total_lessons: int
    exercises_completed: int
    total_exercises: int
    avg_pronunciation_score: Optional[float]
    streak_days: int
    minutes_this_week: float
    phoneme_progress: List[PhonemeProgress]
    last_active: Optional[datetime]


# ── Weekly report ─────────────────────────────────────────────────
class WeeklyReportResponse(BaseModel):
    week_start: datetime
    summary_text: str
    phonemes_mastered: List[str]
    phonemes_struggling: List[str]
    avg_pronunciation_score: Optional[float]
    sessions_completed: int
    total_minutes: float
    recommended_focus: Optional[str]
    encouragement_message: Optional[str]
    generated_at: datetime

    model_config = {"from_attributes": True}


# ── Parent dashboard (all children overview) ──────────────────────
class ChildSummary(BaseModel):
    child_id: int
    child_name: str
    nickname: Optional[str]
    lessons_completed: int
    total_lessons: int
    overall_progress_pct: float
    minutes_today: float
    max_daily_minutes: int
    is_limit_reached: bool
    streak_days: int
    last_active: Optional[datetime]


class ParentDashboardResponse(BaseModel):
    parent_name: str
    total_children: int
    children: List[ChildSummary]
