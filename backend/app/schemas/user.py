"""
User-related Pydantic schemas
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from app.models.user import UserRole, StaffRole, AppLanguage, SubscriptionTier


# ============== Auth Schemas ==============

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=1, max_length=255)
    phone: Optional[str] = None
    role: UserRole = UserRole.FAMILY
    language: AppLanguage = AppLanguage.ENGLISH


class AuthResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    user: "UserResponse"


# ============== User Schemas ==============

class UserCreate(BaseModel):
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: str = Field(min_length=8)
    name: str = Field(min_length=1, max_length=255)
    name_ar: Optional[str] = None
    role: UserRole = UserRole.FAMILY
    language: AppLanguage = AppLanguage.ENGLISH


class UserResponse(BaseModel):
    id: UUID
    email: Optional[str] = None
    phone: Optional[str] = None
    name: str
    name_ar: Optional[str] = None
    role: UserRole
    language: AppLanguage
    avatar_url: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    name: Optional[str] = None
    name_ar: Optional[str] = None
    language: Optional[AppLanguage] = None
    avatar_url: Optional[str] = None


# ============== Family Schemas ==============

class FamilyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    name_ar: Optional[str] = None


class FamilyResponse(BaseModel):
    id: UUID
    owner_id: UUID
    name: str
    name_ar: Optional[str] = None
    subscription_tier: SubscriptionTier
    created_at: datetime

    class Config:
        from_attributes = True


class FamilyUpdate(BaseModel):
    name: Optional[str] = None
    name_ar: Optional[str] = None


# ============== Staff Schemas ==============

class StaffCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=255)
    role: StaffRole = StaffRole.OTHER
    spending_limit: Optional[Decimal] = None


class StaffResponse(BaseModel):
    id: UUID
    user_id: UUID
    family_id: UUID
    name: str
    name_ar: Optional[str] = None
    role: StaffRole
    spending_limit: Optional[Decimal] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class StaffUpdate(BaseModel):
    name: Optional[str] = None
    name_ar: Optional[str] = None
    role: Optional[StaffRole] = None
    spending_limit: Optional[Decimal] = None
    is_active: Optional[bool] = None


# Update forward references
AuthResponse.model_rebuild()
