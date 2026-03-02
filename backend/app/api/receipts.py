"""
Receipt OCR API endpoints
"""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.models.user import User
from app.api.auth import get_current_user
from app.schemas.receipt import (
    OCRRequest,
    OCRResponse,
    PresignedURLRequest,
    PresignedURLResponse,
)
from app.services.ocr import process_receipt_image
from app.services.storage import generate_presigned_url


router = APIRouter()


@router.post("/ocr", response_model=OCRResponse)
async def extract_receipt_data(
    request: OCRRequest,
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Extract data from receipt image using AI OCR"""
    try:
        result = await process_receipt_image(request.image_url)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process receipt: {str(e)}",
        )


@router.post("/presigned", response_model=PresignedURLResponse)
async def get_presigned_upload_url(
    request: PresignedURLRequest,
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Get a presigned URL for uploading receipt image to S3"""
    try:
        result = await generate_presigned_url(
            filename=request.filename,
            content_type=request.content_type,
            user_id=str(current_user.id),
        )
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate upload URL: {str(e)}",
        )
