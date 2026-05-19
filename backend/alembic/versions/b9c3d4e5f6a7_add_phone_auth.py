"""add phone_number to users and create otp invite biometric tables

Revision ID: b9c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-04-19

Idempotent: safe if otp tables were created manually or a previous run failed mid-way.

"""

import sqlalchemy as sa
from alembic import op

revision = "b9c3d4e5f6a7"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def _has_column(inspector, table: str, column: str) -> bool:
    return any(c["name"] == column for c in inspector.get_columns(table))


def _has_index(inspector, table: str, name: str) -> bool:
    return any(ix.get("name") == name for ix in inspector.get_indexes(table))


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)

    # ── users.phone_number ──────────────────────────────────────
    if not _has_column(inspector, "users", "phone_number"):
        op.add_column("users", sa.Column("phone_number", sa.String(20), nullable=True))
        inspector = sa.inspect(conn)

    if not _has_index(inspector, "users", "ix_users_phone_number"):
        op.create_index(
            "ix_users_phone_number", "users", ["phone_number"], unique=True
        )
        inspector = sa.inspect(conn)

    # Phone-primary accounts: email no longer required at DB level
    op.execute(
        sa.text("ALTER TABLE users ALTER COLUMN email DROP NOT NULL")
    )

    # ── OTP records table ───────────────────────────────────────
    if not inspector.has_table("otp_records"):
        op.create_table(
            "otp_records",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("phone_number", sa.String(20), nullable=False),
            sa.Column("otp_hash", sa.String(64), nullable=False),
            sa.Column("attempts", sa.Integer(), nullable=True, default=0),
            sa.Column("is_used", sa.Boolean(), nullable=True, default=False),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=True,
            ),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(
            "ix_otp_records_phone_number",
            "otp_records",
            ["phone_number"],
            unique=False,
        )
        inspector = sa.inspect(conn)

    # ── Invite links table ──────────────────────────────────────
    if not inspector.has_table("invite_links"):
        op.create_table(
            "invite_links",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("parent_id", sa.Integer(), nullable=False),
            sa.Column("child_id", sa.Integer(), nullable=False),
            sa.Column("token", sa.String(512), nullable=False),
            sa.Column("label", sa.String(100), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=True, default=True),
            sa.Column("use_count", sa.Integer(), nullable=True, default=0),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=True,
            ),
            sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["parent_id"], ["users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["child_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("token"),
        )
        op.create_index(
            "ix_invite_links_parent_child",
            "invite_links",
            ["parent_id", "child_id"],
            unique=False,
        )
        inspector = sa.inspect(conn)

    # ── Biometric tokens table ──────────────────────────────────
    if not inspector.has_table("biometric_tokens"):
        op.create_table(
            "biometric_tokens",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("token_hash", sa.String(64), nullable=False),
            sa.Column("device_id", sa.String(200), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=True, default=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=True,
            ),
            sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("token_hash"),
        )
        op.create_index(
            "ix_biometric_tokens_user_id",
            "biometric_tokens",
            ["user_id"],
            unique=False,
        )


def downgrade() -> None:
    op.drop_table("biometric_tokens")
    op.drop_table("invite_links")
    op.drop_table("otp_records")
    op.drop_index("ix_users_phone_number", table_name="users")
    op.drop_column("users", "phone_number")
    op.execute(sa.text("ALTER TABLE users ALTER COLUMN email SET NOT NULL"))
