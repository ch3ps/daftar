"""
Store-related Pydantic schemas
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class StoreCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    name_ar: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None


class StoreResponse(BaseModel):
    id: UUID
    name: str
    name_ar: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    code: str
    logo_url: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class StoreSearchResult(BaseModel):
    id: UUID
    name: str
    name_ar: Optional[str] = None
    address: Optional[str] = None
    is_connected: bool = False


class FamilyStoreCreate(BaseModel):
    code: str = Field(min_length=1, max_length=20)


class FamilyStoreResponse(BaseModel):
    family_id: UUID
    store_id: UUID
    balance: Decimal
    connected_at: datetime
    store: Optional[StoreResponse] = None

    class Config:
        from_attributes = True
