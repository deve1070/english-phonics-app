from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from app.crud.base import CRUDBase
from app.models.teacher_student import teacher_student_association
from app.schemas.aassociation import AssociationCreate, AssociationResponse


class CRUDAssociation(CRUDBase):
    async def create_association(
        self, db: AsyncSession, *, teacher_id: int, student_id: int
    ):
        stmt = teacher_student_association.insert().values(
            teacher_id=teacher_id, student_id=student_id
        )
        await db.execute(stmt)
        await db.commit()

    async def remove_association(
        self, db: AsyncSession, *, teacher_id: int, student_id: int
    ):
        stmt = delete(teacher_student_association).where(
            teacher_student_association.c.teacher_id == teacher_id,
            teacher_student_association.c.student_id == student_id,
        )
        await db.execute(stmt)
        await db.commit()

    async def get_students_for_teacher(self, db: AsyncSession, *, teacher_id: int):
        from app.models.user import User

        stmt = (
            select(User)
            .where(User.id == teacher_student_association.c.student_id)
            .where(teacher_student_association.c.teacher_id == teacher_id)
        )
        result = await db.execute(stmt)
        return result.scalars().all()

    async def get_teachers_for_student(self, db: AsyncSession, *, student_id: int):
        from app.models.user import User

        stmt = (
            select(User)
            .where(User.id == teacher_student_association.c.teachqer_id)
            .where(teacher_student_association.c.student_id == student_id)
        )
        result = await db.execute(stmt)
        return result.scalars().all()


association_crud = CRUDAssociation(None)
