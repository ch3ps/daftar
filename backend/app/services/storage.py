"""
File storage service - Firebase Storage or local fallback
"""
import os
import uuid
from datetime import datetime, timedelta

from app.config import settings


def _get_firebase_bucket():
    """Get Firebase Storage bucket - lazy init"""
    if not settings.FIREBASE_CREDENTIALS_PATH:
        return None
    try:
        import firebase_admin
        from firebase_admin import storage as fb_storage

        # Use existing app or initialize
        try:
            firebase_admin.get_app()
        except ValueError:
            from firebase_admin import credentials
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred, {
                "storageBucket": settings.FIREBASE_STORAGE_BUCKET
            })

        return fb_storage.bucket()
    except Exception as e:
        print(f"[Storage] Firebase init error: {e}")
        return None


async def upload_file(file_data: bytes, filename: str) -> str:
    """
    Upload a file and return its public URL.

    Uses Firebase Storage if credentials are configured,
    otherwise falls back to local disk (development only).
    """
    ext = os.path.splitext(filename)[1] or ".jpg"
    unique_name = f"{datetime.utcnow().strftime('%Y/%m/%d')}/{uuid.uuid4()}{ext}"
    content_type = _get_content_type(ext)

    bucket = _get_firebase_bucket()
    if bucket:
        try:
            blob = bucket.blob(f"receipts/{unique_name}")
            blob.upload_from_string(file_data, content_type=content_type)
            blob.make_public()
            return blob.public_url
        except Exception as e:
            print(f"[Storage] Firebase upload error: {e}")
            raise

    # Local fallback for development
    local_dir = os.path.join(os.path.dirname(__file__), "..", "..", "uploads")
    os.makedirs(local_dir, exist_ok=True)

    safe_name = unique_name.replace("/", "_")
    local_path = os.path.join(local_dir, safe_name)
    with open(local_path, "wb") as f:
        f.write(file_data)

    return f"http://localhost:8000/uploads/{safe_name}"


def _get_content_type(ext: str) -> str:
    types = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".gif": "image/gif",
        ".webp": "image/webp",
        ".pdf": "application/pdf",
    }
    return types.get(ext.lower(), "application/octet-stream")
