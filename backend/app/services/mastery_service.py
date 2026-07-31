"""
Mastery.
========
One definition of "this child has mastered this sound", used by the
parent dashboard, the collectibles, the daily quest's review slot and the
decodable-story gate.

It was previously inlined in parents.py as `bool(avg and avg >= 80)`.
Four features now depend on it, and they must not disagree: a parent
being told a sound is mastered while the app withholds the sticker for it
is the kind of contradiction that costs trust in the whole report.

The threshold is 80, matching ScoreThresholds.pass on the client, so a
child who consistently passes a sound has mastered it.
"""

from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pronuncation_score import PronunciationScore

MASTERY_THRESHOLD = 80.0

# A single lucky attempt is not mastery. Two is a low bar deliberately:
# this gates a reward, and the cost of awarding slightly early is far
# lower than the cost of a child grinding a sound they have plainly got.
MIN_ATTEMPTS_FOR_MASTERY = 2


def is_mastered(avg_score: float | None, attempts: int) -> bool:
    """The definition. Everything else in the app defers to this."""
    if avg_score is None or attempts < MIN_ATTEMPTS_FOR_MASTERY:
        return False
    return avg_score >= MASTERY_THRESHOLD


@dataclass(frozen=True)
class PhonemeStats:
    phoneme_id: int
    avg_score: float
    attempts: int

    @property
    def mastered(self) -> bool:
        return is_mastered(self.avg_score, self.attempts)


async def phoneme_stats(db: AsyncSession, child_id: int) -> dict[int, PhonemeStats]:
    """Average score and attempt count per phoneme, for phonemes attempted.

    Aggregated in the database rather than by loading every score row:
    a child with months of history has thousands of them, and both the
    dashboard and the quest ask for this on every request.

    Only scores carrying a phoneme_id are counted. Scores from exercises
    not tied to a specific phoneme cannot be attributed to a sound, so
    they contribute to the overall average but never to mastery.
    """
    result = await db.execute(
        select(
            PronunciationScore.phoneme_id,
            func.avg(PronunciationScore.score),
            func.count(PronunciationScore.id),
        )
        .where(
            PronunciationScore.user_id == child_id,
            PronunciationScore.phoneme_id.isnot(None),
        )
        .group_by(PronunciationScore.phoneme_id)
    )
    return {
        phoneme_id: PhonemeStats(
            phoneme_id=phoneme_id, avg_score=float(avg), attempts=int(count)
        )
        for phoneme_id, avg, count in result.all()
    }


async def mastered_phoneme_ids(db: AsyncSession, child_id: int) -> set[int]:
    stats = await phoneme_stats(db, child_id)
    return {pid for pid, s in stats.items() if s.mastered}
