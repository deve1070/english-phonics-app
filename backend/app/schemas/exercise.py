from pydantic import BaseModel, ConfigDict

from app.models.enums import ExerciseType


class ExerciseBase(BaseModel):
    lesson_id: int
    content: str
    type: ExerciseType = ExerciseType.WORD
    difficulty: int = 1


class Exercise(ExerciseBase):
    id: int

    model_config = ConfigDict(from_attributes=True)
