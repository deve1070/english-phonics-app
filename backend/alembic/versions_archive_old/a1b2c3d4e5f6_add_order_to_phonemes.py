"""add order column to phonemes

Revision ID: a1b2c3d4e5f6
Revises: 5ea31b4bfded
Create Date: 2026-01-01 00:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "5ea31b4bfded"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "phonemes",
        sa.Column("order", sa.Integer(), nullable=True),
    )
    op.execute('UPDATE phonemes SET "order" = 0 WHERE "order" IS NULL')
    op.alter_column("phonemes", "order", nullable=False)


def downgrade() -> None:
    op.drop_column("phonemes", "order")
