"""
app/services/weekly_report_service.py
=======================================
Generates a personalised AI weekly report for a child using Azure OpenAI.

Called:
  - On-demand when a parent first views the report for the current week
  - By a scheduled background job every Monday at 6am UTC (not implemented
    here — wire this to APScheduler or a cron job)

The report is friendly, encouraging, and written for parents — not teachers.
It avoids technical jargon. It always ends with an actionable suggestion.
"""

import json
from datetime import datetime, timedelta

from app.core.config import settings
from app.models.parent import ScreenTimeLog, WeeklyReport
from app.models.phoneme import Phoneme
from app.models.pronuncation_score import PronunciationScore
from app.models.user import User
from openai import AsyncAzureOpenAI
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


async def generate_weekly_report(
    db: AsyncSession,
    child_id: int,
    week_start: datetime,
) -> WeeklyReport:
    """
    Collect the child's data for the given week and generate an AI report.
    Saves the report to the database and returns it.
    """
    week_end = week_start + timedelta(days=7)

    # ── Collect data ──────────────────────────────────────────────
    child_result = await db.execute(select(User).where(User.id == child_id))
    child = child_result.scalar_one_or_none()
    child_name = child.name if child else "your child"

    # Pronunciation scores this week
    scores_result = await db.execute(
        select(PronunciationScore, Phoneme)
        .join(Phoneme, Phoneme.id == PronunciationScore.phoneme_id, isouter=True)
        .where(
            PronunciationScore.user_id == child_id,
            PronunciationScore.timestamp >= week_start,
            PronunciationScore.timestamp < week_end,
        )
    )
    score_rows = scores_result.all()

    scores_by_phoneme: dict[str, list[float]] = {}
    for score_row, phoneme in score_rows:
        symbol = phoneme.symbol if phoneme else "unknown"
        scores_by_phoneme.setdefault(symbol, []).append(score_row.score)

    # Screen time this week
    screen_result = await db.execute(
        select(ScreenTimeLog).where(
            ScreenTimeLog.child_id == child_id,
            ScreenTimeLog.session_start >= week_start,
            ScreenTimeLog.session_start < week_end,
            ScreenTimeLog.session_end != None,
        )
    )
    screen_logs = screen_result.scalars().all()
    total_minutes = sum(log.duration_mins or 0 for log in screen_logs)
    sessions_completed = len(screen_logs)

    # Mastered vs struggling
    mastered = [
        s
        for s, scores in scores_by_phoneme.items()
        if scores and sum(scores) / len(scores) >= 80
    ]
    struggling = [
        s
        for s, scores in scores_by_phoneme.items()
        if scores and sum(scores) / len(scores) < 60
    ]
    all_scores = [s for scores in scores_by_phoneme.values() for s in scores]
    avg_score = sum(all_scores) / len(all_scores) if all_scores else None

    # Recommended focus: first struggling phoneme, or next unlearned
    recommended_focus = struggling[0] if struggling else None

    # ── AI prompt ─────────────────────────────────────────────────
    data_context = f"""
Child name: {child_name}
Week: {week_start.strftime("%B %d")} - {(week_end - timedelta(days=1)).strftime("%B %d, %Y")}
Sessions completed: {sessions_completed}
Total learning time: {round(total_minutes, 1)} minutes
Average pronunciation score: {round(avg_score, 1) if avg_score else "No attempts this week"}
Phonemes practised and average scores: {json.dumps({k: round(sum(v) / len(v), 1) for k, v in scores_by_phoneme.items()})}
Phonemes mastered (avg >= 80): {mastered}
Phonemes needing work (avg < 60): {struggling}
Recommended focus next week: {recommended_focus or "continue current progress"}
"""

    system_prompt = """You are a friendly children's literacy coach writing a weekly 
progress report for a parent. Write in warm, encouraging language. Avoid technical 
jargon. Never say negative things about the child. Always frame challenges as 
opportunities. The report should feel like a message from a caring teacher, not a 
data dashboard. Write in 3-4 sentences maximum."""

    user_prompt = f"""Based on this week's learning data, write:
1. A 3-4 sentence summary for the parent (what their child did, how they did, one highlight)
2. One specific encouragement message directed at what to tell the child (start with "Tell {child_name}...")
3. One actionable suggestion for the parent for next week (start with "This week, try...")

Data:
{data_context}

Return ONLY valid JSON in this exact format, no other text:
{{
  "summary": "...",
  "encouragement": "...",
  "suggestion": "..."
}}"""

    summary_text = f"{child_name} completed {sessions_completed} learning sessions this week, spending {round(total_minutes, 1)} minutes practising phonics."
    encouragement = (
        f"Tell {child_name} they are doing a wonderful job learning to read!"
    )
    suggestion = "This week, try practising together for 5 minutes before bedtime."

    try:
        client = AsyncAzureOpenAI(
            api_key=settings.AZURE_OPENAI_API_KEY,
            api_version=settings.AZURE_OPENAI_API_VERSION,
            azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
        )
        response = await client.chat.completions.create(
            model=settings.AZURE_OPENAI_DEPLOYMENT,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.7,
            max_tokens=400,
        )
        raw = response.choices[0].message.content or ""
        parsed = json.loads(raw)
        summary_text = parsed.get("summary", summary_text)
        encouragement = parsed.get("encouragement", encouragement)
        suggestion = parsed.get("suggestion", suggestion)
    except Exception:
        # Fallback to template summary if AI fails
        pass

    full_summary = f"{summary_text} {suggestion}"

    # ── Save report ───────────────────────────────────────────────
    report = WeeklyReport(
        child_id=child_id,
        week_start=week_start,
        summary_text=full_summary,
        phonemes_mastered=json.dumps(mastered),
        phonemes_struggling=json.dumps(struggling),
        avg_pronunciation_score=round(avg_score, 1) if avg_score else None,
        sessions_completed=sessions_completed,
        total_minutes=round(total_minutes, 1),
        recommended_focus=recommended_focus,
        encouragement_message=encouragement,
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return report
