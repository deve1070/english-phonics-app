from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base_class import Base
from .enums import Level
from .word_phoneme import word_phoneme


class Word(Base):
    __tablename__ = "words"

    id = Column(Integer, primary_key=True, index=True)
    text = Column(String, nullable=False, unique=True)
    level = Column(SQLEnum(Level), default=Level.LEVEL1)
    phonetic = Column(String, nullable=True)  # fixed earlier typo
    audio_url = Column(String)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), nullable=False)
    phoneme_id = Column(Integer, ForeignKey("phonemes.id"), nullable=False)

    # Many-to-many with Phoneme; mirror attribute name on Phoneme ("words")
    phonemes = relationship("Phoneme", secondary=word_phoneme, back_populates="words")
    exercises = relationship(
        "Exercise",
        back_populates="word",
        foreign_keys="[Exercise.word_id]",
    )
