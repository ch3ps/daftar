"""
SMS OTP service using Twilio Verify in production.
Falls back to an in-memory OTP store for local development.
"""
import asyncio
import logging
import random
import string
from datetime import datetime, timedelta
from typing import Optional, Tuple

from app.config import settings

logger = logging.getLogger(__name__)


# In-memory OTP storage (use Redis in production for multi-instance)
_otp_store: dict[str, dict] = {}


def _is_twilio_configured() -> bool:
    return all(
        [
            settings.TWILIO_ACCOUNT_SID,
            settings.TWILIO_AUTH_TOKEN,
            settings.TWILIO_VERIFY_SERVICE_SID,
        ]
    )


def _build_twilio_client():
    from twilio.rest import Client

    return Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)


def _is_production() -> bool:
    return settings.ENVIRONMENT.lower() == "production"


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
    
    if not _is_twilio_configured():
        if _is_production():
            return False, "OTP service is not configured on the server."

        # Local development fallback
        code = generate_otp()
        expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
        _otp_store[phone] = {
            "code": code,
            "expires_at": expires_at,
            "attempts": _otp_store.get(phone, {}).get("attempts", 0),
            "created_at": datetime.utcnow(),
        }
        print(f"[SMS DEV] OTP for {phone}: {code}")
        return True, "OTP sent (dev mode)"

    try:
        from twilio.base.exceptions import TwilioRestException

        logger.info(f"[SMS] Sending OTP to {phone} via Twilio Verify "
                     f"(service: {settings.TWILIO_VERIFY_SERVICE_SID[:8]}...)")
        client = _build_twilio_client()
        verification = await asyncio.to_thread(
            client.verify.v2.services(settings.TWILIO_VERIFY_SERVICE_SID).verifications.create,
            to=phone,
            channel="sms",
        )

        logger.info(f"[SMS] Twilio response status: {verification.status} for {phone}")
        if verification.status in {"pending", "approved"}:
            return True, "OTP sent successfully"

        return False, f"Failed to send OTP (status: {verification.status})"
    except TwilioRestException as e:
        logger.error(f"[SMS] Twilio verification error {e.code}: {e.msg} "
                      f"(phone: {phone}, status: {e.status})")
        return False, f"Twilio could not send the OTP: {e.msg}"
    except Exception as e:
        logger.error(f"[SMS] Twilio exception: {type(e).__name__}: {e}")
        return False, f"Failed to send OTP: {e}"


async def verify_otp(phone: str, code: str) -> Tuple[bool, str]:
    """
    Verify an OTP code.
    
    Args:
        phone: Phone number
        code: OTP code to verify
        
    Returns:
        Tuple of (valid: bool, message: str)
    """
    phone = normalize_phone(phone)
    
    if not _is_twilio_configured():
        if _is_production():
            return False, "OTP service is not configured on the server."

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
            del _otp_store[phone]
            return True, "OTP verified"

        remaining = settings.OTP_MAX_ATTEMPTS - entry["attempts"]
        return False, f"Invalid code. {remaining} attempts remaining."

    try:
        from twilio.base.exceptions import TwilioRestException

        client = _build_twilio_client()
        check = await asyncio.to_thread(
            client.verify.v2.services(settings.TWILIO_VERIFY_SERVICE_SID).verification_checks.create,
            to=phone,
            code=code,
        )

        logger.info(f"[SMS] Twilio verify status: {check.status} for {phone}")
        if check.status == "approved":
            return True, "OTP verified"

        return False, "Invalid or expired code"
    except TwilioRestException as e:
        logger.error(f"[SMS] Twilio verify error {e.code}: {e.msg} (phone: {phone})")
        return False, f"Twilio could not verify the OTP: {e.msg}"
    except Exception as e:
        logger.error(f"[SMS] Twilio verify exception: {type(e).__name__}: {e}")
        return False, f"Failed to verify OTP: {e}"


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
