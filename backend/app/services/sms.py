"""
SMS Service using Unifonic (optimized for GCC region)
Supports OTP verification for Qatar phone numbers
"""
import random
import string
from datetime import datetime, timedelta
from typing import Optional, Tuple

import httpx

from app.config import settings


# In-memory OTP storage (use Redis in production for multi-instance)
_otp_store: dict[str, dict] = {}


def generate_otp() -> str:
    """Generate a random numeric OTP code"""
    return ''.join(random.choices(string.digits, k=settings.OTP_LENGTH))


async def send_otp(phone: str) -> Tuple[bool, str]:
    """
    Generate and send OTP to phone number.
    
    Args:
        phone: Phone number with country code (e.g., +97455551234)
        
    Returns:
        Tuple of (success: bool, message: str)
    """
    # Normalize phone number
    phone = normalize_phone(phone)
    
    # Check rate limit (max attempts per phone)
    if phone in _otp_store:
        entry = _otp_store[phone]
        if entry.get("attempts", 0) >= settings.OTP_MAX_ATTEMPTS:
            if datetime.utcnow() < entry.get("lockout_until", datetime.min):
                return False, "Too many attempts. Please try again later."
            else:
                # Reset after lockout period
                entry["attempts"] = 0
    
    # Generate new OTP
    code = generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
    
    # Store OTP
    _otp_store[phone] = {
        "code": code,
        "expires_at": expires_at,
        "attempts": _otp_store.get(phone, {}).get("attempts", 0),
        "created_at": datetime.utcnow()
    }
    
    # Send SMS
    if not settings.UNIFONIC_APP_SID:
        # Development mode - just log
        print(f"[SMS DEV] OTP for {phone}: {code}")
        return True, "OTP sent (dev mode)"
    
    # Production - send via Unifonic
    try:
        message_en = f"Your Daftar verification code is: {code}"
        message_ar = f"رمز التحقق من دفتر: {code}"
        message = f"{message_en}\n\n{message_ar}"
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                "https://el.cloud.unifonic.com/rest/SMS/messages",
                data={
                    "AppSid": settings.UNIFONIC_APP_SID,
                    "Recipient": phone.replace("+", ""),  # Unifonic wants no +
                    "Body": message,
                    "SenderID": settings.UNIFONIC_SENDER_ID,
                }
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get("success") == "true":
                    return True, "OTP sent successfully"
                else:
                    print(f"[SMS] Unifonic error: {result}")
                    return False, "Failed to send SMS"
            else:
                print(f"[SMS] HTTP error {response.status_code}: {response.text}")
                return False, "SMS service unavailable"
                
    except Exception as e:
        print(f"[SMS] Exception: {e}")
        return False, "Failed to send SMS"


def verify_otp(phone: str, code: str) -> Tuple[bool, str]:
    """
    Verify an OTP code.
    
    Args:
        phone: Phone number
        code: OTP code to verify
        
    Returns:
        Tuple of (valid: bool, message: str)
    """
    phone = normalize_phone(phone)
    
    if phone not in _otp_store:
        return False, "No OTP requested for this number"
    
    entry = _otp_store[phone]
    
    # Check expiry
    if datetime.utcnow() > entry["expires_at"]:
        del _otp_store[phone]
        return False, "OTP has expired. Please request a new one."
    
    # Increment attempts
    entry["attempts"] = entry.get("attempts", 0) + 1
    
    # Check max attempts
    if entry["attempts"] > settings.OTP_MAX_ATTEMPTS:
        entry["lockout_until"] = datetime.utcnow() + timedelta(minutes=15)
        return False, "Too many failed attempts. Please wait 15 minutes."
    
    # Verify code
    if entry["code"] == code:
        # Success - remove OTP
        del _otp_store[phone]
        return True, "OTP verified"
    else:
        remaining = settings.OTP_MAX_ATTEMPTS - entry["attempts"]
        return False, f"Invalid code. {remaining} attempts remaining."


def normalize_phone(phone: str) -> str:
    """Normalize phone number to E.164 format"""
    # Remove spaces, dashes, parentheses
    phone = ''.join(c for c in phone if c.isdigit() or c == '+')
    
    # Add + if missing
    if not phone.startswith('+'):
        # Assume Qatar if no country code
        if phone.startswith('974'):
            phone = '+' + phone
        elif phone.startswith('00974'):
            phone = '+' + phone[2:]
        else:
            phone = '+974' + phone
    
    return phone


# Development helper - get current OTP (for testing only)
def get_dev_otp(phone: str) -> Optional[str]:
    """Get OTP for testing - only works in development"""
    if settings.ENVIRONMENT == "production":
        return None
    phone = normalize_phone(phone)
    entry = _otp_store.get(phone)
    return entry["code"] if entry else None
