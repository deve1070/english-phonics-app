from typing import Optional
from sqlalchemy.orm import Session
from ..models.user import User
from ..schemas import UserCreate, UserUpdate
from .base import CRUDBase


class CRUDUser(CRUDBase[User, UserCreate, UserUpdate]):
    def get_by_email(self, db: Session, *, email: str) -> Optional[User]:
        return db.query(self.model).filter(self.model.email == email).first()


crud = CRUDUser(User)
