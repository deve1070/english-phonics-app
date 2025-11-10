from sqlalchemy import Column, Integer, String, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base_class import Base


class Phoneme(Base):
    __tablename__ = "phonemes"
    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String, unique=True, index=True, nullable=False)
    description = Column(Text)
    audio_url = Column(String)
    type = Column(
        SQLEnum("consonant", "vowel", name="phoneme_type"), default="consonant"
    )

    exercises = relationship(
        "Exercise", secondary="exercise_phonemes", back_populates="phonemes"
    )
    words = relationship("WordPhoneme", back_populates="phoneme")
