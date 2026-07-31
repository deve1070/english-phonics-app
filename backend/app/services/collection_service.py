"""
Collectibles.
=============
Every phoneme in the curriculum is a collectible. Mastering the sound
unlocks it; nothing else does. That tie is the whole design: the reward
is not payable by grinding, by returning, or by spending time in the app
— only by getting better at the thing the app teaches. A coin economy
would have been easier and would have rewarded the wrong behaviour.

There is no artwork here and none in the repo. Ninety hand-drawn stickers
is a content project, so the client derives each one procedurally from
the phoneme's id and type — same approach as the mascot. The server's job
is only to say which are earned.

Unlocks are written once and never revoked. An average score can fall
back below the threshold after a bad session, and a child who watched a
sticker appear must not find it gone the next morning.
"""

from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.engagement import PhonemeUnlock
from app.services.mastery_service import mastered_phoneme_ids


async def sync_unlocks(db: AsyncSession, child_id: int) -> list[PhonemeUnlock]:
    """Award collectibles for any newly mastered phonemes.

    Returns every unlock the child has not yet been shown (seen_at is
    null), not just the ones created by this call — otherwise a child who
    masters a sound and closes the app before the celebration plays would
    never see it.

    ON CONFLICT DO NOTHING rather than select-then-insert: two requests
    racing (the home screen and the collection screen both refresh on
    resume) would otherwise both see "not unlocked" and one would fail on
    the unique constraint.
    """
    mastered = await mastered_phoneme_ids(db, child_id)

    if mastered:
        await db.execute(
            pg_insert(PhonemeUnlock)
            .values(
                [
                    {"child_id": child_id, "phoneme_id": pid, "unlocked_at": datetime.utcnow()}
                    for pid in sorted(mastered)
                ]
            )
            .on_conflict_do_nothing(constraint="uq_unlock_child_phoneme")
        )
        await db.commit()

    result = await db.execute(
        select(PhonemeUnlock).where(
            PhonemeUnlock.child_id == child_id,
            PhonemeUnlock.seen_at.is_(None),
        )
    )
    return list(result.scalars().all())


async def all_unlocks(db: AsyncSession, child_id: int) -> dict[int, PhonemeUnlock]:
    result = await db.execute(
        select(PhonemeUnlock).where(PhonemeUnlock.child_id == child_id)
    )
    return {u.phoneme_id: u for u in result.scalars().all()}


async def mark_seen(db: AsyncSession, child_id: int) -> int:
    """Acknowledge every pending unlock. Returns how many were pending.

    Driven by the client rather than by the read, because only the client
    knows whether the celebration actually reached the child — marking
    them seen when the list is fetched would swallow the moment whenever
    a background refresh happened to run first.
    """
    result = await db.execute(
        update(PhonemeUnlock)
        .where(
            PhonemeUnlock.child_id == child_id,
            PhonemeUnlock.seen_at.is_(None),
        )
        .values(seen_at=datetime.utcnow())
    )
    await db.commit()
    return result.rowcount or 0
