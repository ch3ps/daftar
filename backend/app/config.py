"""
Application configuration - Production Ready
"""
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = False

    # Database (Supabase PostgreSQL URL)
    DATABASE_URL: str = "sqlite+aiosqlite:///./daftar.db"

    # JWT Authentication
    JWT_SECRET_KEY: str = "dev-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7   # 7 days
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # OpenAI (for OCR / handwriting recognition)
    OPENAI_API_KEY: Optional[str] = None

    # Firebase (push notifications + file storage)
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None
    FIREBASE_CREDENTIALS_JSON: Optional[str] = None
    FIREBASE_STORAGE_BUCKET: Optional[str] = None   # e.g. my-project.appspot.com

    # SMS - Unifonic (GCC / Qatar)
    UNIFONIC_APP_SID: Optional[str] = None
    UNIFONIC_SENDER_ID: str = "DAFTAR"

    # OTP Settings
    OTP_LENGTH: int = 6
    OTP_EXPIRY_MINUTES: int = 5
    OTP_MAX_ATTEMPTS: int = 3

    # Rate Limiting
    RATE_LIMIT_AUTH: str = "5/minute"
    RATE_LIMIT_API: str = "100/minute"
    RATE_LIMIT_OCR: str = "20/minute"

    # CORS (comma-separated origins, or * for all)
    CORS_ORIGINS: str = "*"

    # Server port (Railway injects PORT automatically)
    PORT: int = 8000

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
