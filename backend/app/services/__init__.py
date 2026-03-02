"""
Business logic services
"""
from app.services.ocr import process_receipt_image, process_handwriting_image
from app.services.storage import upload_file
from app.services.push import (
    send_push_notification, 
    send_push_to_multiple,
    NotificationTemplates
)
from app.services.sms import send_otp, verify_otp, normalize_phone, get_dev_otp

__all__ = [
    "process_receipt_image",
    "process_handwriting_image",
    "upload_file",
    "send_push_notification",
    "send_push_to_multiple",
    "NotificationTemplates",
    "send_otp",
    "verify_otp",
    "normalize_phone",
    "get_dev_otp",
]
