"""
Transaction-related Pydantic schemas
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.transaction import TransactionStatus, ItemCategory
from app.schemas.user import StaffResponse
from app.schemas.store import StoreResponse


class TransactionItemCreate(BaseModel):
    item_name: str = Field(min_length=1, max_length=255)
    item_name_ar: Optional[str] = None
    quantity: Decimal = Field(ge=0, default=1)
    unit_price: Decimal = Field(ge=0)
    total_price: Decimal = Field(ge=0)
    category: ItemCategory = ItemCategory.OTHER


class TransactionItemResponse(BaseModel):
    id: UUID
    transaction_id: UUID
    item_name: str
    item_name_ar: Optional[str] = None
    quantity: Decimal
    unit_price: Decimal
    total_price: Decimal
    category: ItemCategory

    class Config:
        from_attributes = True


class TransactionCreate(BaseModel):
    store_id: Optional[UUID] = None
    store_name: Optional[str] = None
    total_amount: Decimal = Field(ge=0)
    receipt_image_url: Optional[str] = None
    notes: Optional[str] = None
    items: List[TransactionItemCreate] = []


class TransactionResponse(BaseModel):
    id: UUID
    family_id: UUID
    staff_id: UUID
    store_id: Optional[UUID] = None
    total_amount: Decimal
    status: TransactionStatus
    receipt_image_url: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    approved_at: Optional[datetime] = None
    approved_by: Optional[UUID] = None
    
    # Related objects
    items: Optional[List[TransactionItemResponse]] = None
    staff: Optional[StaffResponse] = None
    store: Optional[StoreResponse] = None

    class Config:
        from_attributes = True


class TransactionUpdate(BaseModel):
    status: Optional[TransactionStatus] = None
    notes: Optional[str] = None


class PaginatedTransactions(BaseModel):
    items: List[TransactionResponse]
    total: int
    page: int
    limit: int
    has_more: bool
