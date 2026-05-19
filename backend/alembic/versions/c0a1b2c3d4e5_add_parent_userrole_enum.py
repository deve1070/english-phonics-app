"""Add parent label to PostgreSQL userrole enum

Revision ID: c0a1b2c3d4e5
Revises: b9c3d4e5f6a7
Create Date: 2026-05-07

"""

from alembic import op
from sqlalchemy import text

revision = "c0a1b2c3d4e5"
down_revision = "b9c3d4e5f6a7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    exists = conn.execute(
        text(
            """
            SELECT EXISTS (
                SELECT 1
                FROM pg_enum e
                JOIN pg_type t ON e.enumtypid = t.oid
                WHERE t.typname = 'userrole' AND e.enumlabel = 'parent'
            )
            """
        )
    ).scalar()
    if not exists:
        op.execute(text("ALTER TYPE userrole ADD VALUE 'parent'"))


def downgrade() -> None:
    # PostgreSQL does not support dropping a single enum value safely.
    pass
