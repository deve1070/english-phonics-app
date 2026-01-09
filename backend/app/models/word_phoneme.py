from sqlalchemy import Column, Integer, ForeignKey, Table
from ..db.base_class import Base

word_phoneme = Table(
    "word_phonemes",
    Base.metadata,
    Column("word_id", Integer, ForeignKey("words.id"), primary_key=True),
    Column("phoneme_id", Integer, ForeignKey("phonemes.id"), primary_key=True),
)
