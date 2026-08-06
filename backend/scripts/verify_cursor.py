#!/usr/bin/env python3
"""Drives the resume cursor against the live database.

The cursor decides where a child lands when they open the app, so its
failures are all of the same shape: a child sent somewhere wrong, every
launch, with no way back except reinstalling. The cases worth proving are
the ones that only appear against a real database — that the upsert keeps
one row per child however often it is written, that a lesson which does
not exist is refused rather than stored, and that a child who has never
started reads as "no cursor" rather than as an error.

Creates a throwaway child, asserts its way through, and deletes it again.

Usage (from backend/):
  python scripts/verify_cursor.py
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import delete, func, select  # noqa: E402

from app.db.session import AsyncSessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models.engagement import LearningCursor  # noqa: E402
from app.models.lesson import Lesson  # noqa: E402
from app.models.user import User  # noqa: E402

PHONE = "+251900555123"
failures: list[str] = []


def check(label: str, ok: bool, detail: str = "") -> None:
    print(f"  {'ok  ' if ok else 'FAIL'}  {label}")
    if not ok:
        failures.append(f"{label} — {detail}" if detail else label)


async def cleanup() -> None:
    # A Core delete rather than db.delete(user). Every table that points at
    # users is ON DELETE CASCADE, so the database can do this on its own —
    # but the ORM sees the biometric_tokens backref, decides to orphan the
    # rows instead, and tries to null a NOT NULL column. Going round the
    # session lets the constraint do what it was written to do.
    async with AsyncSessionLocal() as db:
        await db.execute(delete(User).where(User.phone_number == PHONE))
        await db.commit()


async def main() -> int:
    await cleanup()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        reg = await c.post(
            "/api/v1/auth/register",
            json={"name": "Cursor Test", "phone_number": PHONE, "role": "STUDENT"},
        )
        if reg.status_code not in (200, 201):
            print(f"could not register a test child: {reg.status_code} {reg.text[:200]}")
            return 1
        token = reg.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        async with AsyncSessionLocal() as db:
            lessons = (
                await db.execute(select(Lesson).order_by(Lesson.order).limit(2))
            ).scalars().all()
        if len(lessons) < 2:
            print("need at least two lessons seeded")
            return 1
        first, second = lessons[0], lessons[1]

        # A child who has never started.
        r = await c.get("/api/v1/me/cursor", headers=headers)
        check(
            "a child who has not started reads as no cursor",
            r.status_code == 200 and r.json() is None,
            f"{r.status_code} {r.text[:120]}",
        )

        # Writing one.
        r = await c.put(
            "/api/v1/me/cursor",
            headers=headers,
            json={"lesson_id": first.id, "phoneme_id": None, "stage": "phonemeIntro"},
        )
        check("a cursor can be written", r.status_code == 200,
              f"{r.status_code} {r.text[:120]}")

        r = await c.get("/api/v1/me/cursor", headers=headers)
        body = r.json() or {}
        check(
            "it reads back exactly as written",
            body.get("lesson_id") == first.id and body.get("stage") == "phonemeIntro",
            str(body),
        )

        # Overwriting, repeatedly. This is the one the app does most.
        for stage in ("gate", "quiz", "exercises"):
            await c.put(
                "/api/v1/me/cursor",
                headers=headers,
                json={"lesson_id": second.id, "phoneme_id": 3, "stage": stage},
            )
        r = await c.get("/api/v1/me/cursor", headers=headers)
        body = r.json() or {}
        check(
            "the latest write wins",
            body.get("lesson_id") == second.id and body.get("stage") == "exercises",
            str(body),
        )

        async with AsyncSessionLocal() as db:
            user = (
                await db.execute(select(User).where(User.phone_number == PHONE))
            ).scalar_one()
            rows = (
                await db.execute(
                    select(func.count())
                    .select_from(LearningCursor)
                    .where(LearningCursor.child_id == user.id)
                )
            ).scalar()
        check("four writes leave one row, not four", rows == 1, f"rows={rows}")

        # A lesson that does not exist must be refused, not stored: this
        # value is what the app navigates to at launch.
        r = await c.put(
            "/api/v1/me/cursor",
            headers=headers,
            json={"lesson_id": 999999, "phoneme_id": None, "stage": "gate"},
        )
        check("a lesson that does not exist is refused", r.status_code == 404,
              f"{r.status_code}")

        r = await c.get("/api/v1/me/cursor", headers=headers)
        body = r.json() or {}
        check(
            "the refused write left the good cursor alone",
            body.get("lesson_id") == second.id,
            str(body),
        )

        # Another child's cursor is not reachable: there is no id in the
        # path, so this is really a check that scoping is by token.
        r = await c.get("/api/v1/me/cursor")
        check("an unauthenticated read is rejected", r.status_code in (401, 403),
              f"{r.status_code}")

    await cleanup()
    await engine.dispose()

    print()
    if failures:
        print(f"{len(failures)} failed:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("all cursor checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
