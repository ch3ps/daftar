"""
Family management API endpoints
"""
from typing import Annotated, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User, Family, Staff
from app.models.store import FamilyStore
from app.api.auth import get_current_user, get_current_family_user
from app.schemas.user import FamilyResponse, FamilyUpdate, StaffResponse
from app.schemas.store import FamilyStoreResponse, FamilyStoreCreate
from app.schemas.report import DashboardStatsResponse


router = APIRouter()


async def get_user_family(
    user: User,
    db: AsyncSession,
) -> Family:
    """Get the family for a user (either as owner or staff)"""
    if user.role.value == "family":
        result = await db.execute(
            select(Family).where(Family.owner_id == user.id)
        )
        family = result.scalar_one_or_none()
    else:
        result = await db.execute(
            select(Staff).where(Staff.user_id == user.id)
        )
        staff = result.scalar_one_or_none()
        if not staff:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Staff profile not found",
            )
        result = await db.execute(
            select(Family).where(Family.id == staff.family_id)
        )
        family = result.scalar_one_or_none()
    
    if not family:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Family not found",
        )
    return family


@router.get("/me", response_model=FamilyResponse)
async def get_my_family(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get current user's family"""
    family = await get_user_family(current_user, db)
    return FamilyResponse.model_validate(family)


@router.patch("/me", response_model=FamilyResponse)
async def update_my_family(
    update: FamilyUpdate,
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Update family details (family owner only)"""
    family = await get_user_family(current_user, db)
    
    update_data = update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(family, field, value)
    
    await db.commit()
    await db.refresh(family)
    
    return FamilyResponse.model_validate(family)


@router.get("/me/staff", response_model=List[StaffResponse])
async def get_family_staff(
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get all staff members in family"""
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(Staff).where(Staff.family_id == family.id)
    )
    staff_list = result.scalars().all()
    
    return [StaffResponse.model_validate(s) for s in staff_list]


@router.get("/me/stores", response_model=List[FamilyStoreResponse])
async def get_family_stores(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get all connected stores for family"""
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(FamilyStore)
        .where(FamilyStore.family_id == family.id)
        .options(selectinload(FamilyStore.store))
    )
    family_stores = result.scalars().all()
    
    return [FamilyStoreResponse.model_validate(fs) for fs in family_stores]


@router.post("/me/stores", response_model=FamilyStoreResponse, status_code=status.HTTP_201_CREATED)
async def connect_store(
    request: FamilyStoreCreate,
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Connect a store to family using store code"""
    from app.models.store import Store
    
    family = await get_user_family(current_user, db)
    
    # Find store by code
    result = await db.execute(
        select(Store).where(Store.code == request.code.upper())
    )
    store = result.scalar_one_or_none()
    
    if not store:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store not found with this code",
        )
    
    # Check if already connected
    result = await db.execute(
        select(FamilyStore).where(
            FamilyStore.family_id == family.id,
            FamilyStore.store_id == store.id,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Store already connected",
        )
    
    # Create connection
    family_store = FamilyStore(
        family_id=family.id,
        store_id=store.id,
    )
    db.add(family_store)
    await db.commit()
    
    # Reload with store relationship
    result = await db.execute(
        select(FamilyStore)
        .where(FamilyStore.id == family_store.id)
        .options(selectinload(FamilyStore.store))
    )
    family_store = result.scalar_one()
    
    return FamilyStoreResponse.model_validate(family_store)


@router.delete("/me/stores/{store_id}", status_code=status.HTTP_204_NO_CONTENT)
async def disconnect_store(
    store_id: UUID,
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Disconnect a store from family"""
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(FamilyStore).where(
            FamilyStore.family_id == family.id,
            FamilyStore.store_id == store_id,
        )
    )
    family_store = result.scalar_one_or_none()
    
    if not family_store:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store connection not found",
        )
    
    await db.delete(family_store)
    await db.commit()


@router.get("/me/dashboard", response_model=DashboardStatsResponse)
async def get_dashboard_stats(
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get dashboard statistics for family"""
    from datetime import datetime
    from sqlalchemy import func
    from app.models.transaction import Transaction, TransactionStatus
    
    family = await get_user_family(current_user, db)
    
    # Current month boundaries
    now = datetime.utcnow()
    current_month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if now.month == 1:
        previous_month_start = current_month_start.replace(year=now.year - 1, month=12)
    else:
        previous_month_start = current_month_start.replace(month=now.month - 1)
    
    # Current month spending
    result = await db.execute(
        select(func.coalesce(func.sum(Transaction.total_amount), 0))
        .where(
            Transaction.family_id == family.id,
            Transaction.created_at >= current_month_start,
            Transaction.status != TransactionStatus.REJECTED,
        )
    )
    current_month_spending = result.scalar() or 0
    
    # Previous month spending
    result = await db.execute(
        select(func.coalesce(func.sum(Transaction.total_amount), 0))
        .where(
            Transaction.family_id == family.id,
            Transaction.created_at >= previous_month_start,
            Transaction.created_at < current_month_start,
            Transaction.status != TransactionStatus.REJECTED,
        )
    )
    previous_month_spending = result.scalar() or 0
    
    # Pending transactions count
    result = await db.execute(
        select(func.count(Transaction.id))
        .where(
            Transaction.family_id == family.id,
            Transaction.status == TransactionStatus.PENDING,
        )
    )
    pending_count = result.scalar() or 0
    
    # Recent transactions
    from app.schemas.transaction import TransactionResponse
    from sqlalchemy.orm import selectinload
    
    result = await db.execute(
        select(Transaction)
        .where(Transaction.family_id == family.id)
        .options(
            selectinload(Transaction.staff),
            selectinload(Transaction.store),
            selectinload(Transaction.items),
        )
        .order_by(Transaction.created_at.desc())
        .limit(5)
    )
    recent_transactions = [
        TransactionResponse.model_validate(t) for t in result.scalars().all()
    ]
    
    return DashboardStatsResponse(
        current_month_spending=current_month_spending,
        previous_month_spending=previous_month_spending,
        pending_transactions=pending_count,
        recent_transactions=recent_transactions,
        top_store=None,  # TODO: Calculate
        top_category=None,  # TODO: Calculate
    )
