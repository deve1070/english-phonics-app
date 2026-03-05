from sqlalchemy import Column, ForeignKey, Integer, Table

from ..db.base import Base

exercise_phoneme = Table(
    "exercise_phoneme",
    Base.metadata,
    Column("exercise_id", Integer, ForeignKey("exercises.id"), primary_key=True),
    Column("phoneme_id", Integer, ForeignKey("phonemes.id"), primary_key=True),
)
