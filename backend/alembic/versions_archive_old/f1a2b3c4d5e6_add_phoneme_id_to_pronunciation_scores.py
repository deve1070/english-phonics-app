"""add phoneme_id to pronunciation_scores

Revision ID: f1a2b3c4d5e6
Revises: 9e509c5cc896
Create Date: 2026-07-07

Fixes Issue #20: phoneme_id was not being saved on PronunciationScore records,
causing per-phoneme analytics in parents.py _compute_progress_summary to always
show 0 attempts for every phoneme. This column is nullable so existing rows and
exercise-level scores with no single phoneme association remain valid.
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'f1a2b3c4d5e6'
down_revision = '9e509c5cc896'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'pronunciation_scores',
        sa.Column('phoneme_id', sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        'fk_pronunciation_scores_phoneme_id',
        'pronunciation_scores',
        'phonemes',
        ['phoneme_id'],
        ['id'],
        ondelete='SET NULL',
    )
    op.create_index(
        'ix_pronunciation_scores_phoneme_id',
        'pronunciation_scores',
        ['phoneme_id'],
    )


def downgrade() -> None:
    op.drop_index('ix_pronunciation_scores_phoneme_id', table_name='pronunciation_scores')
    op.drop_constraint(
        'fk_pronunciation_scores_phoneme_id',
        'pronunciation_scores',
        type_='foreignkey',
    )
    op.drop_column('pronunciation_scores', 'phoneme_id')
