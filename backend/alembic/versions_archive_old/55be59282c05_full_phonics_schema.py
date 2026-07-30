from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "55be59282c05"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # === SAFE DROPS ===
    if "challenges" in inspector.get_table_names():
        op.drop_table("challenges")
    if "friends" in inspector.get_table_names():
        if inspector.get_indexes("friends"):
            op.drop_index(op.f("ix_friends_id"), table_name="friends")
        op.drop_table("friends")

    # === Rest of the migration (safe to run always) ===
    #op.add_column("exercises", sa.Column("difficulty", sa.Integer(), nullable=True))
    op.alter_column(
        "exercises", "lesson_id", existing_type=sa.INTEGER(), nullable=False
    )
    op.alter_column(
        "exercises",
        "type",
        existing_type=postgresql.ENUM(
            "WORD", "SENTENCE", "PHONEME", name="exercisetype"
        ),
        nullable=True,
    )

    # gamification changes
    op.add_column("gamification", sa.Column("name", sa.String(), nullable=False))
    op.add_column("gamification", sa.Column("description", sa.Text(), nullable=True))
    op.add_column(
        "gamification", sa.Column("points_required", sa.Integer(), nullable=True)
    )
    op.add_column("gamification", sa.Column("image_url", sa.String(), nullable=True))
    if inspector.has_table("gamification"):
        op.drop_constraint(
            op.f("gamification_user_id_fkey"), "gamification", type_="foreignkey"
        )
    for col in ("xp", "streak", "last_active", "badges", "user_id"):
        op.drop_column("gamification", col)

    # lessons
    op.add_column(
        "lessons",
        sa.Column(
            "level",
            sa.Enum("LEVEL1", "LEVEL2", "LEVEL3", "LEVEL4", "LEVEL5", name="level"),
            nullable=False,
        ),
    )
    op.add_column("lessons", sa.Column("created_at", sa.DateTime(), nullable=True))
    op.drop_column("lessons", "description")
    op.drop_column("lessons", "title")

    # progress
    op.add_column("progress", sa.Column("exercise_id", sa.Integer(), nullable=True))
    op.add_column("progress", sa.Column("completed", sa.Boolean(), nullable=True))
    op.add_column("progress", sa.Column("score", sa.Float(), nullable=True))
    op.add_column("progress", sa.Column("attempts", sa.Integer(), nullable=True))
    op.add_column("progress", sa.Column("updated_at", sa.DateTime(), nullable=True))
    op.alter_column("progress", "user_id", existing_type=sa.INTEGER(), nullable=False)
    op.alter_column("progress", "lesson_id", existing_type=sa.INTEGER(), nullable=False)
    op.create_foreign_key(None, "progress", "exercises", ["exercise_id"], ["id"])
    for col in ("completed_at", "completed_exercises", "total_exercises"):
        op.drop_column("progress", col)

    # pronunciation_scores
    op.add_column(
        "pronunciation_scores", sa.Column("audio_url", sa.String(), nullable=True)
    )
    op.add_column(
        "pronunciation_scores", sa.Column("timestamp", sa.DateTime(), nullable=True)
    )
    op.alter_column(
        "pronunciation_scores",
        "exercise_id",
        existing_type=sa.INTEGER(),
        nullable=False,
    )
    op.alter_column(
        "pronunciation_scores", "user_id", existing_type=sa.INTEGER(), nullable=False
    )
    op.drop_column("pronunciation_scores", "created_at")
    op.drop_column("pronunciation_scores", "feedback")

    # users
    op.add_column("users", sa.Column("name", sa.String(), nullable=False))
    op.add_column("users", sa.Column("age_group", sa.Integer(), nullable=True))
    op.alter_column(
        "users",
        "role",
        existing_type=sa.VARCHAR(),
        type_=sa.Enum("STUDENT", "TEACHER", "ADMIN", name="userrole"),
        existing_nullable=True,
        postgresql_using="role::text::userrole",
    )
    op.drop_index(op.f("ix_users_username"), table_name="users")
    op.create_index(op.f("ix_users_name"), "users", ["name"], unique=True)
    op.drop_column("users", "username")
