"""
app/models/engagement.py
========================
Tables behind the engagement loop: the daily quest, the collectible
awarded for mastering a phoneme, and the streak freeze.

Design decisions worth stating, because each one was a choice:

  - DailyQuest persists the *selection* but not the completion. Whether
    an item is done is derived from PronunciationScore at read time, so
    there is no second source of truth to drift and no write hook in the
    pronunciation path. See services/quest_service.py.

  - PhonemeUnlock records mastery as an event rather than recomputing it
    on every read. Mastery is defined by average score, which can fall
    again after a bad day; a sticker that a child has already been shown
    must never be taken back, so the unlock is written once and kept.

  - StreakFreeze is earned per calendar week and consumed for a specific
    date. Both are stored rather than derived because consumption has to
    be idempotent — the same missed day must not eat two freezes.

Everything here is scoped to a child (a User with role=STUDENT), never
to a parent.
"""

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base import Base
from .enums import GoalKind, QuestSlot, RecognitionMode


class DailyQuest(Base):
    """One child's quest for one UTC day.

    Built on first request of the day and then fixed. Rebuilding it on
    every read would mean the three tasks changed under the child's feet
    as they worked, and "finish today" is the whole point of the feature.
    """

    __tablename__ = "daily_quests"
    __table_args__ = (
        UniqueConstraint("child_id", "quest_date", name="uq_daily_quest_child_date"),
    )

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    quest_date = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime, default=func.now())

    items = relationship(
        "DailyQuestItem",
        back_populates="quest",
        cascade="all, delete-orphan",
        order_by="DailyQuestItem.id",
    )


class DailyQuestItem(Base):
    """One of the three tasks in a quest.

    No completed flag: see the module docstring.
    """

    __tablename__ = "daily_quest_items"
    __table_args__ = (
        UniqueConstraint("quest_id", "slot", name="uq_quest_item_slot"),
    )

    id = Column(Integer, primary_key=True, index=True)
    quest_id = Column(
        Integer,
        ForeignKey("daily_quests.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    exercise_id = Column(
        Integer, ForeignKey("exercises.id", ondelete="CASCADE"), nullable=False
    )
    slot = Column(
        SQLEnum(QuestSlot, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )

    quest = relationship("DailyQuest", back_populates="items")
    exercise = relationship("Exercise")


class PhonemeUnlock(Base):
    """A collectible the child earned by mastering one phoneme.

    seen_at is nullable so the app can show "you earned something new"
    exactly once. It is the client that marks them seen, because only the
    client knows the celebration actually played.
    """

    __tablename__ = "phoneme_unlocks"
    __table_args__ = (
        UniqueConstraint("child_id", "phoneme_id", name="uq_unlock_child_phoneme"),
    )

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    phoneme_id = Column(
        Integer, ForeignKey("phonemes.id", ondelete="CASCADE"), nullable=False
    )
    unlocked_at = Column(DateTime, default=func.now())
    seen_at = Column(DateTime, nullable=True)

    phoneme = relationship("Phoneme")


class RecognitionAttempt(Base):
    """One answer to "which symbol says this sound?".

    Every attempt is kept, right or wrong, and the wrong ones are the
    valuable half: `chosen_phoneme_id` alongside `phoneme_id` is a
    confusion matrix for this child, built for free. It tells the round
    builder which distractors are worth offering and tells a parent
    something they can act on — "she mixes up /b/ and /d/" rather than
    "82% average".

    Deliberately not merged with PronunciationScore. Recognising a sound
    and being able to say it are different skills; a child can hold the
    mapping long before their mouth is reliable, and averaging the two
    would hide exactly the gap a teacher needs to see. Recognition
    therefore gates no reward that production gates.
    """

    __tablename__ = "recognition_attempts"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # The sound the child was asked to find.
    phoneme_id = Column(
        Integer, ForeignKey("phonemes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # What they picked. Null when the round was abandoned without an answer,
    # which is not a wrong answer and must never be scored as one.
    chosen_phoneme_id = Column(
        Integer, ForeignKey("phonemes.id", ondelete="CASCADE"), nullable=True
    )
    is_correct = Column(Boolean, nullable=False, default=False)
    mode = Column(
        SQLEnum(RecognitionMode, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    # How many symbols were on screen. A correct answer out of two is a
    # coin toss; out of four it is evidence. Stored so the bar for
    # "recognised" can be set on the hard case only.
    option_count = Column(Integer, nullable=False, default=2)
    answered_at = Column(DateTime, default=func.now(), index=True)


class WeeklyGoal(Base):
    """What the child promised themselves this week.

    Stores the promise, not the progress. How far along they are is
    counted from the work itself at read time — practice days, answers in
    the listening game, sounds mastered — so there is no second tally to
    drift and nothing to write on every attempt.

    `target` is stored even though the service can recompute it, because
    it must not move once chosen. A target derived on every read would
    quietly rise as the child got better and the goal would retreat as
    they walked towards it, which is the single cruellest thing this
    feature could do.

    completed_at is written the moment the goal is met and never cleared.
    A prize a child has been shown is theirs; nothing later in the week
    can take it back.

    There is no failed state and no failed_at column. A week that ends
    short simply ends, and the app says nothing about it.
    """

    __tablename__ = "weekly_goals"
    __table_args__ = (
        UniqueConstraint("child_id", "week_start", name="uq_goal_child_week"),
    )

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    week_start = Column(Date, nullable=False, index=True)
    kind = Column(
        SQLEnum(GoalKind, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    target = Column(Integer, nullable=False)
    chosen_at = Column(DateTime, default=func.now())
    completed_at = Column(DateTime, nullable=True)


class WeeklyPromise(Base):
    """What the grown-up promised for the week the child chose.

    Deliberately not a target. The child picks the goal; the parent
    answers it with something real from outside the app — "we'll walk to
    the market on Saturday" — and the app's only job is to carry the
    message and get out of the way. A parent who could set the target
    would turn the whole feature back into homework.

    On rewards. A promise contingent on reading is exactly the pattern
    that can displace a child's own reason for reading with someone
    else's. Three things keep this one on the right side of it: the child
    set the goal, the promise is for the whole week rather than paid out
    per exercise, and the app asks for something the family does together
    rather than something bought. The wording in the parent's form does
    that work; nothing here polices what a family writes, because that is
    not the app's business.

    voice_url is the part that matters most and the part that needed no
    literacy. A parent working long hours records eight seconds in their
    own language, and the child hears their voice at the moment they
    finish — not that evening, not from a notification, but there. Its
    existence is shown to the child from Monday and its contents are
    withheld until the goal is met, the same way a locked story shows its
    title and keeps its text.
    """

    __tablename__ = "weekly_promises"
    __table_args__ = (
        UniqueConstraint("child_id", "week_start", name="uq_promise_child_week"),
    )

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Who made it, kept so the child can be told whose voice this is
    # rather than being handed an anonymous message from the app.
    parent_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    week_start = Column(Date, nullable=False, index=True)

    # In whatever language the family speaks. Never translated, never run
    # through TTS, never rewritten by the app: a promise in a parent's own
    # words is the thing being delivered.
    text = Column(String(200), nullable=True)

    # Path under uploads/, as save_audio_file returns it. Null until the
    # parent records something, which most weeks they will not.
    voice_url = Column(String(255), nullable=True)
    voice_seconds = Column(Float, nullable=True)

    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class StreakFreeze(Base):
    """One earned "missed day doesn't count" token.

    earned_week_start is the Monday of the week it was earned in, and is
    unique per child: that is what caps the award at one per week without
    needing a counter. consumed_for_date is null while the freeze is
    still in hand.
    """

    __tablename__ = "streak_freezes"
    __table_args__ = (
        UniqueConstraint("child_id", "earned_week_start", name="uq_freeze_child_week"),
    )

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    earned_week_start = Column(Date, nullable=False)
    consumed_for_date = Column(Date, nullable=True, index=True)
    created_at = Column(DateTime, default=func.now())


class LearningCursor(Base):
    """Where a child had got to, so the app can put them back there.

    One row per child, overwritten in place: this is a position, not a
    history. What they have finished is already recorded in Progress and
    PronunciationScore, and neither can answer "where were they when they
    stopped" — a list of completed exercises does not distinguish a child
    who closed the app after finishing one from a child who is halfway
    through the next.

    `stage` is a step within a phoneme rather than a phoneme alone. A child
    who has heard the sound and is about to say it has done something, and
    sending them back to hear it again spends the little patience they
    brought. It is stored as text on purpose: the stages belong to the
    Flutter screen and will change as that screen does, and a database
    enum would turn every one of those changes into a migration.

    Written on every step, not on leaving. A children's app is closed by
    the battery, by Android reclaiming memory, or by a parent swiping it
    away mid-sentence — an exit handler is the one path that mostly does
    not run.
    """

    __tablename__ = "learning_cursors"
    __table_args__ = (
        UniqueConstraint("child_id", name="uq_cursor_child"),
    )

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    lesson_id = Column(
        Integer, ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False
    )
    # No FK: a phoneme removed from the curriculum should leave a stale
    # cursor to be ignored, not delete the row and lose the lesson too.
    phoneme_id = Column(Integer, nullable=True)
    stage = Column(String(32), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
