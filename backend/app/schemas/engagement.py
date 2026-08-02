"""Response shapes for the child-facing engagement endpoints."""

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel

from app.models.enums import ExerciseType, GoalKind, QuestSlot, RecognitionMode


class QuestItemResponse(BaseModel):
    slot: QuestSlot
    exercise_id: int
    content: str
    type: ExerciseType
    completed: bool


class QuestResponse(BaseModel):
    quest_date: date
    items: List[QuestItemResponse]
    completed_count: int
    total_count: int
    is_complete: bool


class StreakResponse(BaseModel):
    days: int
    freezes_available: int
    # Dates a freeze is covering. The app says "we saved your streak" on
    # these rather than pretending the child practised.
    frozen_dates: List[date]


class CollectibleResponse(BaseModel):
    phoneme_id: int
    symbol: str
    order: int
    # The client draws each sticker procedurally from these two fields, so
    # ninety collectibles need no artwork and no asset download.
    phoneme_type: str
    is_unlocked: bool
    unlocked_at: Optional[datetime] = None
    is_new: bool = False
    # The recognition track's own reward. The creature opens its eyes when
    # the child can pick this sound out of four, and only turns full colour
    # when they can say it — two visible stages for two separate skills,
    # neither standing in for the other.
    is_recognised: bool = False


class CollectionResponse(BaseModel):
    total: int
    unlocked: int
    items: List[CollectibleResponse]
    # Ids the child has earned but never been shown. The app celebrates
    # these once and then POSTs /collection/seen.
    newly_unlocked: List[int]


class RecognitionOption(BaseModel):
    phoneme_id: int
    symbol: str
    # What the child actually looks at. The symbol may be IPA; the
    # grapheme is the spelling, and the spelling is what has to be learnt.
    grapheme: str
    audio_url: str


class RecognitionQuestionResponse(BaseModel):
    target_phoneme_id: int
    target_audio_url: str
    options: List[RecognitionOption]


class RecognitionRoundResponse(BaseModel):
    mode: RecognitionMode
    questions: List[RecognitionQuestionResponse]


class RecognitionAnswerRequest(BaseModel):
    phoneme_id: int
    # Null when the child left without answering. Recorded, never counted
    # as wrong.
    chosen_phoneme_id: Optional[int] = None
    option_count: int = 2


class RecognitionRoundResult(BaseModel):
    mode: RecognitionMode
    answers: List[RecognitionAnswerRequest]


class RecognitionSummary(BaseModel):
    recorded: int
    # Sounds that crossed into "recognised" because of this round, so the
    # app can show the creature opening its eyes at the moment it happens.
    newly_recognised: List[int]
    total_recognised: int


class GoalOptionResponse(BaseModel):
    kind: GoalKind
    target: int


class EarnedWeekResponse(BaseModel):
    week_start: date
    # What the week was spent on. The prize carries it, so the shelf reads
    # as a run of decisions rather than a row of identical tokens.
    kind: GoalKind


class PromiseResponse(BaseModel):
    """This week's promise as the child may see it."""

    text: Optional[str] = None
    # Whose it is. An anonymous message from the app is not the thing
    # being delivered here.
    parent_name: Optional[str] = None

    # Told from Monday, so the recording is something to work towards
    # rather than a surprise afterwards.
    has_voice: bool = False

    # Filled in only once the goal is met. The server withholds it rather
    # than trusting the client to keep it sealed.
    voice_url: Optional[str] = None


class GoalResponse(BaseModel):
    week_start: date

    # Null until the child has chosen. The client shows `choices` in that
    # case; it never picks one on the child's behalf, and a week with no
    # goal is a perfectly good week.
    kind: Optional[GoalKind] = None
    target: int = 0
    done: int = 0
    is_complete: bool = False

    # Offered only while there is nothing chosen, so a client cannot show
    # a child three tempting alternatives to the promise they made.
    choices: List[GoalOptionResponse] = []

    # Every week this child finished. The client draws one prize per
    # entry, and each week's prize is always the same object — the child
    # can see on Monday exactly which one they are working towards.
    earned_weeks: List[EarnedWeekResponse] = []

    # What a grown-up promised for this week, if anyone did. Null is the
    # ordinary case and draws nothing: a child whose parent has not
    # written anything must never see the space where it would have been.
    promise: Optional[PromiseResponse] = None


class GoalChoiceRequest(BaseModel):
    kind: GoalKind


class PromiseTextRequest(BaseModel):
    # Null clears it. A parent must be able to take back a promise they
    # cannot keep, and doing so quietly is kinder than leaving it there.
    text: Optional[str] = None


class ParentPromiseResponse(BaseModel):
    """The same promise from the parent's side, with nothing withheld.

    Carries the child's goal too, because a parent writing a promise on
    Monday needs to see what their child actually chose — a promise that
    ignores it reads as though nobody was paying attention.
    """

    week_start: date
    text: Optional[str] = None
    has_voice: bool = False
    voice_seconds: Optional[float] = None

    goal_kind: Optional[GoalKind] = None
    goal_target: int = 0
    goal_done: int = 0
    goal_is_complete: bool = False


class StoryResponse(BaseModel):
    exercise_id: int
    title: str
    word_count: int
    is_unlocked: bool
    blocking_phoneme: Optional[str] = None
    # Only sent for stories the child can actually read. Withholding the
    # text of a locked story is deliberate: it keeps a child from
    # struggling through something the app has already judged too hard.
    content: Optional[str] = None


class StoryListResponse(BaseModel):
    total: int
    unlocked: int
    stories: List[StoryResponse]
