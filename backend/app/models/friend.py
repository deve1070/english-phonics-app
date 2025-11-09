from sqlalchemy import Column, Integer, ForeignKey
from sqlalchemy.orm import relationship
from ..db.base_class import Base


class Friend(Base):
    __tablename__ = "friends"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    friend_id = Column(Integer, ForeignKey("users.id"))
