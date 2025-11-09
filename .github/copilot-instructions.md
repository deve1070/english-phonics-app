<!--
Guidance for AI coding agents working on the English Phonics App backend.
Keep this file concise and focused on repository-specific details that help an agent be productive immediately.
-->

# English Phonics App — Copilot Instructions

Short, actionable guidance for automated coding assistants working in this repository.

- Project type: FastAPI backend (async patterns intended) using SQLAlchemy ORM. Code lives under `backend/app`.
- App entry: `backend/app/main.py` — registers `models.api_router` at `/api/v1` and creates DB tables on startup.

Important files to reference
- `backend/app/core/config.py` — pydantic settings; environment-specific classes live here. Use `config` object for PROJECT_NAME and DATABASE_URL.
- `backend/app/db/` — session, base class, and init utilities. Prefer `init_db.py` or the async engine used in `main.py` for migrations.
- `backend/app/models/` — SQLAlchemy models (e.g. `user.py`, `progress.py`). Models are classic Declarative Base classes.
- `backend/app/crud/` — CRUD helpers (example: `crud/users.py`) follow a `CRUDBase` generic pattern.
- `backend/app/schemas/` — Pydantic schemas used for API validation and typing.

Quick runtime & developer commands
- Install backend dependencies (virtualenv recommended) using `pip install -r backend/requirements.txt`.
- Run app locally: `uvicorn app.main:app --reload --port 8000` from `backend/` (or `python -m uvicorn app.main:app --reload`).
- Tests: `pytest` from `backend/` — `pytest` is in requirements.

Project-specific patterns and notes
- DB model base: `backend/app/db/base_class.py` defines `Base = declarative_base()` and models import `Base` from `app.database` or `app.db.base_class`. Prefer `from app.db.base_class import Base`.
- Synchronous vs async: The starters mix synchronous SQLAlchemy Base and async engine/session code. Check `main.py` (uses async engine.begin to run `Base.metadata.create_all`) — maintain consistent async use when modifying sessions.
- Router inclusion: `main.py` expects `models.api_router` to exist. If adding endpoints, register them under `app/api/v1/endpoints` and expose a router object named `api_router` that can be aggregated into `models.api_router` (see existing pattern).

Known issues discovered (avoid these traps)
- Several typos in DB/session and deps modules will cause import/attribute errors. Examples found in repository:
  - `backend/app/db/session.py` uses misspelled names: `sqlachemy`, `AsynchScession`, `AsynchScessionLocal`, `config.DABASE_URL` and returns an empty generator in `get_db()` — fix names to `sqlalchemy`, `AsyncSession`, `AsyncSessionLocal`, and `config.DATABASE_URL`, and `yield session`.
  - `backend/app/api/deps.py` imports `sqlacchemy.orm.Session` (typo) and should import `sqlalchemy.orm.Session` and the async DB getter from `app.db.session`.
  - `backend/app/main.py` imports `app.database.engine` but the codebase exposes `engine` in `app/db/session.py` or `app/db/init_db.py` — use `from app.db.session import engine` or normalize exports.

How to propose fixes safely
- Small fix PRs are preferred. When correcting typos in imports or names, run `pytest` and start uvicorn locally to ensure no regressions.
- Keep changes minimal and update only the modules required to make tests/uvicorn start. Add a short PR description referencing this file when making fixes.

Examples (concrete snippets to follow project patterns)
- Async DB session generator (use this pattern in `app/db/session.py`):

  ```py
  from sqlalchemy.ext.asyncio import AsyncSession
  from sqlalchemy.orm import sessionmaker

  AsyncSessionLocal = sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

  async def get_db():
      async with AsyncSessionLocal() as session:
          yield session
  ```

- Model example reference: `backend/app/models/user.py` uses `relationship("Progress", back_populates="user")`.

If anything in this file is unclear or you'd like more examples (tests, migrations, or endpoint patterns), tell me which area to expand.
