"""
Transaction API endpoints
"""
from datetime import datetime
from typing import Annotated, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User, Staff
from app.models.transaction import Transaction, TransactionItem, TransactionStatus
from app.api.auth import get_current_user
from app.api.families import get_user_family
from app.schemas.transaction import (
    TransactionCreate,
    TransactionResponse,
    TransactionUpdate,
    PaginatedTransactions,
)


router = APIRouter()


@router.get("", response_model=PaginatedTransactions)
async def list_transactions(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: Optional[TransactionStatus] = None,
    store_id: Optional[UUID] = None,
    staff_id: Optional[UUID] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
):
    """List transactions with filtering and pagination"""
    family = await get_user_family(current_user, db)
    
    # Build query
    query = select(Transaction).where(Transaction.family_id == family.id)
    count_query = select(func.count(Transaction.id)).where(
        Transaction.family_id == family.id
    )
    
    # Apply filters
    if status:
        query = query.where(Transaction.status == status)
        count_query = count_query.where(Transaction.status == status)
    if store_id:
        query = query.where(Transaction.store_id == store_id)
        count_query = count_query.where(Transaction.store_id == store_id)
    if staff_id:
        query = query.where(Transaction.staff_id == staff_id)
        count_query = count_query.where(Transaction.staff_id == staff_id)
    if start_date:
        query = query.where(Transaction.created_at >= start_date)
        count_query = count_query.where(Transaction.created_at >= start_date)
    if end_date:
        query = query.where(Transaction.created_at <= end_date)
        count_query = count_query.where(Transaction.created_at <= end_date)
    
    # Get total count
    result = await db.execute(count_query)
    total = result.scalar() or 0
    
    # Apply pagination and ordering
    offset = (page - 1) * limit
    query = (
        query
        .options(
            selectinload(Transaction.staff),
            selectinload(Transaction.store),
            selectinload(Transaction.items),
        )
        .order_by(Transaction.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    
    result = await db.execute(query)
    transactions = result.scalars().all()
    
    return PaginatedTransactions(
        items=[TransactionResponse.model_validate(t) for t in transactions],
        total=total,
        page=page,
        limit=limit,
        has_more=offset + len(transactions) < total,
    )


@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    request: TransactionCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Create a new transaction (staff only)"""
    # Get staff profile
    result = await db.execute(
        select(Staff).where(Staff.user_id == current_user.id)
    )
    staff = result.scalar_one_or_none()
    
    if not staff:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only staff members can create transactions",
        )
    
    if not staff.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff member is not active",
        )
    
    # Check spending limit
    if staff.spending_limit and request.total_amount > staff.spending_limit:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Amount exceeds spending limit of {staff.spending_limit}",
        )
    
    # Create transaction
    transaction = Transaction(
        family_id=staff.family_id,
        staff_id=staff.id,
        store_id=request.store_id,
        total_amount=request.total_amount,
        receipt_image_url=request.receipt_image_url,
        notes=request.notes,
        status=TransactionStatus.PENDING,
    )
    db.add(transaction)
    await db.flush()
    
    # Create transaction items
    for item_data in request.items:
        item = TransactionItem(
            transaction_id=transaction.id,
            item_name=item_data.item_name,
            item_name_ar=item_data.item_name_ar,
            quantity=item_data.quantity,
            unit_price=item_data.unit_price,
            total_price=item_data.total_price,
            category=item_data.category,
        )
        db.add(item)
    
    await db.commit()
    
    # Reload with relationships
    result = await db.execute(
        select(Transaction)
        .where(Transaction.id == transaction.id)
        .options(
            selectinload(Transaction.staff),
            selectinload(Transaction.store),
            selectinload(Transaction.items),
        )
    )
    transaction = result.scalar_one()
    
    # TODO: Send push notification to family
    
    return TransactionResponse.model_validate(transaction)


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get transaction details"""
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(Transaction)
        .where(
            Transaction.id == transaction_id,
            Transaction.family_id == family.id,
        )
        .options(
            selectinload(Transaction.staff),
            selectinload(Transaction.store),
            selectinload(Transaction.items),
        )
    )
    transaction = result.scalar_one_or_none()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )
    
    return TransactionResponse.model_validate(transaction)


@router.patch("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: UUID,
    update: TransactionUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Update transaction status (approve/flag/reject)"""
    from app.api.auth import get_current_family_user
    
    # Only family users can update status
    if current_user.role.value != "family":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family managers can update transaction status",
        )
    
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(Transaction)
        .where(
            Transaction.id == transaction_id,
            Transaction.family_id == family.id,
        )
        .options(
            selectinload(Transaction.staff),
            selectinload(Transaction.store),
            selectinload(Transaction.items),
        )
    )
    transaction = result.scalar_one_or_none()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )
    
    # Update fields
    if update.status:
        transaction.status = update.status
        if update.status == TransactionStatus.APPROVED:
            transaction.approved_at = datetime.utcnow()
            transaction.approved_by = current_user.id
    if update.notes is not None:
        transaction.notes = update.notes
    
    await db.commit()
    await db.refresh(transaction)
    
    # TODO: Send push notification to staff
    
    return TransactionResponse.model_validate(transaction)
