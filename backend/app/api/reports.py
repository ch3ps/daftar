"""
Reports API endpoints
"""
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.api.auth import get_current_family_user
from app.api.families import get_user_family
from app.schemas.report import MonthlyReportResponse
from app.services.reports import generate_monthly_report


router = APIRouter()


@router.get("/monthly", response_model=MonthlyReportResponse)
async def get_monthly_report(
    month: int = Query(ge=1, le=12),
    year: int = Query(ge=2020, le=2100),
    current_user: Annotated[User, Depends(get_current_family_user)] = None,
    db: Annotated[AsyncSession, Depends(get_db)] = None,
):
    """Get monthly spending report"""
    family = await get_user_family(current_user, db)
    
    report = await generate_monthly_report(
        db=db,
        family_id=family.id,
        month=month,
        year=year,
    )
    
    return report


@router.get("/monthly/pdf")
async def get_monthly_report_pdf(
    month: int = Query(ge=1, le=12),
    year: int = Query(ge=2020, le=2100),
    current_user: Annotated[User, Depends(get_current_family_user)] = None,
    db: Annotated[AsyncSession, Depends(get_db)] = None,
):
    """Generate and download monthly report as PDF"""
    from fastapi.responses import FileResponse
    from app.services.reports import generate_report_pdf
    
    family = await get_user_family(current_user, db)
    
    pdf_path = await generate_report_pdf(
        db=db,
        family_id=family.id,
        month=month,
        year=year,
    )
    
    return FileResponse(
        path=pdf_path,
        filename=f"daftar_report_{year}_{month:02d}.pdf",
        media_type="application/pdf",
    )
