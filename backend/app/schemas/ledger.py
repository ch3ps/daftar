"""
Pydantic schemas for the ledger API
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


# MARK: - Store Schemas

class StoreBase(BaseModel):
    name: str
    name_ar: Optional[str] = None
    phone: str
    address: Optional[str] = None
    logo_url: Optional[str] = None


class StoreCreate(BaseModel):
    name: str
    name_ar: Optional[str] = None
    phone: str


class StoreResponse(StoreBase):
    id: UUID
    join_code: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class StoreAuthResponse(BaseModel):
    token: str
    store: StoreResponse


# MARK: - Customer Schemas

class CustomerBase(BaseModel):
    name: str
    name_ar: Optional[str] = None
    phone: str


class CustomerCreate(BaseModel):
    name: str
    name_ar: Optional[str] = None
    phone: str


class CustomerResponse(CustomerBase):
    id: UUID
    created_at: datetime
    
    class Config:
        from_attributes = True


class CustomerAuthResponse(BaseModel):
    token: str
    customer: CustomerResponse


# MARK: - Product Schemas

class ProductResponse(BaseModel):
    id: UUID
    name: str
    name_ar: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    category: Optional[str] = None
    default_price: Optional[Decimal] = None
    
    class Config:
        from_attributes = True


# MARK: - Bill Item Schemas

class BillItemCreate(BaseModel):
    name: str
    name_ar: Optional[str] = None
    quantity: Decimal = Field(default=Decimal("1"))
    unit_price: Decimal
    total_price: Decimal
    product_id: Optional[UUID] = None


class BillItemResponse(BaseModel):
    id: UUID
    name: str
    name_ar: Optional[str] = None
    image_url: Optional[str] = None
    quantity: Decimal
    unit_price: Decimal
    total_price: Decimal
    product: Optional[ProductResponse] = None
    
    class Config:
        from_attributes = True


# MARK: - Bill Schemas

class BillCreate(BaseModel):
    customer_id: UUID
    items: List[BillItemCreate]
    total: Decimal
    receipt_image_url: Optional[str] = None
    notes: Optional[str] = None


class BillUpdate(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None


class BillResponse(BaseModel):
    id: UUID
    store_id: UUID
    customer_id: UUID
    items: List[BillItemResponse]
    total_amount: Decimal
    status: str
    receipt_image_url: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    paid_at: Optional[datetime] = None
    store: Optional[StoreResponse] = None
    customer: Optional[CustomerResponse] = None
    
    class Config:
        from_attributes = True


# MARK: - Ledger Entry Schemas (Store's view of customers)

class LedgerEntryResponse(BaseModel):
    store_id: UUID
    customer_id: UUID
    total_owed: Decimal
    last_activity_at: datetime
    customer: Optional[CustomerResponse] = None
    
    class Config:
        from_attributes = True


# MARK: - Customer Ledger Schemas (Customer's view of stores)

class CustomerLedgerResponse(BaseModel):
    store_id: UUID
    customer_id: UUID
    total_owed: Decimal
    last_activity_at: datetime
    store: Optional[StoreResponse] = None
    
    class Config:
        from_attributes = True


# MARK: - OCR Schemas

class OCRItemResponse(BaseModel):
    name: str
    name_ar: Optional[str] = None
    quantity: Decimal
    unit_price: Decimal
    total_price: Decimal
    matched_product_id: Optional[UUID] = None
    matched_product: Optional[ProductResponse] = None


class OCRResponse(BaseModel):
    store_name: Optional[str] = None
    store_name_ar: Optional[str] = None
    items: List[OCRItemResponse]
    total: Decimal
    confidence: float


# MARK: - Auth Schemas

class LoginRequest(BaseModel):
    phone: str
    code: str


class RegisterRequest(BaseModel):
    name: str
    name_ar: Optional[str] = None
    phone: str
    code: str


class JoinStoreRequest(BaseModel):
    code: str


class AddCustomerRequest(BaseModel):
    name: str
    phone: str


class PendingCountResponse(BaseModel):
    count: int


class UploadResponse(BaseModel):
    url: str


class OCRRequest(BaseModel):
    image_url: str


# MARK: - Handwriting OCR Schemas (Option A)

class HandwritingRequest(BaseModel):
    image_url: str


class HandwritingResponse(BaseModel):
    customer_name: Optional[str] = None
    amount: Optional[Decimal] = None
    raw_text: Optional[str] = None
    confidence: float
