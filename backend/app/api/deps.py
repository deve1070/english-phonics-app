from typing import AsyncGenerator

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ..db.session import get_db as get_async_db


async def get_db() -> AsyncGenerator[AsyncSession, None]:
	"""FastAPI dependency that yields an AsyncSession.

	This delegates to the async generator provided by `app.db.session.get_db`.
	Endpoints should import this dependency from `app.api.deps` or call
	`Depends(app.db.session.get_db)` directly.
	"""
	async for session in get_async_db():
		yield session


__all__ = ["get_db"]
