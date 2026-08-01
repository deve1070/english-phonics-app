"""
The recognition track.
======================
"Which symbol says /sh/?" — the other half of phonics, and until now the
half this app never asked about.

Every scored interaction in the app has been production: the child says
something and Azure grades it. That is the hardest rung and the most
exposed one, and it was the only rung. Recognition comes first
developmentally — a child holds the sound-to-symbol mapping long before
their mouth is reliable — and it is where the mapping is actually built.

It is also the only exercise the app can run without a microphone, an
upload, or a call to Azure, which matters on the connections these
children have.

Two modes, forming a ladder:

  EXPLORE  every symbol on screen plays its own true sound when tapped.
           The child can listen around before committing. A search they
           can verify, not a trap.
  CHOOSE   the target plays once; the symbols are silent. Recall.

Only CHOOSE counts towards recognising a sound. See RecognitionMode.

**Every card always plays its own correct sound.** The tempting design —
pair a symbol with the wrong sound and ask the child to spot the imposter
— is one this module deliberately refuses. In most subjects a wrong
option is inert; here it is not. A child who hears /b/ while looking at
"d" has just had that wrong link co-activated, and that is precisely how
b/d confusion gets cemented. The exercise never lies to the child.

This track gates nothing that production gates. No collectible, no story,
no lesson unlock depends on it, because averaging the two skills would
hide exactly the gap a teacher needs to see. What it does earn is the
creature opening its eyes — see collection_service.
"""

import random
from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.curriculum.confusions import confusable_with
from app.models.engagement import RecognitionAttempt
from app.models.enums import RecognitionMode
from app.models.phoneme import Phoneme
from app.models.pronuncation_score import PronunciationScore

# A round is short on purpose. Five questions is roughly ninety seconds,
# which fits inside any screen-time cap a parent is likely to set and,
# more importantly, ends while the child still wants another one.
ROUND_SIZE = 5

# How many symbols go on screen. Two is a coin toss and exists only as a
# way in; four is the real test. The ramp is per-phoneme, so a child works
# up the difficulty on each sound separately rather than being pushed to
# four everywhere the moment they get good at one.
MIN_OPTIONS = 2
MAX_OPTIONS = 4

# Correct CHOOSE answers at full width needed before a sound counts as
# recognised. Three, and they have to be the most recent three: a child
# who got it right last week and wrong twice since has not got it.
RECOGNITION_STREAK = 3

# How much of the curriculum a child who has done nothing yet can be asked
# about. Enough that a first round is five different sounds rather than
# the same pair five times.
STARTER_WINDOW = 8


@dataclass(frozen=True)
class RecognitionQuestion:
    """One question. The target is included so the client can mark the
    answer instantly without a round trip — a six-year-old cannot be left
    waiting on the network to find out whether they were right, and there
    is nothing here worth hiding from a client the child already owns."""

    target: Phoneme
    options: list[Phoneme]
    option_count: int


@dataclass(frozen=True)
class RecognitionStats:
    phoneme_id: int
    asked: int
    correct: int
    recent_correct_streak: int
    hardest_width_passed: int

    @property
    def is_recognised(self) -> bool:
        return (
            self.recent_correct_streak >= RECOGNITION_STREAK
            and self.hardest_width_passed >= MAX_OPTIONS
        )

    @property
    def next_option_count(self) -> int:
        """Widen the field as the child gets steady, never faster than one
        step, and drop back a step after a wrong answer rather than
        leaving them stuck at a width they are failing at."""
        if self.asked == 0:
            return MIN_OPTIONS
        width = max(MIN_OPTIONS, min(self.hardest_width_passed, MAX_OPTIONS))
        if self.recent_correct_streak >= 2 and width < MAX_OPTIONS:
            return width + 1
        if self.recent_correct_streak == 0 and width > MIN_OPTIONS:
            return width - 1
        return width


# ── Reading the child's history ──────────────────────────────────────


async def stats_by_phoneme(
    db: AsyncSession, child_id: int
) -> dict[int, RecognitionStats]:
    """Per-sound recognition history, CHOOSE answers only.

    EXPLORE attempts are recorded but never counted here: getting it right
    with every answer audible proves the child can compare two sounds, not
    that they hold the mapping.
    """
    rows = (
        await db.execute(
            select(RecognitionAttempt)
            .where(
                RecognitionAttempt.child_id == child_id,
                RecognitionAttempt.mode == RecognitionMode.CHOOSE,
                RecognitionAttempt.chosen_phoneme_id.isnot(None),
            )
            .order_by(RecognitionAttempt.answered_at)
        )
    ).scalars().all()

    grouped: dict[int, list[RecognitionAttempt]] = {}
    for row in rows:
        grouped.setdefault(row.phoneme_id, []).append(row)

    stats: dict[int, RecognitionStats] = {}
    for phoneme_id, attempts in grouped.items():
        streak = 0
        for attempt in reversed(attempts):
            if not attempt.is_correct:
                break
            streak += 1
        stats[phoneme_id] = RecognitionStats(
            phoneme_id=phoneme_id,
            asked=len(attempts),
            correct=sum(1 for a in attempts if a.is_correct),
            recent_correct_streak=streak,
            hardest_width_passed=max(
                (a.option_count for a in attempts if a.is_correct), default=0
            ),
        )
    return stats


async def recognised_phoneme_ids(db: AsyncSession, child_id: int) -> set[int]:
    stats = await stats_by_phoneme(db, child_id)
    return {pid for pid, s in stats.items() if s.is_recognised}


async def confusion_counts(
    db: AsyncSession, child_id: int
) -> dict[int, dict[int, int]]:
    """How often this child picked X when the answer was Y.

    The wrong answers are the valuable half of the history. They pick the
    distractors that are worth offering, and they are the one thing in
    this app that can tell a parent something actionable — "he mixes up
    /b/ and /d/" rather than an average.
    """
    rows = (
        await db.execute(
            select(
                RecognitionAttempt.phoneme_id,
                RecognitionAttempt.chosen_phoneme_id,
                func.count(RecognitionAttempt.id),
            )
            .where(
                RecognitionAttempt.child_id == child_id,
                RecognitionAttempt.is_correct.is_(False),
                RecognitionAttempt.chosen_phoneme_id.isnot(None),
            )
            .group_by(
                RecognitionAttempt.phoneme_id, RecognitionAttempt.chosen_phoneme_id
            )
        )
    ).all()

    matrix: dict[int, dict[int, int]] = {}
    for target_id, chosen_id, count in rows:
        matrix.setdefault(target_id, {})[chosen_id] = count
    return matrix


# ── Choosing what to ask ─────────────────────────────────────────────


def _primary_grapheme(phoneme: Phoneme) -> str:
    declared = (phoneme.graphemes or "").split(",")[0].strip().lower()
    return declared


def pick_distractors(
    target: Phoneme,
    pool: list[Phoneme],
    wanted: int,
    *,
    personal_confusions: dict[int, int] | None = None,
    rng: random.Random | None = None,
) -> list[Phoneme]:
    """Choose the wrong answers, hardest first.

    Order of preference:
      1. sounds this child has actually confused with the target before
      2. sounds the curriculum says are confusable with it
      3. neighbours in curriculum order

    The fallback matters as much as the table. A random distractor makes
    the question answerable without consulting the mapping at all, which
    is a question that teaches nothing; a neighbour in curriculum order is
    at least a sound the child met recently and is therefore competing
    with the target in memory.
    """
    rng = rng or random.Random()
    confusions = personal_confusions or {}
    candidates = [p for p in pool if p.id != target.id]
    if not candidates:
        return []

    confusable = set(confusable_with(_primary_grapheme(target)))

    def rank(phoneme: Phoneme) -> tuple[int, int, int]:
        personal = confusions.get(phoneme.id, 0)
        if personal:
            # Most-confused first, so the hardest distractor leads.
            return (0, -personal, abs(phoneme.order - target.order))
        if _primary_grapheme(phoneme) in confusable:
            return (1, 0, abs(phoneme.order - target.order))
        return (2, 0, abs(phoneme.order - target.order))

    ranked = sorted(candidates, key=rank)

    # Take the strongest few, then shuffle within them, so the same three
    # distractors do not appear in the same order every time and the child
    # cannot learn the position instead of the sound.
    chosen = ranked[:wanted]
    rng.shuffle(chosen)
    return chosen


async def _taught_phonemes(db: AsyncSession, child_id: int) -> list[Phoneme]:
    """Sounds this child has met, plus a little of what comes next.

    A recognition question about a sound the child has never seen is not a
    stretch, it is a guess. The window extends slightly past the frontier
    so new sounds get introduced here — recognising a sound is a good way
    to meet it — but not so far that most of the round is unfamiliar.

    The frontier moves on either track. Gating it on speaking alone would
    have made this exercise useless to the child it was built for: one who
    cannot yet say /b/ would have been handed the same two sounds forever
    while their ear ran well ahead of their mouth. It advances on correct
    recognition rather than on questions asked, so it cannot be guessed
    open.
    """
    all_phonemes = (
        await db.execute(select(Phoneme).order_by(Phoneme.order))
    ).scalars().all()
    if not all_phonemes:
        return []

    spoken = (
        await db.execute(
            select(func.max(Phoneme.order))
            .select_from(PronunciationScore)
            .join(Phoneme, Phoneme.id == PronunciationScore.phoneme_id)
            .where(PronunciationScore.user_id == child_id)
        )
    ).scalar()

    heard = (
        await db.execute(
            select(func.max(Phoneme.order))
            .select_from(RecognitionAttempt)
            .join(Phoneme, Phoneme.id == RecognitionAttempt.phoneme_id)
            .where(
                RecognitionAttempt.child_id == child_id,
                RecognitionAttempt.is_correct.is_(True),
            )
        )
    ).scalar()

    frontier = max(spoken or 0, heard or 0) + 2
    window = [p for p in all_phonemes if p.order <= frontier]
    # A brand-new child has done nothing at all, and a frontier of two
    # sounds is not a game — it is /a/ against /b/, over and over, with
    # nothing to find. Open with enough of the curriculum to make a real
    # round.
    if len(window) < STARTER_WINDOW:
        window = list(all_phonemes[:STARTER_WINDOW])
    return window


async def build_round(
    db: AsyncSession,
    child_id: int,
    *,
    mode: RecognitionMode,
    size: int = ROUND_SIZE,
    rng: random.Random | None = None,
) -> list[RecognitionQuestion]:
    """Assemble one short round.

    Targets are weighted towards sounds that are shaky or overdue rather
    than sampled evenly: asking a child about a sound they have had right
    five times running is a question with nothing in it.
    """
    rng = rng or random.Random()
    pool = await _taught_phonemes(db, child_id)
    if len(pool) < MIN_OPTIONS:
        return []

    stats = await stats_by_phoneme(db, child_id)
    matrix = await confusion_counts(db, child_id)
    last_asked = await _last_asked(db, child_id)
    now = datetime.utcnow()

    def priority(phoneme: Phoneme) -> tuple[int, float]:
        stat = stats.get(phoneme.id)
        if stat is None:
            return (0, 0.0)  # never asked — highest priority
        if stat.is_recognised:
            # Still worth revisiting, but only once it has had time to fade.
            due = last_asked.get(phoneme.id, now) + timedelta(days=7)
            return (3, (due - now).total_seconds())
        if stat.recent_correct_streak == 0:
            return (1, 0.0)  # got it wrong last time
        return (2, float(stat.recent_correct_streak))

    ordered = sorted(pool, key=priority)
    # A little jitter over the top of the queue, so two rounds in a row
    # are not identical when the priorities are tied.
    head = ordered[: max(size * 2, size)]
    rng.shuffle(head)
    targets = head[:size]

    questions: list[RecognitionQuestion] = []
    for target in targets:
        stat = stats.get(target.id)
        width = stat.next_option_count if stat else MIN_OPTIONS
        distractors = pick_distractors(
            target,
            pool,
            width - 1,
            personal_confusions=matrix.get(target.id),
            rng=rng,
        )
        if not distractors:
            continue
        options = [target, *distractors]
        rng.shuffle(options)
        questions.append(
            RecognitionQuestion(
                target=target,
                options=options,
                option_count=len(options),
            )
        )
    return questions


async def _last_asked(db: AsyncSession, child_id: int) -> dict[int, datetime]:
    rows = (
        await db.execute(
            select(
                RecognitionAttempt.phoneme_id,
                func.max(RecognitionAttempt.answered_at),
            )
            .where(RecognitionAttempt.child_id == child_id)
            .group_by(RecognitionAttempt.phoneme_id)
        )
    ).all()
    return {pid: when for pid, when in rows if when is not None}


# ── Recording ────────────────────────────────────────────────────────


@dataclass(frozen=True)
class SubmittedAnswer:
    phoneme_id: int
    chosen_phoneme_id: int | None
    mode: RecognitionMode
    option_count: int


async def record_answers(
    db: AsyncSession, child_id: int, answers: list[SubmittedAnswer]
) -> int:
    """Store a whole round in one write.

    Batched rather than one request per question, because the network is
    the weakest part of this app and a child should never lose a finished
    round to a dropped connection mid-way.

    An answer with no choice — the round was abandoned — is stored as an
    attempt but never as a wrong one. A child who put the phone down has
    not confused anything, and counting it would both slander them in the
    parent's report and poison the confusion matrix.
    """
    for answer in answers:
        db.add(
            RecognitionAttempt(
                child_id=child_id,
                phoneme_id=answer.phoneme_id,
                chosen_phoneme_id=answer.chosen_phoneme_id,
                is_correct=answer.chosen_phoneme_id == answer.phoneme_id,
                mode=answer.mode,
                option_count=answer.option_count,
            )
        )
    await db.commit()
    return len(answers)
