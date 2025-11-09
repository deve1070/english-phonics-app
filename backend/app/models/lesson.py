from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship

from ..db.base_class import Base


class Lesson(Base):
    __tablename__ = "lessons"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    order = Column(Integer, nullable=False)
    # created_at = Column(datetime, default=datetime.utcnow)
    # updated_at = Column(datetime, default=datetime.utcnow, onupdate=datetime.utcnow)

    exexrcises = relationship("Exercise", back_populates="lesson")
