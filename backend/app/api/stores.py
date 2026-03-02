"""
Store API endpoints
"""
from typing import Annotated, List

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.models.store import Store, FamilyStore
from app.api.auth import get_current_user
from app.api.families import get_user_family
from app.schemas.store import StoreResponse, StoreSearchResult


router = APIRouter()


@router.get("/search", response_model=List[StoreSearchResult])
async def search_stores(
    q: str = Query(min_length=1, max_length=100),
    current_user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[AsyncSession, Depends(get_db)] = None,
):
    """Search stores by name"""
    family = await get_user_family(current_user, db)
    
    # Search stores
    search_pattern = f"%{q}%"
    result = await db.execute(
        select(Store).where(
            or_(
                Store.name.ilike(search_pattern),
                Store.name_ar.ilike(search_pattern),
            )
        ).limit(20)
    )
    stores = result.scalars().all()
    
    # Get connected store IDs
    result = await db.execute(
        select(FamilyStore.store_id).where(FamilyStore.family_id == family.id)
    )
    connected_store_ids = {row[0] for row in result.all()}
    
    return [
        StoreSearchResult(
            id=store.id,
            name=store.name,
            name_ar=store.name_ar,
            address=store.address,
            is_connected=store.id in connected_store_ids,
        )
        for store in stores
    ]


@router.get("/{store_id}", response_model=StoreResponse)
async def get_store(
    store_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get store details by ID"""
    from uuid import UUID
    from fastapi import HTTPException, status
    
    result = await db.execute(
        select(Store).where(Store.id == UUID(store_id))
    )
    store = result.scalar_one_or_none()
    
    if not store:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store not found",
        )
    
    return StoreResponse.model_validate(store)
