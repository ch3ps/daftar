"""
Database configuration and session management
"""
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


# Ensure Supabase/Postgres URLs include SSL requirement.
def _normalize_database_url(url: str) -> str:
    if url.startswith("postgresql") and "ssl=" not in url and "sslmode=" not in url:
        separator = "&" if "?" in url else "?"
        return f"{url}{separator}ssl=require"
    return url


DATABASE_URL = _normalize_database_url(settings.DATABASE_URL)


# Create async engine
# SQLite doesn't support pool settings, so we configure conditionally
if DATABASE_URL.startswith("sqlite"):
    engine = create_async_engine(
        DATABASE_URL,
        echo=False,
        connect_args={"check_same_thread": False}
    )
else:
    engine = create_async_engine(
        DATABASE_URL,
        echo=False,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10
    )

# Create session factory
async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)


# Base class for models
class Base(DeclarativeBase):
    pass


# Dependency for FastAPI
async def get_db():
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


# Create all tables (for development)
async def create_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
