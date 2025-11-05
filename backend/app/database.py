from sqlachemy.ext.asyncio import AsynchScession
from sqlachemy.orm import declarative_base, sessionmaker

from .core.config import config

engine = sqlachemy.create_engine(
    config.DABASE_URL, connect_args={"check_same_thread": False}, echo=True
)


AsynchScessionLocal = sessionmaker(
    bind=engine,
    class_=AsynchScession,
    expire_on_commit=False,
)

Base = declarative_base()


async def get_db():
    async with AsynchScessionLocal() as session:
        yield
