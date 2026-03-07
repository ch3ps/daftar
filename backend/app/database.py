"""
Database configuration and session management
"""
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


# Ensure Supabase/Postgres URLs include SSL requirement
# and use session-mode pooler (port 5432) instead of transaction-mode (port 6543).
def _normalize_database_url(url: str) -> str:
    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    # Supabase transaction-mode pooler (6543) breaks asyncpg prepared statements;
    # session-mode pooler (5432) works correctly.
    if "pooler.supabase.com:6543" in url:
        url = url.replace("pooler.supabase.com:6543", "pooler.supabase.com:5432")
    if url.startswith("postgresql") and "ssl=" not in url and "sslmode=" not in url:
        separator = "&" if "?" in url else "?"
        return f"{url}{separator}ssl=require"
    return url


DATABASE_URL = _normalize_database_url(settings.DATABASE_URL)

# Supabase pooler (pgBouncer transaction mode) is incompatible with asyncpg
# prepared statement caching. Disable statement cache for reliability.
POSTGRES_CONNECT_ARGS = {
    "statement_cache_size": 0,
    "prepared_statement_cache_size": 0,
}


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
        connect_args=POSTGRES_CONNECT_ARGS,
        pool_pre_ping=True,
        pool_recycle=300,
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
