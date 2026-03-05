from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class AssociationBase(BaseModel):
    teacher_id: int
    student_id: int


class AssociationCreate(AssociationBase):
    pass


class AssociationResponse(AssociationBase):
    id: Optional[int] = None
    created_at: Optional[datetime] = None

    # class Config:
    #     orm_mode = True
    model_config = ConfigDict(from_attributes=True)
