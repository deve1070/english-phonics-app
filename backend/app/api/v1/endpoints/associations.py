from app.core.security import get_current_teacher_or_admin
from app.crud.association import association_crud
from app.db.session import get_db
from app.models.user import User
from app.schemas.aassociation import AssociationCreate, AssociationResponse
from app.schemas.user import UserResponse
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/associations", tags=["associations"])


@router.post(
    "/", response_model=AssociationResponse, status_code=status.HTTP_201_CREATED
)
async def create_association(
    obj_in: AssociationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(
        get_current_teacher_or_admin
    ),  # both teacher and admin can create associations
):
    teacher = await User.crud.get_user(db, id=obj_in.teacher_id)
    student = await User.crud.get_user(db, id=obj_in.student_id)
    if not teacher or teacher.role != "TEACHER":
        raise HTTPException(status_code=404, detail="Teacher not found")
    if not student or student.role != "STUDENT":
        raise HTTPException(status_code=404, detail="Student not found")
    await association_crud.create_association(
        db, teacher_id=obj_in.teacher_id, student_id=obj_in.student_id
    )
    return obj_in


@router.delete("/")
async def remove_student_from_teacher(
    teacher_id: int,
    student_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_teacher_or_admin),
):
    await association_crud.remove_association(
        db, teacher_id=teacher_id, student_id=student_id
    )
    return {"detail": "Association removed successfully"}


@router.get("teachers/me/studnets", response_model=list[UserResponse])
async def get_my_students(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_teacher_or_admin),
):
    students = await association_crud.get_students_for_teacher(
        db, teacher_id=current_user.id
    )
    return students


@router.get("students/me/teachers", response_model=list[UserResponse])
async def get_my_teachers(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_teacher_or_admin),
):
    teachers = await association_crud.get_teachers_for_student(
        db, student_id=current_user.id
    )
    return teachers
