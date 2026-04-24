from typing import Optional

from pydantic import BaseModel


class ProgressCreate(BaseModel):
    user_id: int
    lesson_id: int
    exercise_id: Optional[int] = None
    score: float = 0.0
    attempts: int = 1
    completed: bool = False


class ProgressUpdate(BaseModel):
    score: Optional[float] = None
    attempts: Optional[int] = None
    completed: Optional[bool] = None


class ProgressResponse(BaseModel):
    id: int
    user_id: int
    lesson_id: int
    exercise_id: Optional[int] = None
    score: float
    attempts: int
    completed: bool

    model_config = {"from_attributes": True}
