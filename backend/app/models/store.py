"""
Store models
"""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional, List

from sqlalchemy import String, ForeignKey, Numeric, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Store(Base):
    """Store model"""
    __tablename__ = "stores"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(255))
    name_ar: Mapped[Optional[str]] = mapped_column(String(255))
    phone: Mapped[Optional[str]] = mapped_column(String(20))
    address: Mapped[Optional[str]] = mapped_column(String(512))
    code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    logo_url: Mapped[Optional[str]] = mapped_column(String(512))
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Relationships
    family_connections: Mapped[List["FamilyStore"]] = relationship(
        back_populates="store", foreign_keys="FamilyStore.store_id"
    )
    transactions: Mapped[List["Transaction"]] = relationship(
        back_populates="store", foreign_keys="Transaction.store_id"
    )


class FamilyStore(Base):
    """Family-Store connection model"""
    __tablename__ = "family_stores"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    family_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("families.id")
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("stores.id")
    )
    balance: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=0)
    connected_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)

    # Unique constraint on family_id and store_id
    __table_args__ = (
        UniqueConstraint("family_id", "store_id", name="uq_family_store"),
    )

    # Relationships
    family: Mapped["Family"] = relationship(
        back_populates="stores", foreign_keys=[family_id]
    )
    store: Mapped["Store"] = relationship(
        back_populates="family_connections", foreign_keys=[store_id]
    )


# Import for type hints
from app.models.user import Family
from app.models.transaction import Transaction
