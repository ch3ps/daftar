"""
Ledger models - the digital دفتر
"""
import enum
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID, uuid4

from sqlalchemy import (
    Column, String, DateTime, Numeric, ForeignKey, 
    Enum as SQLEnum, Text, Boolean, TypeDecorator, CHAR
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship

from app.database import Base
from app.config import settings


# UUID type that works with both PostgreSQL and SQLite
class GUID(TypeDecorator):
    """Platform-independent GUID type.
    Uses PostgreSQL's UUID type when available, otherwise uses CHAR(36).
    """
    impl = CHAR
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == 'postgresql':
            return dialect.type_descriptor(PGUUID(as_uuid=True))
        else:
            return dialect.type_descriptor(CHAR(36))

    def process_bind_param(self, value, dialect):
        if value is not None:
            if dialect.name == 'postgresql':
                return value
            else:
                if isinstance(value, UUID):
                    return str(value)
                return value
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            if not isinstance(value, UUID):
                return UUID(value)
            return value
        return value


class BillStatus(str, enum.Enum):
    PENDING = "pending"
    PAID = "paid"
    DISPUTED = "disputed"


class Store(Base):
    """Store profile"""
    __tablename__ = "stores"
    
    id = Column(GUID(), primary_key=True, default=uuid4)
    name = Column(String(255), nullable=False)
    name_ar = Column(String(255))
    phone = Column(String(20), unique=True, nullable=False)
    address = Column(Text)
    logo_url = Column(Text)
    join_code = Column(String(6), unique=True, nullable=False)
    password_hash = Column(String(255))
    push_token = Column(Text)  # FCM device token
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    bills = relationship("Bill", back_populates="store")
    ledger_entries = relationship("LedgerEntry", back_populates="store")


class Customer(Base):
    """Customer profile"""
    __tablename__ = "customers"
    
    id = Column(GUID(), primary_key=True, default=uuid4)
    name = Column(String(255), nullable=False)
    name_ar = Column(String(255))
    phone = Column(String(20), unique=True, nullable=False)
    password_hash = Column(String(255))
    push_token = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    bills = relationship("Bill", back_populates="customer")
    ledger_entries = relationship("LedgerEntry", back_populates="customer")


class LedgerEntry(Base):
    """
    Represents the relationship between a store and customer.
    Tracks the running total owed.
    """
    __tablename__ = "ledger_entries"
    
    store_id = Column(GUID(), ForeignKey("stores.id"), primary_key=True)
    customer_id = Column(GUID(), ForeignKey("customers.id"), primary_key=True)
    total_owed = Column(Numeric(10, 2), default=0)
    last_activity_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    store = relationship("Store", back_populates="ledger_entries")
    customer = relationship("Customer", back_populates="ledger_entries")


class Bill(Base):
    """A bill/transaction in the ledger"""
    __tablename__ = "bills"
    
    id = Column(GUID(), primary_key=True, default=uuid4)
    store_id = Column(GUID(), ForeignKey("stores.id"), nullable=False)
    customer_id = Column(GUID(), ForeignKey("customers.id"), nullable=False)
    total_amount = Column(Numeric(10, 2), nullable=False)
    status = Column(
        SQLEnum(BillStatus, values_callable=lambda e: [x.value for x in e]),
        default=BillStatus.PENDING
    )
    receipt_image_url = Column(Text)
    notes = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    paid_at = Column(DateTime)
    
    # Relationships
    store = relationship("Store", back_populates="bills")
    customer = relationship("Customer", back_populates="bills")
    items = relationship("BillItem", back_populates="bill", cascade="all, delete-orphan")


class Product(Base):
    """Product catalog for matching OCR items"""
    __tablename__ = "products"
    
    id = Column(GUID(), primary_key=True, default=uuid4)
    store_id = Column(GUID(), ForeignKey("stores.id"))
    name = Column(String(255), nullable=False)
    name_ar = Column(String(255))
    description = Column(Text)
    image_url = Column(Text)
    category = Column(String(50))
    default_price = Column(Numeric(10, 2))
    created_at = Column(DateTime, default=datetime.utcnow)


class BillItem(Base):
    """Individual item on a bill"""
    __tablename__ = "bill_items"
    
    id = Column(GUID(), primary_key=True, default=uuid4)
    bill_id = Column(GUID(), ForeignKey("bills.id"), nullable=False)
    product_id = Column(GUID(), ForeignKey("products.id"))
    name = Column(String(255), nullable=False)
    name_ar = Column(String(255))
    image_url = Column(Text)
    quantity = Column(Numeric(10, 3), default=1)
    unit_price = Column(Numeric(10, 2), nullable=False)
    total_price = Column(Numeric(10, 2), nullable=False)
    
    # Relationships
    bill = relationship("Bill", back_populates="items")
    product = relationship("Product")
