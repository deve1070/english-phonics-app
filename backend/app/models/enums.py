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
    PHARAGRAPH = "paragraph"


class Level(str, Enum):
    LEVEL1 = "level_1"
    LEVEL2 = "level_2"
    LEVEL3 = "level_3"
    LEVEL4 = "level_4"
    LEVEL5 = "level_5"


class FriendRequestStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


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


class LessonStatus(str, Enum):
    NOT_STARTED = "not_started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"


class NotificationType(str, Enum):
    FRIEND_REQUEST = "friend_request"
    MESSAGE = "message"
    SYSTEM_ALERT = "system_alert"
