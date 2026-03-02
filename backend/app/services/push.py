"""
Push notification service using Firebase Cloud Messaging
"""
from typing import Optional, List
import json

from app.config import settings

# Firebase Admin SDK
_firebase_app = None

def _init_firebase():
    """Initialize Firebase Admin SDK"""
    global _firebase_app
    if _firebase_app is not None:
        return True
        
    if not settings.FIREBASE_CREDENTIALS_PATH:
        return False
    
    try:
        import firebase_admin
        from firebase_admin import credentials
        
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
        return True
    except Exception as e:
        print(f"[PUSH] Firebase init error: {e}")
        return False


async def send_push_notification(
    token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
    badge: Optional[int] = None
) -> bool:
    """
    Send a push notification to a single device.
    
    Args:
        token: FCM device token
        title: Notification title
        body: Notification body
        data: Optional data payload
        badge: Optional badge count for iOS
        
    Returns:
        True if successful, False otherwise
    """
    if not _init_firebase():
        # Development mode - just log
        print(f"[PUSH DEV] To: {token[:20]}... | {title}: {body}")
        return True
    
    try:
        from firebase_admin import messaging
        
        # Build notification
        notification = messaging.Notification(
            title=title,
            body=body,
        )
        
        # iOS-specific config
        apns = messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    badge=badge,
                    sound="default",
                    content_available=True,
                )
            )
        )
        
        # Android-specific config
        android = messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                click_action="FLUTTER_NOTIFICATION_CLICK",
            )
        )
        
        message = messaging.Message(
            notification=notification,
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            apns=apns,
            android=android,
        )
        
        response = messaging.send(message)
        print(f"[PUSH] Sent successfully: {response}")
        return True
        
    except Exception as e:
        print(f"[PUSH] Error sending to {token[:20]}...: {e}")
        return False


async def send_push_to_multiple(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[dict] = None
) -> dict:
    """
    Send push notification to multiple devices.
    
    Args:
        tokens: List of FCM device tokens
        title: Notification title
        body: Notification body
        data: Optional data payload
        
    Returns:
        Dict with success_count, failure_count, and failed_tokens
    """
    if not tokens:
        return {"success_count": 0, "failure_count": 0, "failed_tokens": []}
    
    if not _init_firebase():
        print(f"[PUSH DEV] To {len(tokens)} devices: {title}: {body}")
        return {"success_count": len(tokens), "failure_count": 0, "failed_tokens": []}
    
    try:
        from firebase_admin import messaging
        
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            tokens=tokens,
        )
        
        response = messaging.send_multicast(message)
        
        failed_tokens = []
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    failed_tokens.append(tokens[idx])
        
        return {
            "success_count": response.success_count,
            "failure_count": response.failure_count,
            "failed_tokens": failed_tokens
        }
        
    except Exception as e:
        print(f"[PUSH] Multicast error: {e}")
        return {"success_count": 0, "failure_count": len(tokens), "failed_tokens": tokens}


# Notification templates for common events
class NotificationTemplates:
    @staticmethod
    def new_bill(store_name: str, amount: str, lang: str = "en") -> tuple:
        """New bill notification"""
        if lang == "ar":
            return (
                f"فاتورة جديدة من {store_name}",
                f"تمت إضافة فاتورة بقيمة {amount} ر.ق إلى حسابك"
            )
        return (
            f"New bill from {store_name}",
            f"A bill of QR {amount} has been added to your account"
        )
    
    @staticmethod
    def payment_received(customer_name: str, amount: str, lang: str = "en") -> tuple:
        """Payment received notification"""
        if lang == "ar":
            return (
                f"تم استلام دفعة من {customer_name}",
                f"تم استلام {amount} ر.ق"
            )
        return (
            f"Payment received from {customer_name}",
            f"QR {amount} has been received"
        )
    
    @staticmethod
    def reminder(store_name: str, amount: str, lang: str = "en") -> tuple:
        """Payment reminder notification"""
        if lang == "ar":
            return (
                f"تذكير من {store_name}",
                f"لديك رصيد مستحق بقيمة {amount} ر.ق"
            )
        return (
            f"Reminder from {store_name}",
            f"You have an outstanding balance of QR {amount}"
        )
