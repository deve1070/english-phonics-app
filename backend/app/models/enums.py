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


class LessonStatus(str, Enum):
    NOT_STARTED = "not_started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
