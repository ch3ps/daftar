"""
Staff management API endpoints
"""
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User, Staff, UserRole
from app.api.auth import (
    get_current_user,
    get_current_family_user,
    get_password_hash,
)
from app.api.families import get_user_family
from app.schemas.user import StaffCreate, StaffResponse, StaffUpdate


router = APIRouter()


@router.get("/me", response_model=StaffResponse)
async def get_my_staff_profile(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get current user's staff profile"""
    result = await db.execute(
        select(Staff).where(Staff.user_id == current_user.id)
    )
    staff = result.scalar_one_or_none()
    
    if not staff:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff profile not found",
        )
    
    return StaffResponse.model_validate(staff)


@router.post("", response_model=StaffResponse, status_code=status.HTTP_201_CREATED)
async def add_staff_member(
    request: StaffCreate,
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Add a new staff member to family"""
    family = await get_user_family(current_user, db)
    
    # Check if email already exists
    result = await db.execute(select(User).where(User.email == request.email))
    existing_user = result.scalar_one_or_none()
    
    if existing_user:
        # Check if already staff for this family
        result = await db.execute(
            select(Staff).where(
                Staff.user_id == existing_user.id,
                Staff.family_id == family.id,
            )
        )
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User is already a staff member",
            )
        
        # Create staff profile for existing user
        staff = Staff(
            user_id=existing_user.id,
            family_id=family.id,
            name=request.name,
            role=request.role,
            spending_limit=request.spending_limit,
        )
    else:
        # Create new user with temporary password
        import secrets
        temp_password = secrets.token_urlsafe(16)
        
        new_user = User(
            email=request.email,
            password_hash=get_password_hash(temp_password),
            name=request.name,
            role=UserRole.STAFF,
        )
        db.add(new_user)
        await db.flush()
        
        # Create staff profile
        staff = Staff(
            user_id=new_user.id,
            family_id=family.id,
            name=request.name,
            role=request.role,
            spending_limit=request.spending_limit,
        )
        
        # TODO: Send invitation email with temp password
    
    db.add(staff)
    await db.commit()
    await db.refresh(staff)
    
    return StaffResponse.model_validate(staff)


@router.get("/{staff_id}", response_model=StaffResponse)
async def get_staff_member(
    staff_id: UUID,
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get a specific staff member"""
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(Staff).where(
            Staff.id == staff_id,
            Staff.family_id == family.id,
        )
    )
    staff = result.scalar_one_or_none()
    
    if not staff:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff member not found",
        )
    
    return StaffResponse.model_validate(staff)


@router.patch("/{staff_id}", response_model=StaffResponse)
async def update_staff_member(
    staff_id: UUID,
    update: StaffUpdate,
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Update a staff member"""
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(Staff).where(
            Staff.id == staff_id,
            Staff.family_id == family.id,
        )
    )
    staff = result.scalar_one_or_none()
    
    if not staff:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff member not found",
        )
    
    update_data = update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(staff, field, value)
    
    await db.commit()
    await db.refresh(staff)
    
    return StaffResponse.model_validate(staff)


@router.delete("/{staff_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_staff_member(
    staff_id: UUID,
    current_user: Annotated[User, Depends(get_current_family_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Remove a staff member from family"""
    family = await get_user_family(current_user, db)
    
    result = await db.execute(
        select(Staff).where(
            Staff.id == staff_id,
            Staff.family_id == family.id,
        )
    )
    staff = result.scalar_one_or_none()
    
    if not staff:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff member not found",
        )
    
    await db.delete(staff)
    await db.commit()
