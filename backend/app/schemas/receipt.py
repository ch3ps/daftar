"""
Receipt OCR related Pydantic schemas
"""
from decimal import Decimal
from typing import Optional, List

from pydantic import BaseModel

from app.models.transaction import ItemCategory


class OCRItem(BaseModel):
    name: str
    name_ar: Optional[str] = None
    quantity: Decimal = 1
    unit_price: Decimal
    total_price: Decimal
    category: ItemCategory = ItemCategory.OTHER


class OCRRequest(BaseModel):
    image_url: str


class OCRResponse(BaseModel):
    store_name: Optional[str] = None
    store_name_ar: Optional[str] = None
    date: Optional[str] = None
    time: Optional[str] = None
    items: List[OCRItem] = []
    subtotal: Optional[Decimal] = None
    tax: Optional[Decimal] = None
    total: Decimal
    confidence: float = 0.0
    raw_text: Optional[str] = None


class PresignedURLRequest(BaseModel):
    filename: str
    content_type: str = "image/jpeg"


class PresignedURLResponse(BaseModel):
    upload_url: str
    file_url: str
    key: str
