"""
Transaction models
"""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional, List

from sqlalchemy import String, ForeignKey, Numeric, Text, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum

from app.database import Base


class TransactionStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    FLAGGED = "flagged"
    REJECTED = "rejected"


class ItemCategory(str, enum.Enum):
    PRODUCE = "produce"
    DAIRY = "dairy"
    MEAT = "meat"
    BAKERY = "bakery"
    BEVERAGES = "beverages"
    HOUSEHOLD = "household"
    PERSONAL_CARE = "personal_care"
    OTHER = "other"


class Transaction(Base):
    """Transaction model"""
    __tablename__ = "transactions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    family_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("families.id"), index=True
    )
    staff_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("staff.id"), index=True
    )
    store_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("stores.id"), index=True
    )
    total_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    status: Mapped[TransactionStatus] = mapped_column(
        SQLEnum(TransactionStatus), default=TransactionStatus.PENDING
    )
    receipt_image_url: Mapped[Optional[str]] = mapped_column(String(512))
    notes: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow, index=True)
    approved_at: Mapped[Optional[datetime]] = mapped_column()
    approved_by: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True))

    # Relationships
    family: Mapped["Family"] = relationship(
        back_populates="transactions", foreign_keys=[family_id]
    )
    staff: Mapped["Staff"] = relationship(
        back_populates="transactions", foreign_keys=[staff_id]
    )
    store: Mapped[Optional["Store"]] = relationship(
        back_populates="transactions", foreign_keys=[store_id]
    )
    items: Mapped[List["TransactionItem"]] = relationship(
        back_populates="transaction", cascade="all, delete-orphan"
    )


class TransactionItem(Base):
    """Transaction item model"""
    __tablename__ = "transaction_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("transactions.id"), index=True
    )
    item_name: Mapped[str] = mapped_column(String(255))
    item_name_ar: Mapped[Optional[str]] = mapped_column(String(255))
    quantity: Mapped[Decimal] = mapped_column(Numeric(10, 3), default=1)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    total_price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    category: Mapped[ItemCategory] = mapped_column(
        SQLEnum(ItemCategory), default=ItemCategory.OTHER
    )

    # Relationships
    transaction: Mapped["Transaction"] = relationship(
        back_populates="items", foreign_keys=[transaction_id]
    )


# Import for type hints
from app.models.user import Family, Staff
from app.models.store import Store
