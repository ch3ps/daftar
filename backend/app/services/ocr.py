"""
Receipt OCR service using OpenAI GPT-4 Vision
"""
import json
from decimal import Decimal
from typing import Optional

from openai import AsyncOpenAI

from app.config import settings
from app.schemas.ledger import OCRResponse, OCRItemResponse


# Initialize OpenAI client
client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None


# OCR system prompt
OCR_SYSTEM_PROMPT = """You are an expert at extracting structured data from grocery receipt images.
You can read Arabic and English text accurately.

Extract the following information from the receipt image:
1. Store name (both English and Arabic if available)
2. All items with quantities, unit prices, and total prices
3. Total amount

Return the data as JSON with this exact structure:
{
    "store_name": "Store name in English",
    "store_name_ar": "اسم المتجر بالعربية",
    "items": [
        {
            "name": "Item name in English",
            "name_ar": "اسم الصنف بالعربية",
            "quantity": 1.0,
            "unit_price": 5.50,
            "total_price": 5.50
        }
    ],
    "total": 105.00,
    "confidence": 0.95
}

If you cannot read certain fields, omit them or set them to null.
The confidence score should reflect how confident you are in the extraction (0.0 to 1.0).
Always provide the total amount even if other fields are missing."""


async def process_receipt_image(image_url: str) -> OCRResponse:
    """
    Process a receipt image using GPT-4 Vision and extract structured data.
    
    Args:
        image_url: URL of the receipt image
        
    Returns:
        OCRResponse with extracted receipt data
    """
    if not client:
        # Return mock data if OpenAI is not configured
        return _get_mock_response()
    
    try:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": OCR_SYSTEM_PROMPT,
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "Please extract all data from this grocery receipt image. Return only the JSON response.",
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": image_url},
                        },
                    ],
                },
            ],
            max_tokens=4096,
            response_format={"type": "json_object"},
        )
        
        # Parse the response
        content = response.choices[0].message.content
        data = json.loads(content)
        
        # Convert to OCRResponse
        items = [
            OCRItemResponse(
                name=item.get("name", "Unknown Item"),
                name_ar=item.get("name_ar"),
                quantity=Decimal(str(item.get("quantity", 1))),
                unit_price=Decimal(str(item.get("unit_price", 0))),
                total_price=Decimal(str(item.get("total_price", 0))),
                matched_product_id=None,
                matched_product=None
            )
            for item in data.get("items", [])
        ]
        
        return OCRResponse(
            store_name=data.get("store_name"),
            store_name_ar=data.get("store_name_ar"),
            items=items,
            total=Decimal(str(data.get("total", 0))),
            confidence=float(data.get("confidence", 0.8))
        )
        
    except Exception as e:
        print(f"OCR error: {e}")
        raise


def _get_mock_response() -> OCRResponse:
    """Return mock OCR response for testing"""
    return OCRResponse(
        store_name="Al Meera",
        store_name_ar="الميرة",
        items=[
            OCRItemResponse(
                name="Fresh Milk 1L",
                name_ar="حليب طازج 1 لتر",
                quantity=Decimal("2"),
                unit_price=Decimal("5.50"),
                total_price=Decimal("11.00"),
                matched_product_id=None,
                matched_product=None
            ),
            OCRItemResponse(
                name="Arabic Bread",
                name_ar="خبز عربي",
                quantity=Decimal("3"),
                unit_price=Decimal("2.00"),
                total_price=Decimal("6.00"),
                matched_product_id=None,
                matched_product=None
            ),
            OCRItemResponse(
                name="Chicken Breast 500g",
                name_ar="صدر دجاج 500 جم",
                quantity=Decimal("1"),
                unit_price=Decimal("25.00"),
                total_price=Decimal("25.00"),
                matched_product_id=None,
                matched_product=None
            ),
        ],
        total=Decimal("42.00"),
        confidence=0.95
    )


# MARK: - Handwriting OCR (Option A)

HANDWRITING_SYSTEM_PROMPT = """You are an expert at reading handwritten notes in Arabic and English.
Your task is to extract customer name and amount from a handwritten note.

Common patterns you might see:
- "أحمد - ٥٠" (Ahmad - 50)
- "محمد 25 ريال" (Mohammed 25 riyal)  
- "Ali 150"
- "فاطمة ١٠٠ ر.ق" (Fatima 100 QR)

Extract:
1. customer_name: The person's name (could be Arabic or English)
2. amount: The numerical amount (convert Arabic numerals ٠١٢٣٤٥٦٧٨٩ to standard digits)
3. raw_text: The full text you read from the image

Return JSON with this exact structure:
{
    "customer_name": "Ahmad",
    "amount": 50.00,
    "raw_text": "أحمد - ٥٠",
    "confidence": 0.9
}

If you cannot read the name, set customer_name to null.
If you cannot read the amount, set amount to null.
The confidence should reflect how confident you are (0.0 to 1.0)."""


class HandwritingResponse:
    """Response from handwriting OCR"""
    def __init__(self, customer_name: Optional[str], amount: Optional[Decimal], 
                 raw_text: Optional[str], confidence: float):
        self.customer_name = customer_name
        self.amount = amount
        self.raw_text = raw_text
        self.confidence = confidence


async def process_handwriting_image(image_url: str) -> HandwritingResponse:
    """
    Process a handwritten note image using GPT-4 Vision.
    Extracts customer name and amount from handwriting.
    
    Args:
        image_url: URL of the handwriting image
        
    Returns:
        HandwritingResponse with extracted data
    """
    if not client:
        return _get_mock_handwriting_response()
    
    try:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": HANDWRITING_SYSTEM_PROMPT,
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "Please read this handwritten note and extract the customer name and amount. Return only JSON.",
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": image_url},
                        },
                    ],
                },
            ],
            max_tokens=500,
            response_format={"type": "json_object"},
        )
        
        content = response.choices[0].message.content
        data = json.loads(content)
        
        amount = None
        if data.get("amount") is not None:
            try:
                amount = Decimal(str(data["amount"]))
            except:
                pass
        
        return HandwritingResponse(
            customer_name=data.get("customer_name"),
            amount=amount,
            raw_text=data.get("raw_text"),
            confidence=float(data.get("confidence", 0.5))
        )
        
    except Exception as e:
        print(f"Handwriting OCR error: {e}")
        return _get_mock_handwriting_response()


def _get_mock_handwriting_response() -> HandwritingResponse:
    """Return mock handwriting response for testing"""
    return HandwritingResponse(
        customer_name="أحمد",
        amount=Decimal("50.00"),
        raw_text="أحمد - ٥٠ ريال",
        confidence=0.85
    )
