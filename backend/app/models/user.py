"""
User, Family, and Staff models
"""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional, List

from sqlalchemy import String, Boolean, ForeignKey, Numeric, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum

from app.database import Base


class UserRole(str, enum.Enum):
    FAMILY = "family"
    STAFF = "staff"


class StaffRole(str, enum.Enum):
    DRIVER = "driver"
    HELPER = "helper"
    OTHER = "other"


class AppLanguage(str, enum.Enum):
    ENGLISH = "en"
    ARABIC = "ar"



class SubscriptionTier(str, enum.Enum):
    BASIC = "basic"
    FAMILY = "family"
    PREMIUM = "premium"


class User(Base):
    """User account model"""
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, index=True)
    phone: Mapped[Optional[str]] = mapped_column(String(20), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(255))
    name_ar: Mapped[Optional[str]] = mapped_column(String(255))
    role: Mapped[UserRole] = mapped_column(SQLEnum(UserRole), default=UserRole.FAMILY)
    language: Mapped[AppLanguage] = mapped_column(
        SQLEnum(AppLanguage), default=AppLanguage.ENGLISH
    )
    avatar_url: Mapped[Optional[str]] = mapped_column(String(512))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Relationships
    family: Mapped[Optional["Family"]] = relationship(
        back_populates="owner", foreign_keys="Family.owner_id"
    )
    staff_profile: Mapped[Optional["Staff"]] = relationship(
        back_populates="user", foreign_keys="Staff.user_id"
    )

    # FCM token for push notifications
    fcm_token: Mapped[Optional[str]] = mapped_column(String(512))


class Family(Base):
    """Family account model"""
    __tablename__ = "families"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), unique=True
    )
    name: Mapped[str] = mapped_column(String(255))
    name_ar: Mapped[Optional[str]] = mapped_column(String(255))
    subscription_tier: Mapped[SubscriptionTier] = mapped_column(
        SQLEnum(SubscriptionTier), default=SubscriptionTier.BASIC
    )
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Relationships
    owner: Mapped["User"] = relationship(back_populates="family", foreign_keys=[owner_id])
    staff_members: Mapped[List["Staff"]] = relationship(
        back_populates="family", foreign_keys="Staff.family_id"
    )
    transactions: Mapped[List["Transaction"]] = relationship(
        back_populates="family", foreign_keys="Transaction.family_id"
    )
    stores: Mapped[List["FamilyStore"]] = relationship(
        back_populates="family", foreign_keys="FamilyStore.family_id"
    )


class Staff(Base):
    """Staff member model (linked to a family)"""
    __tablename__ = "staff"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), unique=True
    )
    family_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("families.id")
    )
    name: Mapped[str] = mapped_column(String(255))
    name_ar: Mapped[Optional[str]] = mapped_column(String(255))
    role: Mapped[StaffRole] = mapped_column(SQLEnum(StaffRole), default=StaffRole.OTHER)
    spending_limit: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 2))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Relationships
    user: Mapped["User"] = relationship(back_populates="staff_profile", foreign_keys=[user_id])
    family: Mapped["Family"] = relationship(back_populates="staff_members", foreign_keys=[family_id])
    transactions: Mapped[List["Transaction"]] = relationship(
        back_populates="staff", foreign_keys="Transaction.staff_id"
    )


# Import for type hints
from app.models.transaction import Transaction
from app.models.store import FamilyStore
