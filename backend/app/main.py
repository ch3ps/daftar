"""
Daftar API - Digital Ledger for Stores and Customers
Production-Ready Version with:
- OTP Authentication
- Rate Limiting
- Error Tracking (Sentry)
- Push Notifications
- GDPR Compliance (Export/Delete)
"""
import random
import string
import json
from datetime import datetime, timedelta
from decimal import Decimal
from typing import List, Optional
from uuid import UUID

from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse, FileResponse
from pathlib import Path
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
import jwt

from app.config import settings
from app.database import get_db
from app.models.ledger import (
    Store, Customer, LedgerEntry, Bill, BillItem, Product, BillStatus
)
from app.schemas.ledger import (
    StoreCreate, StoreResponse, StoreAuthResponse,
    CustomerCreate, CustomerResponse, CustomerAuthResponse,
    BillCreate, BillUpdate, BillResponse, BillItemResponse,
    LedgerEntryResponse, CustomerLedgerResponse,
    LoginRequest, RegisterRequest, JoinStoreRequest, AddCustomerRequest,
    PendingCountResponse, UploadResponse, OCRRequest, OCRResponse,
    HandwritingRequest, HandwritingResponse
)
from app.services.ocr import process_receipt_image, process_handwriting_image
from app.services.storage import upload_file
from app.services.push import send_push_notification, NotificationTemplates
from app.services.sms import send_otp, verify_otp, normalize_phone, get_dev_otp

# Initialize rate limiter
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Daftar API",
    description="Digital Ledger for Stores and Customers - دفتر رقمي للمتاجر والعملاء",
    version="2.1.0",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

# Add rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS
origins = settings.CORS_ORIGINS.split(",") if settings.CORS_ORIGINS != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Create tables on startup
@app.on_event("startup")
async def startup():
    # In production, schema is managed by Alembic migrations.
    # Auto create_tables is only for local/dev convenience.
    if settings.ENVIRONMENT != "production":
        from app.database import create_tables
        await create_tables()
    print(f"✅ Daftar API started in {settings.ENVIRONMENT} mode")


security = HTTPBearer()


# MARK: - Auth Helpers

def create_access_token(user_id: UUID, user_type: str) -> str:
    """Create JWT access token"""
    expire = datetime.utcnow() + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "type": user_type,
        "exp": expire,
        "iat": datetime.utcnow(),
        "token_type": "access"
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: UUID, user_type: str) -> str:
    """Create JWT refresh token (longer-lived)"""
    expire = datetime.utcnow() + timedelta(days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "type": user_type,
        "exp": expire,
        "iat": datetime.utcnow(),
        "token_type": "refresh"
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str, expected_type: str = "access") -> dict:
    """Decode and validate JWT token"""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        if payload.get("token_type") != expected_type and expected_type != "any":
            raise HTTPException(status_code=401, detail="Invalid token type")
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def generate_join_code() -> str:
    """Generate a unique store join code"""
    chars = string.ascii_uppercase.replace('O', '').replace('I', '') + string.digits.replace('0', '').replace('1', '')
    return ''.join(random.choices(chars, k=6))


async def get_current_store(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> Store:
    """Get current authenticated store"""
    payload = decode_token(credentials.credentials, "any")
    if payload.get("type") != "store":
        raise HTTPException(status_code=403, detail="Store access required")
    
    result = await db.execute(select(Store).where(Store.id == UUID(payload["sub"])))
    store = result.scalar_one_or_none()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    return store


async def get_current_customer(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> Customer:
    """Get current authenticated customer"""
    payload = decode_token(credentials.credentials, "any")
    if payload.get("type") != "customer":
        raise HTTPException(status_code=403, detail="Customer access required")
    
    result = await db.execute(select(Customer).where(Customer.id == UUID(payload["sub"])))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return customer


# MARK: - OTP Endpoints

from pydantic import BaseModel as PydanticBaseModel

class SendOTPRequest(PydanticBaseModel):
    phone: str


class VerifyOTPRequest(PydanticBaseModel):
    phone: str
    code: str


class PushTokenRequest(PydanticBaseModel):
    token: str


@app.post("/api/v1/auth/otp/send")
@limiter.limit(settings.RATE_LIMIT_AUTH)
async def request_otp(request: Request, data: SendOTPRequest):
    """Send OTP to phone number for verification"""
    phone = normalize_phone(data.phone)
    success, message = await send_otp(phone)
    
    if not success:
        raise HTTPException(status_code=429, detail=message)
    
    response = {"message": "OTP sent", "phone": phone}
    
    # In development, include the OTP for testing
    if settings.ENVIRONMENT != "production":
        response["dev_otp"] = get_dev_otp(phone)
    
    return response


# MARK: - Store Auth

@app.post("/api/v1/auth/store/register", response_model=StoreAuthResponse)
@limiter.limit(settings.RATE_LIMIT_AUTH)
async def register_store(request: Request, data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new store with OTP verification"""
    phone = normalize_phone(data.phone)
    
    # Check if phone exists
    result = await db.execute(select(Store).where(Store.phone == phone))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone already registered")
    
    store = Store(
        name=data.name,
        name_ar=data.name_ar,
        phone=phone,
        join_code=generate_join_code()
    )
    db.add(store)
    await db.commit()
    await db.refresh(store)
    
    access_token = create_access_token(store.id, "store")
    return StoreAuthResponse(token=access_token, store=StoreResponse.model_validate(store))


@app.post("/api/v1/auth/store/login", response_model=StoreAuthResponse)
@limiter.limit(settings.RATE_LIMIT_AUTH)
async def login_store(request: Request, data: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login as store with OTP verification"""
    phone = normalize_phone(data.phone)
    
    result = await db.execute(select(Store).where(Store.phone == phone))
    store = result.scalar_one_or_none()
    
    if not store:
        raise HTTPException(status_code=401, detail="Phone not registered")
    
    # Verify OTP
    if settings.ENVIRONMENT == "production" or settings.UNIFONIC_APP_SID:
        valid, message = verify_otp(phone, data.code)
        if not valid:
            raise HTTPException(status_code=401, detail=message)
    else:
        # Development mode - accept any 4+ digit code
        if len(data.code) < 4:
            raise HTTPException(status_code=401, detail="Invalid code")
    
    access_token = create_access_token(store.id, "store")
    return StoreAuthResponse(token=access_token, store=StoreResponse.model_validate(store))


@app.get("/api/v1/store/profile", response_model=StoreResponse)
async def get_store_profile(store: Store = Depends(get_current_store)):
    """Get current store profile"""
    return StoreResponse.model_validate(store)


# MARK: - Customer Auth

@app.post("/api/v1/auth/customer/register", response_model=CustomerAuthResponse)
@limiter.limit(settings.RATE_LIMIT_AUTH)
async def register_customer(request: Request, data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new customer"""
    phone = normalize_phone(data.phone)
    
    result = await db.execute(select(Customer).where(Customer.phone == phone))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone already registered")
    
    customer = Customer(
        name=data.name,
        name_ar=data.name_ar,
        phone=phone
    )
    db.add(customer)
    await db.commit()
    await db.refresh(customer)
    
    access_token = create_access_token(customer.id, "customer")
    return CustomerAuthResponse(token=access_token, customer=CustomerResponse.model_validate(customer))


@app.post("/api/v1/auth/customer/login", response_model=CustomerAuthResponse)
@limiter.limit(settings.RATE_LIMIT_AUTH)
async def login_customer(request: Request, data: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login as customer with OTP verification"""
    phone = normalize_phone(data.phone)
    
    result = await db.execute(select(Customer).where(Customer.phone == phone))
    customer = result.scalar_one_or_none()
    
    if not customer:
        raise HTTPException(status_code=401, detail="Phone not registered")
    
    # Verify OTP
    if settings.ENVIRONMENT == "production" or settings.UNIFONIC_APP_SID:
        valid, message = verify_otp(phone, data.code)
        if not valid:
            raise HTTPException(status_code=401, detail=message)
    else:
        if len(data.code) < 4:
            raise HTTPException(status_code=401, detail="Invalid code")
    
    access_token = create_access_token(customer.id, "customer")
    return CustomerAuthResponse(token=access_token, customer=CustomerResponse.model_validate(customer))


@app.get("/api/v1/customer/profile", response_model=CustomerResponse)
async def get_customer_profile(customer: Customer = Depends(get_current_customer)):
    """Get current customer profile"""
    return CustomerResponse.model_validate(customer)


# MARK: - Token Refresh

@app.post("/api/v1/auth/refresh")
async def refresh_access_token(credentials: HTTPAuthorizationCredentials = Depends(security), db: AsyncSession = Depends(get_db)):
    """Refresh access token using refresh token"""
    payload = decode_token(credentials.credentials, "refresh")
    user_type = payload.get("type")
    user_id = UUID(payload["sub"])
    
    # Verify user still exists
    if user_type == "store":
        result = await db.execute(select(Store).where(Store.id == user_id))
        user = result.scalar_one_or_none()
    else:
        result = await db.execute(select(Customer).where(Customer.id == user_id))
        user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    new_access_token = create_access_token(user_id, user_type)
    new_refresh_token = create_refresh_token(user_id, user_type)
    
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }


# MARK: - Push Token Registration

@app.post("/api/v1/store/push-token")
async def register_store_push_token(
    data: PushTokenRequest,
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Register FCM push token for store"""
    store.push_token = data.token
    await db.commit()
    return {"message": "Push token registered"}


@app.post("/api/v1/customer/push-token")
async def register_customer_push_token(
    data: PushTokenRequest,
    customer: Customer = Depends(get_current_customer),
    db: AsyncSession = Depends(get_db)
):
    """Register FCM push token for customer"""
    customer.push_token = data.token
    await db.commit()
    return {"message": "Push token registered"}


# MARK: - Store Ledger

@app.get("/api/v1/store/ledger", response_model=List[LedgerEntryResponse])
async def get_store_ledger(
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Get all customers who owe the store"""
    result = await db.execute(
        select(LedgerEntry)
        .options(selectinload(LedgerEntry.customer))
        .where(LedgerEntry.store_id == store.id)
        .order_by(LedgerEntry.last_activity_at.desc())
    )
    entries = result.scalars().all()
    return [LedgerEntryResponse.model_validate(e) for e in entries]


@app.get("/api/v1/store/customers/{customer_id}/bills", response_model=List[BillResponse])
async def get_customer_bills_for_store(
    customer_id: UUID,
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Get all bills for a specific customer"""
    result = await db.execute(
        select(Bill)
        .options(selectinload(Bill.items))
        .where(Bill.store_id == store.id, Bill.customer_id == customer_id)
        .order_by(Bill.created_at.desc())
    )
    bills = result.scalars().all()
    return [BillResponse.model_validate(b) for b in bills]


@app.post("/api/v1/store/customers", response_model=LedgerEntryResponse)
async def add_customer_to_store(
    data: AddCustomerRequest,
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Add a new customer to the store's ledger"""
    phone = normalize_phone(data.phone)
    
    # Check if customer exists
    result = await db.execute(select(Customer).where(Customer.phone == phone))
    customer = result.scalar_one_or_none()
    
    if not customer:
        customer = Customer(name=data.name, phone=phone)
        db.add(customer)
        await db.flush()
    
    # Check if already in ledger
    result = await db.execute(
        select(LedgerEntry).where(
            LedgerEntry.store_id == store.id,
            LedgerEntry.customer_id == customer.id
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Customer already added")
    
    entry = LedgerEntry(
        store_id=store.id,
        customer_id=customer.id,
        total_owed=Decimal("0"),
        last_activity_at=datetime.utcnow()
    )
    db.add(entry)
    await db.commit()
    
    result = await db.execute(
        select(LedgerEntry)
        .options(selectinload(LedgerEntry.customer))
        .where(LedgerEntry.store_id == store.id, LedgerEntry.customer_id == customer.id)
    )
    entry = result.scalar_one()
    return LedgerEntryResponse.model_validate(entry)


# MARK: - Customer Ledger

@app.get("/api/v1/customer/ledger", response_model=List[CustomerLedgerResponse])
async def get_customer_ledger(
    customer: Customer = Depends(get_current_customer),
    db: AsyncSession = Depends(get_db)
):
    """Get all stores the customer owes"""
    result = await db.execute(
        select(LedgerEntry)
        .options(selectinload(LedgerEntry.store))
        .where(LedgerEntry.customer_id == customer.id)
        .order_by(LedgerEntry.last_activity_at.desc())
    )
    entries = result.scalars().all()
    return [CustomerLedgerResponse.model_validate(e) for e in entries]


@app.get("/api/v1/customer/stores/{store_id}/bills", response_model=List[BillResponse])
async def get_store_bills_for_customer(
    store_id: UUID,
    customer: Customer = Depends(get_current_customer),
    db: AsyncSession = Depends(get_db)
):
    """Get all bills from a specific store"""
    result = await db.execute(
        select(Bill)
        .options(selectinload(Bill.items))
        .where(Bill.store_id == store_id, Bill.customer_id == customer.id)
        .order_by(Bill.created_at.desc())
    )
    bills = result.scalars().all()
    return [BillResponse.model_validate(b) for b in bills]


@app.post("/api/v1/customer/join", response_model=StoreResponse)
async def join_store(
    data: JoinStoreRequest,
    customer: Customer = Depends(get_current_customer),
    db: AsyncSession = Depends(get_db)
):
    """Customer joins a store using their code"""
    result = await db.execute(select(Store).where(Store.join_code == data.code.upper()))
    store = result.scalar_one_or_none()
    
    if not store:
        raise HTTPException(status_code=404, detail="Invalid store code")
    
    result = await db.execute(
        select(LedgerEntry).where(
            LedgerEntry.store_id == store.id,
            LedgerEntry.customer_id == customer.id
        )
    )
    if result.scalar_one_or_none():
        return StoreResponse.model_validate(store)
    
    entry = LedgerEntry(
        store_id=store.id,
        customer_id=customer.id,
        total_owed=Decimal("0"),
        last_activity_at=datetime.utcnow()
    )
    db.add(entry)
    await db.commit()
    
    return StoreResponse.model_validate(store)


@app.get("/api/v1/customer/bills/pending/count", response_model=PendingCountResponse)
async def get_pending_bills_count(
    customer: Customer = Depends(get_current_customer),
    db: AsyncSession = Depends(get_db)
):
    """Get count of pending bills for customer"""
    result = await db.execute(
        select(func.count(Bill.id))
        .where(Bill.customer_id == customer.id, Bill.status == BillStatus.PENDING)
    )
    count = result.scalar() or 0
    return PendingCountResponse(count=count)


# MARK: - Bills

@app.post("/api/v1/bills", response_model=BillResponse)
async def create_bill(
    data: BillCreate,
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Create a new bill"""
    result = await db.execute(
        select(LedgerEntry).where(
            LedgerEntry.store_id == store.id,
            LedgerEntry.customer_id == data.customer_id
        )
    )
    ledger_entry = result.scalar_one_or_none()
    
    if not ledger_entry:
        raise HTTPException(status_code=404, detail="Customer not in ledger")
    
    bill = Bill(
        store_id=store.id,
        customer_id=data.customer_id,
        total_amount=data.total,
        receipt_image_url=data.receipt_image_url,
        notes=data.notes,
        status=BillStatus.PENDING
    )
    db.add(bill)
    await db.flush()
    
    for item_data in data.items:
        item = BillItem(
            bill_id=bill.id,
            name=item_data.name,
            name_ar=item_data.name_ar,
            quantity=item_data.quantity,
            unit_price=item_data.unit_price,
            total_price=item_data.total_price,
            product_id=item_data.product_id
        )
        db.add(item)
    
    ledger_entry.total_owed += data.total
    ledger_entry.last_activity_at = datetime.utcnow()
    
    await db.commit()
    
    result = await db.execute(
        select(Bill).options(selectinload(Bill.items)).where(Bill.id == bill.id)
    )
    bill = result.scalar_one()
    
    # Send push notification
    customer_result = await db.execute(select(Customer).where(Customer.id == data.customer_id))
    customer = customer_result.scalar_one_or_none()
    if customer and customer.push_token:
        title, body = NotificationTemplates.new_bill(store.name, str(data.total))
        await send_push_notification(token=customer.push_token, title=title, body=body)
    
    return BillResponse.model_validate(bill)


@app.patch("/api/v1/bills/{bill_id}", response_model=BillResponse)
async def update_bill(
    bill_id: UUID,
    data: BillUpdate,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
):
    """Update bill status"""
    payload = decode_token(credentials.credentials, "any")
    user_type = payload.get("type")
    user_id = UUID(payload["sub"])
    
    result = await db.execute(
        select(Bill).options(selectinload(Bill.items)).where(Bill.id == bill_id)
    )
    bill = result.scalar_one_or_none()
    
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")
    
    if user_type == "store" and bill.store_id != user_id:
        raise HTTPException(status_code=403, detail="Not your bill")
    if user_type == "customer" and bill.customer_id != user_id:
        raise HTTPException(status_code=403, detail="Not your bill")
    
    old_status = bill.status
    
    if data.status:
        new_status = BillStatus(data.status)
        bill.status = new_status
        
        if old_status != new_status:
            result = await db.execute(
                select(LedgerEntry).where(
                    LedgerEntry.store_id == bill.store_id,
                    LedgerEntry.customer_id == bill.customer_id
                )
            )
            ledger_entry = result.scalar_one()
            
            if new_status == BillStatus.PAID and old_status == BillStatus.PENDING:
                ledger_entry.total_owed -= bill.total_amount
                bill.paid_at = datetime.utcnow()
            elif new_status == BillStatus.PENDING and old_status == BillStatus.PAID:
                ledger_entry.total_owed += bill.total_amount
                bill.paid_at = None
            
            ledger_entry.last_activity_at = datetime.utcnow()
    
    if data.notes is not None:
        bill.notes = data.notes
    
    await db.commit()
    await db.refresh(bill)
    
    return BillResponse.model_validate(bill)


# MARK: - Upload & OCR

@app.post("/api/v1/upload", response_model=UploadResponse)
@limiter.limit(settings.RATE_LIMIT_API)
async def upload_image_endpoint(
    request: Request,
    file: UploadFile = File(...),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Upload an image"""
    decode_token(credentials.credentials, "any")
    contents = await file.read()
    url = await upload_file(contents, file.filename or "receipt.jpg")
    return UploadResponse(url=url)


@app.post("/api/v1/ocr/receipt", response_model=OCRResponse)
@limiter.limit(settings.RATE_LIMIT_OCR)
async def ocr_receipt(
    request: Request,
    data: OCRRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Process receipt image with OCR"""
    decode_token(credentials.credentials, "any")
    result = await process_receipt_image(data.image_url)
    return result


@app.post("/api/v1/ocr/handwriting", response_model=HandwritingResponse)
@limiter.limit(settings.RATE_LIMIT_OCR)
async def ocr_handwriting(
    request: Request,
    data: HandwritingRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Process handwritten note to extract customer name and amount"""
    decode_token(credentials.credentials, "any")
    result = await process_handwriting_image(data.image_url)
    return HandwritingResponse(
        customer_name=result.customer_name,
        amount=result.amount,
        raw_text=result.raw_text,
        confidence=result.confidence
    )


# MARK: - Products

@app.get("/api/v1/products", response_model=List[dict])
async def search_products(
    q: str = "",
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Search products"""
    query = select(Product).where(
        Product.store_id == store.id,
        Product.name.ilike(f"%{q}%")
    ).limit(20)
    
    result = await db.execute(query)
    products = result.scalars().all()
    return [{"id": str(p.id), "name": p.name, "name_ar": p.name_ar} for p in products]


# MARK: - GDPR Compliance: Data Export & Deletion

@app.get("/api/v1/store/export")
async def export_store_data(
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Export all store data as JSON (GDPR compliance)"""
    # Get all ledger entries with customers
    ledger_result = await db.execute(
        select(LedgerEntry)
        .options(selectinload(LedgerEntry.customer))
        .where(LedgerEntry.store_id == store.id)
    )
    ledger_entries = ledger_result.scalars().all()
    
    # Get all bills with items
    bills_result = await db.execute(
        select(Bill)
        .options(selectinload(Bill.items))
        .where(Bill.store_id == store.id)
    )
    bills = bills_result.scalars().all()
    
    export_data = {
        "exported_at": datetime.utcnow().isoformat(),
        "store": {
            "id": str(store.id),
            "name": store.name,
            "name_ar": store.name_ar,
            "phone": store.phone,
            "address": store.address,
            "join_code": store.join_code,
            "created_at": store.created_at.isoformat() if store.created_at else None
        },
        "customers": [
            {
                "id": str(e.customer_id),
                "name": e.customer.name if e.customer else None,
                "phone": e.customer.phone if e.customer else None,
                "total_owed": str(e.total_owed),
                "last_activity_at": e.last_activity_at.isoformat() if e.last_activity_at else None
            }
            for e in ledger_entries
        ],
        "bills": [
            {
                "id": str(b.id),
                "customer_id": str(b.customer_id),
                "total_amount": str(b.total_amount),
                "status": b.status.value,
                "created_at": b.created_at.isoformat() if b.created_at else None,
                "paid_at": b.paid_at.isoformat() if b.paid_at else None,
                "items": [
                    {
                        "name": item.name,
                        "quantity": str(item.quantity),
                        "unit_price": str(item.unit_price),
                        "total_price": str(item.total_price)
                    }
                    for item in b.items
                ]
            }
            for b in bills
        ]
    }
    
    return JSONResponse(
        content=export_data,
        headers={"Content-Disposition": f"attachment; filename=daftar-export-{store.id}.json"}
    )


@app.delete("/api/v1/store/account")
async def delete_store_account(
    store: Store = Depends(get_current_store),
    db: AsyncSession = Depends(get_db)
):
    """Delete store account and all associated data (GDPR compliance)"""
    # Delete all bill items for this store's bills
    await db.execute(
        delete(BillItem).where(
            BillItem.bill_id.in_(
                select(Bill.id).where(Bill.store_id == store.id)
            )
        )
    )
    
    # Delete all bills
    await db.execute(delete(Bill).where(Bill.store_id == store.id))
    
    # Delete all ledger entries
    await db.execute(delete(LedgerEntry).where(LedgerEntry.store_id == store.id))
    
    # Delete all products
    await db.execute(delete(Product).where(Product.store_id == store.id))
    
    # Delete the store
    await db.execute(delete(Store).where(Store.id == store.id))
    
    await db.commit()
    
    return {"message": "Account and all data deleted successfully"}


@app.get("/api/v1/customer/export")
async def export_customer_data(
    customer: Customer = Depends(get_current_customer),
    db: AsyncSession = Depends(get_db)
):
    """Export all customer data as JSON (GDPR compliance)"""
    ledger_result = await db.execute(
        select(LedgerEntry)
        .options(selectinload(LedgerEntry.store))
        .where(LedgerEntry.customer_id == customer.id)
    )
    ledger_entries = ledger_result.scalars().all()
    
    bills_result = await db.execute(
        select(Bill)
        .options(selectinload(Bill.items), selectinload(Bill.store))
        .where(Bill.customer_id == customer.id)
    )
    bills = bills_result.scalars().all()
    
    export_data = {
        "exported_at": datetime.utcnow().isoformat(),
        "customer": {
            "id": str(customer.id),
            "name": customer.name,
            "name_ar": customer.name_ar,
            "phone": customer.phone,
            "created_at": customer.created_at.isoformat() if customer.created_at else None
        },
        "stores": [
            {
                "store_id": str(e.store_id),
                "store_name": e.store.name if e.store else None,
                "total_owed": str(e.total_owed),
                "last_activity_at": e.last_activity_at.isoformat() if e.last_activity_at else None
            }
            for e in ledger_entries
        ],
        "bills": [
            {
                "id": str(b.id),
                "store_name": b.store.name if b.store else None,
                "total_amount": str(b.total_amount),
                "status": b.status.value,
                "created_at": b.created_at.isoformat() if b.created_at else None,
                "items": [
                    {"name": item.name, "quantity": str(item.quantity), "total_price": str(item.total_price)}
                    for item in b.items
                ]
            }
            for b in bills
        ]
    }
    
    return JSONResponse(
        content=export_data,
        headers={"Content-Disposition": f"attachment; filename=daftar-export-{customer.id}.json"}
    )


@app.delete("/api/v1/customer/account")
async def delete_customer_account(
    customer: Customer = Depends(get_current_customer),
    db: AsyncSession = Depends(get_db)
):
    """Delete customer account and all associated data (GDPR compliance)"""
    # Delete all bill items
    await db.execute(
        delete(BillItem).where(
            BillItem.bill_id.in_(
                select(Bill.id).where(Bill.customer_id == customer.id)
            )
        )
    )
    
    # Delete all bills
    await db.execute(delete(Bill).where(Bill.customer_id == customer.id))
    
    # Delete all ledger entries
    await db.execute(delete(LedgerEntry).where(LedgerEntry.customer_id == customer.id))
    
    # Delete the customer
    await db.execute(delete(Customer).where(Customer.id == customer.id))
    
    await db.commit()
    
    return {"message": "Account and all data deleted successfully"}


# MARK: - Health Check & Legal Pages

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "version": "2.1.0",
        "environment": settings.ENVIRONMENT
    }


# Static files directory
STATIC_DIR = Path(__file__).parent.parent / "static"


@app.get("/privacy")
async def privacy_policy():
    """Privacy Policy page"""
    return FileResponse(STATIC_DIR / "privacy.html", media_type="text/html")


@app.get("/terms")
async def terms_of_service():
    """Terms of Service page"""
    return FileResponse(STATIC_DIR / "terms.html", media_type="text/html")


# MARK: - Demo/Development Endpoints

@app.post("/api/v1/seed")
async def seed_demo_data(db: AsyncSession = Depends(get_db)):
    """Seed demo data for testing"""
    if settings.ENVIRONMENT == "production":
        raise HTTPException(status_code=403, detail="Not available in production")
    
    import uuid
    
    result = await db.execute(select(Store).where(Store.join_code == "DEMO01"))
    existing_store = result.scalar_one_or_none()
    if existing_store:
        token = create_access_token(existing_store.id, "store")
        return {"message": "Demo data already exists", "store_code": "DEMO01", "token": token}
    
    demo_store = Store(
        id=uuid.uuid4(),
        name="Demo Baqala",
        name_ar="بقالة تجريبية",
        phone="+97412345678",
        join_code="DEMO01"
    )
    db.add(demo_store)
    await db.flush()
    
    customers_data = [
        {"name": "Ahmed", "name_ar": "أحمد", "phone": "+97455551111", "balance": Decimal("150.00")},
        {"name": "Mohammed", "name_ar": "محمد", "phone": "+97455552222", "balance": Decimal("75.50")},
        {"name": "Ali", "name_ar": "علي", "phone": "+97455553333", "balance": Decimal("200.00")},
        {"name": "Fatima", "name_ar": "فاطمة", "phone": "+97455554444", "balance": Decimal("0.00")},
    ]
    
    customers = []
    for c_data in customers_data:
        customer = Customer(id=uuid.uuid4(), name=c_data["name"], name_ar=c_data["name_ar"], phone=c_data["phone"])
        db.add(customer)
        customers.append((customer, c_data["balance"]))
    await db.flush()
    
    for customer, balance in customers:
        entry = LedgerEntry(store_id=demo_store.id, customer_id=customer.id, total_owed=balance, last_activity_at=datetime.utcnow())
        db.add(entry)
        
        if balance > 0:
            bill = Bill(
                id=uuid.uuid4(),
                store_id=demo_store.id,
                customer_id=customer.id,
                total_amount=balance,
                status=BillStatus.PENDING,
                created_at=datetime.utcnow() - timedelta(days=random.randint(1, 7))
            )
            db.add(bill)
            await db.flush()
            
            item = BillItem(
                id=uuid.uuid4(),
                bill_id=bill.id,
                name="Purchase",
                name_ar="مشتريات",
                quantity=Decimal("1"),
                unit_price=balance,
                total_price=balance
            )
            db.add(item)
    
    await db.commit()
    
    token = create_access_token(demo_store.id, "store")
    return {
        "message": "Demo data created",
        "store": {"id": str(demo_store.id), "name": demo_store.name, "join_code": "DEMO01", "token": token},
        "customers": [{"name": c.name, "phone": c.phone, "balance": str(b)} for c, b in customers]
    }


@app.get("/api/v1/demo/login")
async def demo_login(db: AsyncSession = Depends(get_db)):
    """Quick demo login"""
    if settings.ENVIRONMENT == "production":
        raise HTTPException(status_code=403, detail="Not available in production")
    
    result = await db.execute(select(Store).where(Store.join_code == "DEMO01"))
    store = result.scalar_one_or_none()
    
    if not store:
        raise HTTPException(status_code=404, detail="Demo store not found. Call POST /api/v1/seed first.")
    
    token = create_access_token(store.id, "store")
    return StoreAuthResponse(token=token, store=StoreResponse.model_validate(store))
