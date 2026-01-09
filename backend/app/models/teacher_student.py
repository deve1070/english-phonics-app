from app.db.base_class import Base
from sqlalchemy import Column, ForeignKey, Integer, Table

teacher_student_association = Table(
    "teacher_student_association",
    Base.metadata,
    Column("teacher_id", Integer, ForeignKey("users.id"), primary_key=True),
    Column("student_id", Integer, ForeignKey("users.id"), primary_key=True),
)
