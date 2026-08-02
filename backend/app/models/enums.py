from enum import Enum


class UserRole(str, Enum):
    STUDENT = "student"
    ADMIN = "admin"
    PARENT = "parent"


class StudentLevel(str, Enum):
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"


class ExerciseType(str, Enum):
    WORD = "word"
    SENTENCE = "sentence"
    PHONEME = "phoneme"
    PARAGRAPH = "paragraph"


class Level(str, Enum):
    LEVEL1 = "level_1"
    LEVEL2 = "level_2"
    LEVEL3 = "level_3"
    LEVEL4 = "level_4"
    LEVEL5 = "level_5"


class PhonemeType(str, Enum):
    ALPHABET = "alphabet"
    LONG_VOWEL = "long_vowel"
    SHORT_VOWEL = "short_vowel"
    DIPHTHONG = "diphthong"
    CONSONANT_BLEND = "consonant_blend"
    LETTER_COMBINATION = "letter_combination"
    R_CONTROLLED_VOWEL = "r_controlled_vowel"
    SILENT_LETTER = "silent_letter"
    SCHWA = "schwa"
    SUFFIX = "suffix"


class QuestSlot(str, Enum):
    """The three fixed rungs of a daily quest.

    Ordered deliberately: something already met and shaky, something
    being learnt now, something just past the edge. A quest is always
    these three roles, never three arbitrary exercises — that is what
    makes the review slot double as spaced repetition.
    """

    REVIEW = "review"
    CURRENT = "current"
    STRETCH = "stretch"


class RecognitionMode(str, Enum):
    """How much help the child had when they answered.

    Two rungs of the same ladder, and the distinction has to be recorded
    because a correct answer means very different things on each. In
    EXPLORE the child may tap every card to hear it before committing, so
    the task is a search they can verify. In CHOOSE the target plays once
    and the symbols are silent — that is recall with nothing to lean on.

    Only CHOOSE counts towards recognising a sound. Getting it right with
    the answers audible proves the child can compare, not that they hold
    the mapping.
    """

    EXPLORE = "explore"
    CHOOSE = "choose"


class GoalKind(str, Enum):
    """What a child can promise themselves for one week.

    Three kinds rather than three sizes of one kind, because the choice is
    meant to be about what the child wants to do — "I'll come every day"
    against "I'll wake up two friends" — and not a difficulty slider,
    which only ever invites picking the smallest number.

    Each is sized from that child's own last few weeks, so all three are
    reachable. A goal a child cannot reach teaches the opposite of what
    this feature exists to teach.

    DAYS is the floor and always offered: it asks only for turning up,
    which is the one thing every child can do regardless of how the
    sounds are going. SOUNDS_FOUND runs on the listening game, so it
    survives a bad microphone and a bad connection. SOUNDS_MASTERED is
    the ambitious one and depends on scoring, which is partly out of the
    child's hands — it is offered, never assigned.
    """

    DAYS = "days"
    SOUNDS_FOUND = "sounds_found"
    SOUNDS_MASTERED = "sounds_mastered"


class LessonStatus(str, Enum):
    NOT_STARTED = "not_started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
