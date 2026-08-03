#!/usr/bin/env python3
"""Walks a parent's promise from written to heard, over real HTTP.

verify_engagement.py drives the service layer, which is right for
anything that needs a child to have practised for three weeks. This one
cannot: the promise crosses two accounts, a multipart upload and an
authorisation boundary, and every one of those is only real over HTTP.
The thing being checked is mostly a negative — that a child cannot hear
the recording before they have earned it, by any route — and a negative
is worth checking against the actual endpoints.

Needs a server running. From backend/:
  uvicorn app.main:app --port 8077
  python scripts/verify_promises.py [http://127.0.0.1:8077/api/v1]
"""

from __future__ import annotations

import asyncio
import sys
import time
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import delete, select  # noqa: E402

from app.db.session import AsyncSessionLocal, engine  # noqa: E402
from app.models.engagement import (  # noqa: E402
    RecognitionAttempt,
    WeeklyGoal,
    WeeklyPromise,
)
from app.models.parent import LearningGoal, ParentChildLink  # noqa: E402
from app.models.user import User  # noqa: E402
from app.utils.audio import delete_audio_file, resolve_stored_audio  # noqa: E402

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8077/api/v1"

results: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> bool:
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n       {detail}" if detail else ""))
    return ok


def _report() -> int:
    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    passed = sum(1 for _, ok, _ in results if ok)
    failed = [n for n, ok, _ in results if not ok]
    print(f"{passed}/{len(results)} passed")
    if failed:
        print("\nFAILED:")
        for name in failed:
            print(f"  - {name}")
    return 1 if failed else 0


# A tiny but genuinely well-formed mp3 frame header. The endpoint only
# stores the bytes, so what matters is that the upload path accepts a
# real file rather than an empty one.
FAKE_MP3 = b"\xff\xfb\x90\x64" + b"\x00" * 2048


def _register(c: httpx.Client) -> tuple[dict, dict, int]:
    stamp = int(time.time() * 1000) % 100000000
    body = {
        "name": "Promise Parent",
        "phone_number": f"+2519{stamp:08d}",
        "child": {
            "name": "Promise Child",
            "user_name": f"promisekid{stamp}",
            "nickname": "Bud",
        },
    }
    reg = c.post(f"{BASE}/parents/register", json=body)
    reg.raise_for_status()
    data = reg.json()
    child_id = data["child"]["id"]
    parent_h = {"Authorization": f"Bearer {data['access_token']}"}

    login = c.post(f"{BASE}/parents/child-login/{child_id}", headers=parent_h)
    login.raise_for_status()
    child_h = {"Authorization": f"Bearer {login.json()['access_token']}"}
    return parent_h, child_h, child_id


def _answer_a_round(c: httpx.Client, child_h: dict) -> int:
    """Play one round of the listening game, correctly."""
    rnd = c.get(f"{BASE}/me/recognition/round", headers=child_h).json()
    answers = [
        {
            "phoneme_id": q["target_phoneme_id"],
            "chosen_phoneme_id": q["target_phoneme_id"],
            "option_count": len(q["options"]),
        }
        for q in rnd["questions"]
    ]
    c.post(
        f"{BASE}/me/recognition/round",
        json={"mode": "explore", "answers": answers},
        headers=child_h,
    )
    return len(answers)


def run() -> None:
    c = httpx.Client(timeout=60)
    parent_h, child_h, child_id = _register(c)
    other_h, _, _ = _register(c)

    # ── The parent looks before the child has chosen ─────────────────
    r = c.get(f"{BASE}/parents/children/{child_id}/promise", headers=parent_h)
    check("a parent can look at a week nobody has done anything with", r.status_code == 200,
          f"status={r.status_code}")
    empty = r.json()
    check("nothing is promised until somebody promises it",
          empty["text"] is None and empty["has_voice"] is False)
    check("and no goal is invented on the child's behalf",
          empty["goal_kind"] is None)

    # ── The child chooses, the parent answers ────────────────────────
    c.post(f"{BASE}/me/goal", json={"kind": "sounds_found"}, headers=child_h)
    r = c.get(f"{BASE}/parents/children/{child_id}/promise", headers=parent_h).json()
    check("the parent sees what the child chose for themselves",
          r["goal_kind"] == "sounds_found" and r["goal_target"] > 0,
          f"{r['goal_kind']} x{r['goal_target']}")

    promise_text = "እሁድ ወደ ፓርኩ አብረን እንሄዳለን"
    r = c.put(
        f"{BASE}/parents/children/{child_id}/promise",
        json={"text": promise_text},
        headers=parent_h,
    )
    check("a promise can be written in the family's own language",
          r.status_code == 200 and r.json()["text"] == promise_text,
          f"status={r.status_code}")

    r = c.put(
        f"{BASE}/parents/children/{child_id}/promise",
        json={"text": promise_text + " ከሰዓት በኋላ"},
        headers=parent_h,
    )
    check("and rewritten on Wednesday without an error",
          r.status_code == 200 and r.json()["text"].endswith("ከሰዓት በኋላ"))

    # ── The recording ────────────────────────────────────────────────
    r = c.post(
        f"{BASE}/parents/children/{child_id}/promise/voice",
        files={"file": ("message.mp3", FAKE_MP3, "audio/mpeg")},
        data={"seconds": "8.4"},
        headers=parent_h,
    )
    check("a parent can record a message", r.status_code == 200,
          f"status={r.status_code} {r.text[:120]}")
    check("and the app knows how long it is",
          r.json()["has_voice"] is True and r.json()["voice_seconds"] == 8.4)

    r = c.get(f"{BASE}/parents/children/{child_id}/promise/voice", headers=parent_h)
    check("the parent can hear their own recording back before it is sent",
          r.status_code == 200 and len(r.content) == len(FAKE_MP3),
          f"status={r.status_code} bytes={len(r.content)}")

    first_take = _stored_voice_path(child_id)

    r = c.post(
        f"{BASE}/parents/children/{child_id}/promise/voice",
        files={"file": ("message.mp3", FAKE_MP3 + b"\x00" * 16, "audio/mpeg")},
        data={"seconds": "6.0"},
        headers=parent_h,
    )
    check("re-recording replaces the first take", r.status_code == 200)

    r = c.get(f"{BASE}/parents/children/{child_id}/promise/voice", headers=parent_h)
    check("and what plays back is the new one",
          r.status_code == 200 and len(r.content) == len(FAKE_MP3) + 16,
          f"bytes={len(r.content)}")
    # The button promised "replaces the last one". A discarded take of a
    # family's voice left on the server would make that untrue, and it is
    # the kind of untrue nobody would ever notice.
    check("and the take it replaced is gone from disk",
          first_take is not None and not first_take.exists(),
          f"still there: {first_take}")

    r = c.post(
        f"{BASE}/parents/children/{child_id}/promise/voice",
        files={"file": ("message.mp3", FAKE_MP3, "audio/mpeg")},
        data={"seconds": "600"},
        headers=parent_h,
    )
    check("a ten-minute recording is refused", r.status_code == 400,
          f"status={r.status_code}")

    # ── What the child may see before finishing ──────────────────────
    goal = c.get(f"{BASE}/me/goal", headers=child_h).json()
    promise = goal.get("promise")
    check("the child is told a promise exists", promise is not None)
    check("and told whose it is",
          promise and promise["parent_name"] == "Promise Parent",
          str(promise and promise["parent_name"]))
    check("and told there is a message waiting", promise and promise["has_voice"] is True)
    check("but the message is sealed until the week is kept",
          promise and promise["voice_url"] is None,
          str(promise and promise["voice_url"]))

    r = c.get(f"{BASE}/me/promise/voice", headers=child_h)
    check("and cannot be reached by asking for it directly", r.status_code == 404,
          f"status={r.status_code}")

    # ── Another family cannot reach any of it ────────────────────────
    r = c.get(f"{BASE}/parents/children/{child_id}/promise", headers=other_h)
    check("someone else's parent cannot read this promise", r.status_code == 404,
          f"status={r.status_code}")
    r = c.get(f"{BASE}/parents/children/{child_id}/promise/voice", headers=other_h)
    check("nor play the recording", r.status_code == 404, f"status={r.status_code}")
    r = c.put(
        f"{BASE}/parents/children/{child_id}/promise",
        json={"text": "not yours"},
        headers=other_h,
    )
    check("nor write over it", r.status_code == 404, f"status={r.status_code}")

    # ── The dashboard tells the parent what is going on ──────────────
    board = c.get(f"{BASE}/parents/dashboard", headers=parent_h).json()
    row = board["children"][0]
    check("the dashboard carries the promise the parent made",
          row["promise_text"] is not None)
    check("and does not claim a week that is not finished",
          row["kept_the_week"] is False)

    # ── The child finishes ───────────────────────────────────────────
    for _ in range(12):
        if c.get(f"{BASE}/me/goal", headers=child_h).json().get("is_complete"):
            break
        _answer_a_round(c, child_h)

    goal = c.get(f"{BASE}/me/goal", headers=child_h).json()
    check("the goal is reached", goal["is_complete"] is True,
          f"{goal['done']}/{goal['target']}")
    promise = goal["promise"]
    check("and the message opens at that moment",
          promise["voice_url"] is not None, str(promise["voice_url"]))

    r = c.get(f"{BASE}/me/promise/voice", headers=child_h)
    check("the child can play their parent's voice",
          r.status_code == 200 and len(r.content) > 0,
          f"status={r.status_code} bytes={len(r.content)}")

    board = c.get(f"{BASE}/parents/dashboard", headers=parent_h).json()
    check("the parent is told on their own home screen that the week was kept",
          board["children"][0]["kept_the_week"] is True,
          "a parent who is not told has been made to break a promise")

    # ── Nothing is taken back ────────────────────────────────────────
    r = c.put(
        f"{BASE}/parents/children/{child_id}/promise",
        json={"text": None},
        headers=parent_h,
    )
    still = c.get(f"{BASE}/me/promise/voice", headers=child_h)
    check("clearing the text does not take back a message already heard",
          still.status_code == 200,
          f"status={still.status_code}")

    return child_id


def _stored_voice_path(child_id: int) -> Path | None:
    """Where this week's recording actually sits, read straight from the row.

    The api deliberately never tells anyone the stored filename, so the
    only way to check that a replaced take was really deleted is to look.
    """

    async def go() -> Path | None:
        async with AsyncSessionLocal() as db:
            url = (
                await db.execute(
                    select(WeeklyPromise.voice_url).where(
                        WeeklyPromise.child_id == child_id
                    )
                )
            ).scalar_one_or_none()
        # The pool holds connections belonging to this loop, and the loop
        # dies with the asyncio.run below. Left in place they are handed
        # to the next run() and fail there instead of here.
        await engine.dispose()
        return resolve_stored_audio(url) if url else None

    return asyncio.run(go())


async def _cleanup(child_id: int) -> None:
    """Remove the probe accounts, including the parents behind them.

    And the audio they uploaded. Deleting the rows alone left a probe
    recording on disk after every run — which is how the app's own
    re-record leak was found, so the script may as well not have it.
    """
    async with AsyncSessionLocal() as db:
        voices = (
            await db.execute(
                select(WeeklyPromise.voice_url).where(
                    WeeklyPromise.child_id == child_id
                )
            )
        ).scalars().all()
    for url in voices:
        if url:
            delete_audio_file(url)

    async with AsyncSessionLocal() as db:
        links = (
            await db.execute(
                delete(ParentChildLink)
                .where(ParentChildLink.child_id == child_id)
                .returning(ParentChildLink.parent_id)
            )
        ).scalars().all()
        for table in (WeeklyPromise, WeeklyGoal, RecognitionAttempt):
            await db.execute(delete(table).where(table.child_id == child_id))
        await db.execute(delete(LearningGoal).where(LearningGoal.child_id == child_id))
        await db.execute(delete(User).where(User.id == child_id))
        for parent_id in links:
            await db.execute(delete(User).where(User.id == parent_id))
        await db.commit()
    print("probe accounts removed")


if __name__ == "__main__":
    child_id = None
    try:
        child_id = run()
    finally:
        if child_id is not None:
            asyncio.run(_cleanup(child_id))
    sys.exit(_report())
