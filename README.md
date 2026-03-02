# Daftar (دفتر) - Digital Ledger for Stores & Customers

A minimal, fast mobile platform that digitizes the traditional store credit ledger (دفتر) system used across the GCC region.

## The Problem

Small grocery stores (baqalas) and supermarkets in Qatar use paper ledgers to track customer credit accounts. Customers buy on credit and pay at month-end. This creates:

- **No transparency** - Customers don't know exactly what they owe
- **No notifications** - Purchases happen without customer awareness
- **Manual tracking** - Stores use paper notebooks, prone to errors
- **Trust issues** - Disputes over amounts are common

## The Solution

Daftar digitizes this ledger, giving both stores and customers real-time visibility:

### For Stores
- **Scan receipts** with AI-powered OCR to auto-extract items
- **Add bills manually** for quick entry
- **See all customers** who owe money in one place
- **Track payments** and mark bills as paid

### For Customers
- **Get notifications** when bills are added to your account
- **See all stores** you owe and how much
- **View itemized bills** with product details
- **Dispute issues** directly in the app

## Key Features

- **Quick bill entry** - Enter amount and done in 2 taps
- **Instant WhatsApp sharing** - Share bills and statements directly
- **Smart reminders** - "Who to chase" shows overdue customers
- **Beautiful Arabic/English UI** - Full RTL support with light/dark mode
- **Store Analytics** - Revenue, collection rate, top customers
- **PDF/CSV Export** - Export your ledger anytime
- **Store Discovery** - Customers can find and join stores
- **Onboarding flows** - Guide new users through the app

## How It Works

```
┌─────────────────┐         ┌─────────────────┐
│     STORE       │         │    CUSTOMER     │
├─────────────────┤         ├─────────────────┤
│                 │         │                 │
│ 1. Scan receipt │ ──────▶ │ 2. Get notified │
│    or add bill  │   push  │                 │
│                 │         │ 3. View details │
│ 4. Mark paid    │ ◀────── │    or dispute   │
│                 │         │                 │
└─────────────────┘         └─────────────────┘
         │                           │
         └───────────┬───────────────┘
                     │
              ┌──────▼──────┐
              │   SHARED    │
              │   LEDGER    │
              │  (Digital   │
              │   دفتر)     │
              └─────────────┘
```

## Tech Stack

### iOS App (SwiftUI)
- Swift 5.9+ with SwiftUI
- MVVM architecture
- Async/await networking
- Bilingual (Arabic/English)

### Backend (Python FastAPI)
- Python 3.11 with FastAPI
- PostgreSQL 15 with SQLAlchemy 2.0
- OpenAI GPT-4 Vision for receipt OCR
- AWS S3 for file storage
- Firebase Cloud Messaging for push

## Project Structure

```
daftar/
├── daftar/                    # iOS App
│   ├── App/                   # App entry point
│   ├── Core/
│   │   ├── API/              # API client
│   │   ├── Auth/             # Authentication
│   │   ├── Models/           # Data models
│   │   └── Services/         # App state
│   ├── Features/
│   │   ├── Store/            # Store features
│   │   ├── Customer/         # Customer features
│   │   ├── Onboarding/       # Auth flows
│   │   └── Settings/         # Settings
│   └── Shared/
│       ├── Extensions/       # Swift extensions
│       └── Localization/     # Arabic/English
│
└── backend/                   # FastAPI Backend
    ├── app/
    │   ├── api/              # (deprecated)
    │   ├── models/           # SQLAlchemy models
    │   ├── schemas/          # Pydantic schemas
    │   └── services/         # Business logic
    ├── alembic/              # Database migrations
    └── requirements.txt
```

## Getting Started

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your config

# Start PostgreSQL
docker-compose up -d db

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload
```

API available at `http://localhost:8000/docs`

### iOS App Setup

1. Open `daftar.xcodeproj` in Xcode
2. Update API URL in `Core/API/APIClient.swift` if needed
3. Build and run

## API Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| **Auth** | | |
| POST | `/auth/store/register` | Register store |
| POST | `/auth/store/login` | Store login |
| POST | `/auth/customer/register` | Register customer |
| POST | `/auth/customer/login` | Customer login |
| **Store** | | |
| GET | `/store/ledger` | List customers who owe |
| GET | `/store/customers/{id}/bills` | Get customer's bills |
| POST | `/store/customers` | Add customer |
| **Customer** | | |
| GET | `/customer/ledger` | List stores I owe |
| GET | `/customer/stores/{id}/bills` | Get bills from store |
| POST | `/customer/join` | Join store by code |
| **Bills** | | |
| POST | `/bills` | Create bill |
| PATCH | `/bills/{id}` | Update status |
| **OCR** | | |
| POST | `/upload` | Upload image |
| POST | `/ocr/receipt` | Process receipt |

## User Flows

### Store: Add Bill (2 taps)
1. Tap camera button
2. Photo receipt → OCR extracts items → Select customer → Done

### Store: Add Bill Manually (3 taps)
1. Tap customer
2. Tap +
3. Add items → Save

### Customer: View Bill (2 taps)
1. Tap store
2. Tap bill to expand

## Environment Variables

```env
DATABASE_URL=postgresql+asyncpg://...
JWT_SECRET_KEY=your-secret
OPENAI_API_KEY=sk-...
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_BUCKET_NAME=daftar-receipts
```

## Business Model

- **Free for stores** - No monthly fees, no transaction fees
- **Free for customers** - Easy adoption
- **Value-first approach** - Make the app indispensable before monetization
- **Future revenue** (ecosystem-driven):
  - Brand promotions and sponsored content
  - Lending partnerships with banks
  - Optional customer convenience fees

## App Store Distribution

The app is ready for App Store submission:

- **iOS 17.0+** minimum deployment target
- **Bundle ID**: Durra.daftar
- **Category**: Finance
- **Localization**: English and Arabic
- **Light/Dark mode** support
- **No required permissions** - Pure SwiftUI, no camera/location access

## Current Features

- [x] Store & Customer dual-user system
- [x] Quick bill entry with number pad
- [x] Detailed itemized bills
- [x] WhatsApp bill sharing
- [x] WhatsApp statement sharing
- [x] Smart "Who to Chase" reminders
- [x] Store analytics dashboard
- [x] PDF/CSV ledger export
- [x] Store discovery for customers
- [x] Staff & branch management (UI)
- [x] Onboarding for new users
- [x] Light/Dark/System appearance modes
- [x] Full Arabic localization

## Roadmap

- [ ] Push notifications
- [ ] In-app payments
- [ ] Product catalog with images
- [ ] Android app

## License

Proprietary - All rights reserved

## Contact

For questions, contact the development team.
