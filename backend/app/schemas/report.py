"""
Report-related Pydantic schemas
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel

from app.models.transaction import ItemCategory
from app.schemas.transaction import TransactionResponse


class CategorySpending(BaseModel):
    category: ItemCategory
    amount: Decimal
    percentage: float
    item_count: int


class StoreSpending(BaseModel):
    store_id: UUID
    store_name: str
    store_name_ar: Optional[str] = None
    amount: Decimal
    percentage: float
    transaction_count: int


class StaffSpending(BaseModel):
    staff_id: UUID
    staff_name: str
    staff_name_ar: Optional[str] = None
    amount: Decimal
    percentage: float
    transaction_count: int


class TopItem(BaseModel):
    item_name: str
    item_name_ar: Optional[str] = None
    total_spent: Decimal
    purchase_count: int
    category: ItemCategory


class MonthlyReportResponse(BaseModel):
    id: UUID
    family_id: UUID
    month: int
    year: int
    total_spending: Decimal
    transaction_count: int
    category_breakdown: List[CategorySpending]
    store_breakdown: List[StoreSpending]
    staff_breakdown: List[StaffSpending]
    top_items: List[TopItem]
    comparison_to_previous_month: Optional[Decimal] = None
    pdf_url: Optional[str] = None
    generated_at: datetime


class DashboardStatsResponse(BaseModel):
    current_month_spending: Decimal
    previous_month_spending: Decimal
    pending_transactions: int
    recent_transactions: List[TransactionResponse]
    top_store: Optional[StoreSpending] = None
    top_category: Optional[CategorySpending] = None
