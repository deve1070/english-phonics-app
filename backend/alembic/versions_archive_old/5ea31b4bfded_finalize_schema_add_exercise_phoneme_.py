"""Finalize schema: add exercise_phoneme, subscriptions, total_points; remove teacher-student and words

Revision ID: 5ea31b4bfded
Revises: 627f9d6cf257
Create Date: 2026-02-15 01:11:01.390707

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "5ea31b4bfded"
down_revision: Union[str, Sequence[str], None] = "627f9d6cf257"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop FK and columns on exercises FIRST so we can drop words
    op.drop_constraint("exercises_word_id_fkey", "exercises", type_="foreignkey")
    op.drop_column("exercises", "audio_url")
    op.drop_column("exercises", "word_id")
    op.create_index(
        op.f("ix_exercises_lesson_id"), "exercises", ["lesson_id"], unique=False
    )

    # Now safe to drop tables that referenced or were referenced by exercises/words
    op.drop_table("word_phonemes")
    op.drop_table("exercise_phonemes")  # Old association
    op.drop_index(op.f("ix_words_id"), table_name="words")
    op.drop_table("words")
    op.drop_table("teacher_student_association")
    op.create_index(
        op.f("ix_friend_requests_receiver_id"),
        "friend_requests",
        ["receiver_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_friend_requests_sender_id"),
        "friend_requests",
        ["sender_id"],
        unique=False,
    )
    op.add_column(
        "gamification",
        sa.Column(
            "created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False
        ),
    )
    op.add_column(
        "phonemes",
        sa.Column(
            "created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False
        ),
    )
    # Change phonemes.type from old enum (consonant/vowel) to new phonemetype
    op.execute(
        "DO $$ BEGIN CREATE TYPE phonemetype AS ENUM ("
        "'ALPHABET','LONG_VOWEL','SHORT_VOWEL','DIPHTHONG','CONSONANT_BLEND',"
        "'LETTER_COMBINATION','R_CONTROLLED_VOWEL','SILENT_LETTER','SCHWA','SUFFIX');"
        " EXCEPTION WHEN duplicate_object THEN NULL; END $$"
    )
    op.execute(
        "ALTER TABLE phonemes ALTER COLUMN type TYPE phonemetype "
        "USING (CASE type::text WHEN 'consonant' THEN 'CONSONANT_BLEND'::phonemetype "
        "WHEN 'vowel' THEN 'SHORT_VOWEL'::phonemetype ELSE 'ALPHABET'::phonemetype END)"
    )
    op.execute("DROP TYPE phoneme_type")
    op.create_index(
        op.f("ix_phonemes_lesson_id"), "phonemes", ["lesson_id"], unique=False
    )
    op.create_index(
        op.f("ix_progress_exercise_id"), "progress", ["exercise_id"], unique=False
    )
    op.create_index(
        op.f("ix_progress_lesson_id"), "progress", ["lesson_id"], unique=False
    )
    op.create_index(op.f("ix_progress_user_id"), "progress", ["user_id"], unique=False)
    op.create_index(
        op.f("ix_pronunciation_scores_exercise_id"),
        "pronunciation_scores",
        ["exercise_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_pronunciation_scores_user_id"),
        "pronunciation_scores",
        ["user_id"],
        unique=False,
    )

    # Fix total_points: non-nullable with default 0
    op.add_column(
        "users",
        sa.Column("total_points", sa.Integer(), server_default="0", nullable=False),
    )
    op.drop_index(op.f("ix_users_name"), table_name="users")
    op.create_index(op.f("ix_users_name"), "users", ["name"], unique=False)

    # ADD MISSING: New exercise_phoneme association table (IF NOT EXISTS: may exist from create_all)
    op.execute(
        "CREATE TABLE IF NOT EXISTS exercise_phoneme ("
        "exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE, "
        "phoneme_id INTEGER NOT NULL REFERENCES phonemes(id) ON DELETE CASCADE, "
        "PRIMARY KEY (exercise_id, phoneme_id))"
    )

    # ADD MISSING: Subscriptions table (mandatory for payment)
    op.execute(
        "CREATE TABLE IF NOT EXISTS subscriptions ("
        "id SERIAL PRIMARY KEY, "
        "user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, "
        "status VARCHAR DEFAULT 'TRIAL' NOT NULL, "
        "stripe_customer_id VARCHAR, "
        "stripe_subscription_id VARCHAR, "
        "current_period_end TIMESTAMP, "
        "created_at TIMESTAMP DEFAULT now() NOT NULL, "
        "updated_at TIMESTAMP DEFAULT now() NOT NULL)"
    )

    # Optional: Clean up UserRole enum (remove 'teacher') – only if old enum exists
    op.execute(
        "DO $$ BEGIN "
        "IF EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid "
        "WHERE t.typname = 'userrole' AND e.enumlabel IN ('teacher', 'TEACHER')) THEN "
        "ALTER TYPE userrole RENAME TO userrole_old; "
        "CREATE TYPE userrole AS ENUM ('student', 'admin'); "
        "ALTER TABLE users ALTER COLUMN role TYPE userrole USING ("
        "CASE role::text WHEN 'teacher' THEN 'student'::userrole WHEN 'TEACHER' THEN 'student'::userrole "
        "WHEN 'STUDENT' THEN 'student'::userrole WHEN 'student' THEN 'student'::userrole "
        "WHEN 'ADMIN' THEN 'admin'::userrole WHEN 'admin' THEN 'admin'::userrole ELSE 'student'::userrole END); "
        "DROP TYPE userrole_old; "
        "END IF; END $$"
    )


def downgrade() -> None:
    # Reverse UserRole enum (optional)
    op.execute("ALTER TYPE userrole RENAME TO userrole_new")
    op.execute("CREATE TYPE userrole AS ENUM ('student', 'teacher', 'admin')")
    op.execute(
        "ALTER TABLE users ALTER COLUMN role TYPE userrole USING role::text::userrole"
    )
    op.execute("DROP TYPE userrole_new")

    # Drop new tables
    op.drop_table("subscriptions")
    op.drop_table("exercise_phoneme")

    # Reverse the rest (keep autogenerated reversals)
    op.drop_index(op.f("ix_users_name"), table_name="users")
    op.create_index(op.f("ix_users_name"), "users", ["name"], unique=True)
    op.drop_column("users", "total_points")
    # ... keep the rest of autogenerated downgrade ...
