"""exercises.graphemes — the stored segmentation of an exercise

Adds the column that makes the ordering rule enforceable. Before this,
whether a child could read a piece of content was decided by guessing a
segmentation at request time, which stops discriminating once the child
knows all twenty-six letters — every word segments letter-by-letter from
sound 26 onward.

Nullable, because the rows exist before the values do. Backfilled by
scripts/backfill_exercise_graphemes.py immediately after.

Revision ID: b7c3d91f204e
Revises: 4a5eb442dc7c
Create Date: 2026-08-05

"""

import sqlalchemy as sa
from alembic import op

revision = "b7c3d91f204e"
down_revision = "4a5eb442dc7c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("exercises", sa.Column("graphemes", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("exercises", "graphemes")
