from typing import Optional

from pydantic import BaseModel

from ..models.enums import ExerciseType


class ExerciseBase(BaseModel):
    content: str
    type: ExerciseType = ExerciseType.WORD
    difficulty: int = 1


class ExerciseCreate(ExerciseBase):
    lesson_id: int


class ExerciseUpdate(BaseModel):
    content: Optional[str] = None
    type: Optional[ExerciseType] = None
    difficulty: Optional[int] = None


class ExerciseResponse(ExerciseBase):
    id: int
    lesson_id: int

    model_config = {"from_attributes": True}
