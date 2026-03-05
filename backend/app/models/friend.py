from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, Table
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import relationship

from ..db.base import Base
from .enums import FriendRequestStatus


class FriendRequest(Base):
    __tablename__ = "friend_requests"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(SQLEnum(FriendRequestStatus), default=FriendRequestStatus.PENDING)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])


friends_association = Table(
    "friends",
    Base.metadata,
    Column("user_id", Integer, ForeignKey("users.id"), primary_key=True),
    Column("friend_id", Integer, ForeignKey("users.id"), primary_key=True),
)
