# seed_test_users.py
# Run this script in your backend directory with: python seed_test_users.py
# It creates 5 STUDENT users and 5 ADMIN users with password "testpassword123"
# Emails: student1@test.com ... student5@test.com and admin1@test.com ... admin5@test.com
# Names: Test Student 1 ... and Test Admin 1 ...
# This uses the app's own user creation logic (proper password hashing with Argon2, auto user_name, etc.)

import asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import AsyncSessionLocal
from app.crud import user as crud_user
from app.schemas.user import UserCreate
from app.models.enums import UserRole


async def seed_users():
    async with AsyncSessionLocal() as db:  # type: AsyncSession
        # Common password for easy testing
        password = "testpassword123"

        # Create 5 STUDENTS
        for i in range(1, 6):
            student_in = UserCreate(
                name=f"Test Student {i}",
                email=f"student{i}@test.com",
                password=password,
                role=UserRole.STUDENT,  # Or "student" if schema accepts string
                age_group=8 + i,        # Optional example data
                grade_level=i,          # Optional
                school_name="Test School",
                city="Test City",
                country="Test Country",
            )
            try:
                student = await crud_user.create_user(db=db, obj_in=student_in)
                print(f"Created STUDENT: {student.email} (ID: {student.id})")
            except Exception as e:
                print(f"Failed to create student{i}@test.com: {e}")

        # Create 5 ADMINS
        for i in range(1, 6):
            admin_in = UserCreate(
                name=f"Test Admin {i}",
                email=f"admin{i}@test.com",
                password=password,
                role=UserRole.ADMIN,
                age_group=0,  # schema requires int
            )
            try:
                admin = await crud_user.create_user(db=db, obj_in=admin_in)
                print(f"Created ADMIN: {admin.email} (ID: {admin.id})")
            except Exception as e:
                print(f"Failed to create admin{i}@test.com: {e}")

    print("Seeding complete!")


if __name__ == "__main__":
    asyncio.run(seed_users())