from sqlalchemy import Column, ForeignKey, Integer, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base import Base
from .enums import ExerciseType
from .exercise_phoneme import exercise_phoneme


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False, index=True)
    content = Column(Text, nullable=False)
    type = Column(SQLEnum(ExerciseType), default=ExerciseType.WORD)
    difficulty = Column(Integer, default=1)

    # How `content` breaks into the graphemes the curriculum teaches,
    # comma-separated: "ship" is stored as "sh,i,p".
    #
    # Stored rather than derived because a word has one true segmentation
    # and it cannot be recovered from the phoneme table: "ship" is sh·i·p
    # while "mishap" is s·h across a syllable break, and the two look
    # identical to any matcher. Deriving it is what let the old check
    # pass "through" to a child four sounds into the course.
    #
    # Nullable only so the column could be added before it was filled.
    # Content without a segmentation cannot be checked, so the gate
    # treats null as undecodable rather than as permission.
    graphemes = Column(Text, nullable=True)

    lesson = relationship("Lesson", back_populates="exercises")
    scores = relationship("PronunciationScore", back_populates="exercise")
    phonemes = relationship(
        "Phoneme", secondary=exercise_phoneme, back_populates="exercises"
    )
    progress = relationship("Progress", back_populates="exercise")
