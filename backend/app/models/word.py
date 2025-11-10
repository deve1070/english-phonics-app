from sqlalchemy import Column, Integer, String
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base_class import Base
from .enums import Level


class Word(Base):
    __tablename__ = "words"

    id = Column(Integer, primary_key=True, index=True)
    text = Column(String, nullable=False)
    level = Column(SQLEnum(Level), default=Level.LEVEL1)
    phonitc = Column(String)
    audio_url = Column(String)

    phonemes = relationship("WordPhoneme", back_populates="word")
    exercises = relationship("Exercise", back_populates="word")
