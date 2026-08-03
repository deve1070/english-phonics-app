"""
The grown-up's half of the week.
================================
The child chooses a goal; a parent may answer it with a promise from the
real world and, if they want, eight seconds of their own voice for the
moment it is met.

The design is mostly a list of things this deliberately does not do:

  1. **The parent cannot set the target.** They write a promise and
     nothing else. A grown-up who could pick the goal turns the feature
     back into homework, and the child's choosing is the whole mechanism.

  2. **The voice is withheld, not hidden.** From Monday the child is told
     a message exists and whose it is. They hear it when they finish.
     Showing the locked thing is what makes it something to work towards;
     hiding it entirely would make it a surprise, which is a different
     and much weaker thing.

  3. **Nothing is retracted.** A promise can be edited up to the moment
     it is earned and is frozen afterwards — a message a child has been
     handed is theirs, and the app will not let a bad Saturday take it
     back.

  4. **A missed week is silent.** No "you didn't get it", no notification
     to the parent that the child fell short, nothing on the child's
     screen naming the promise they did not reach. The promise simply
     goes with the week.

On rewards. Making something a child enjoys contingent on a prize can
displace their reason for doing it with the prize — a real risk here, and
the reason the parent's form asks what the family will *do together*
rather than what the child will *get*. That is a nudge in the wording,
not a rule: what a family promises each other is not this app's business.

Why a voice note at all. The parents this is built for often cannot sit
beside their child at seven in the evening, and some cannot read the
English their child is learning. A recording needs neither. It is the one
feature here that works just as well for a parent who never types a word.
"""

from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.engagement import WeeklyPromise
from app.models.user import User
from app.services.streak_service import week_start
from app.utils.audio import delete_audio_file

# Long enough for a sentence in any language, short enough that a parent
# with a minute between jobs will actually do it. A recording that feels
# like a task to make is one that never gets made.
MAX_VOICE_SECONDS = 30

# Two lines on a phone. The promise has to be readable at a glance by
# someone who is six.
MAX_TEXT_LENGTH = 200


@dataclass(frozen=True)
class ChildPromiseView:
    """What the child is allowed to know about this week's promise.

    Split from the model on purpose. `voice_url` is only ever filled in
    once the goal is met, so the endpoint cannot leak the recording early
    by forgetting a condition — there is one place that decides, and it
    is here.
    """

    text: str | None
    parent_name: str | None
    has_voice: bool
    # Null until the week is kept. The client shows a sealed envelope
    # while this is missing, which is the state that does the work.
    voice_url: str | None

    @property
    def is_empty(self) -> bool:
        return not self.text and not self.has_voice


async def for_week(
    db: AsyncSession, child_id: int, today: date | None = None
) -> WeeklyPromise | None:
    today = today or date.today()
    return (
        await db.execute(
            select(WeeklyPromise).where(
                WeeklyPromise.child_id == child_id,
                WeeklyPromise.week_start == week_start(today),
            )
        )
    ).scalar_one_or_none()


async def set_text(
    db: AsyncSession,
    child_id: int,
    parent_id: int,
    text: str | None,
    today: date | None = None,
) -> WeeklyPromise:
    """Write or rewrite this week's promise.

    Upserts rather than erroring on a second call: a parent correcting a
    typo on Wednesday is the normal case, and there is nothing here worth
    showing them a conflict over.
    """
    today = today or date.today()
    promise = await for_week(db, child_id, today)
    cleaned = (text or "").strip()[:MAX_TEXT_LENGTH] or None

    if promise is None:
        promise = WeeklyPromise(
            child_id=child_id,
            parent_id=parent_id,
            week_start=week_start(today),
            text=cleaned,
        )
        db.add(promise)
    else:
        promise.text = cleaned
        promise.parent_id = parent_id

    await db.commit()
    await db.refresh(promise)
    return promise


async def set_voice(
    db: AsyncSession,
    child_id: int,
    parent_id: int,
    voice_url: str,
    seconds: float | None = None,
    today: date | None = None,
) -> WeeklyPromise:
    """Attach a recording to this week's promise, creating one if needed.

    A parent who records without typing anything has still made a
    promise — for a family that does not share a written language it may
    be the only form of it available — so a promise with no text and a
    voice note is a complete promise, not a half-filled form.

    A take that is replaced is deleted from disk. The button says
    "replaces the last one", and a parent who reads that and re-records
    has asked for the first attempt to be gone — leaving every discarded
    take of a family's voice sitting on a server would make that a lie.
    """
    today = today or date.today()
    promise = await for_week(db, child_id, today)
    replaced = promise.voice_url if promise is not None else None

    if promise is None:
        promise = WeeklyPromise(
            child_id=child_id,
            parent_id=parent_id,
            week_start=week_start(today),
            voice_url=voice_url,
            voice_seconds=seconds,
        )
        db.add(promise)
    else:
        promise.voice_url = voice_url
        promise.voice_seconds = seconds
        promise.parent_id = parent_id

    await db.commit()
    await db.refresh(promise)

    # After the commit, never before: if the write had failed, the row
    # would still point at a file this had already thrown away.
    if replaced and replaced != voice_url:
        delete_audio_file(replaced)

    return promise


async def child_view(
    db: AsyncSession,
    child_id: int,
    is_complete: bool,
    today: date | None = None,
) -> ChildPromiseView | None:
    """This week's promise as the child may see it.

    `is_complete` comes from the goal and is the only thing that opens the
    recording. It is a parameter rather than another query here so that
    the one condition guarding the message is visible in one place.
    """
    promise = await for_week(db, child_id, today)
    if promise is None:
        return None

    parent_name = (
        await db.execute(select(User.name).where(User.id == promise.parent_id))
    ).scalar_one_or_none()

    return ChildPromiseView(
        # Named, always. "Your mum recorded this" is a different thing to
        # a child than a message from the app, and the difference is the
        # entire feature.
        text=promise.text,
        parent_name=parent_name,
        has_voice=promise.voice_url is not None,
        voice_url=promise.voice_url if (is_complete and promise.voice_url) else None,
    )
