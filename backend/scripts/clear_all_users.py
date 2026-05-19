#!/usr/bin/env python3
"""
Remove every row from `users` and all tables that reference it.

Lessons, phonemes, exercises, and other curriculum data are kept.

Usage (from backend/, with venv active):
  python scripts/clear_all_users.py --yes

Requires DATABASE_URL in the environment (.env loaded via app settings).
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import text

from app.db.session import AsyncSessionLocal


async def clear_users(*, clear_otp: bool) -> None:
    async with AsyncSessionLocal() as db:
        # CASCADE truncates dependent tables (progress, scores, friends, etc.)
        await db.execute(text("TRUNCATE TABLE users RESTART IDENTITY CASCADE"))
        if clear_otp:
            await db.execute(text("TRUNCATE TABLE otp_records RESTART IDENTITY CASCADE"))
        await db.commit()


def main() -> None:
    parser = argparse.ArgumentParser(description="Delete all users and linked rows.")
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Required to actually run (safety guard).",
    )
    parser.add_argument(
        "--keep-otp",
        action="store_true",
        help="Do not truncate otp_records (phone verification rows).",
    )
    args = parser.parse_args()
    if not args.yes:
        print("Refusing to run without --yes (this deletes all accounts).")
        sys.exit(1)

    asyncio.run(clear_users(clear_otp=not args.keep_otp))
    print("All users and dependent data removed.")
    if not args.keep_otp:
        print("otp_records truncated.")


if __name__ == "__main__":
    main()
