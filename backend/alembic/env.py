import os
import sys
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

# Add project root to path first
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Import app modules (now path is set)/fix Simple statements must be separated by newlines or semicolons, Statements must be separated by newlines or semicolons
from app.core.config import config as app_config  # Alias to avoid overwrite
from app.db.base_class import Base
from app.models import *  # Registers all models with Base.metadata

# Alembic Config object
alembic_config = context.config

# load .env so env vars (if any) are available
try:
    from dotenv import load_dotenv

    load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
except Exception:
    # dotenv is optional; continue if not available
    pass

# Choose database URL for Alembic:
# Prefer environment DATABASE_URL, then app_config.DATABASE_URL, then DEV_DATABASE_URL
raw_url = (
    os.getenv("DATABASE_URL")
    or getattr(app_config, "DATABASE_URL", None)
    or getattr(app_config, "DEV_DATABASE_URL", None)
)
if not raw_url:
    raise ValueError("No DATABASE_URL or DEV_DATABASE_URL found for Alembic.")

# Alembic expects a sync SQLAlchemy URL. If an async driver is present (e.g. +asyncpg),
# strip it for Alembic operations.
sync_url = raw_url.replace("+asyncpg", "") if "+asyncpg" in raw_url else raw_url
alembic_config.set_main_option("sqlalchemy.url", sync_url)

# Interpret the config file for Python logging
if alembic_config.config_file_name is not None:
    fileConfig(alembic_config.config_file_name)

# Target metadata for autogenerate
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = alembic_config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    connectable = engine_from_config(
        alembic_config.get_section(alembic_config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata, compare_type=True
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

# The following shell commands were present in the original file but are not valid Python.
# If you need to run them, execute them in a shell (not from this Python module).
# Example shell commands:
#   export DATABASE_URL="${DATABASE_URL:-$DEV_DATABASE_URL}"
#   ./venv/bin/alembic upgrade head
#   ./venv/bin/alembic current
