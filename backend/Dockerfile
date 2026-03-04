# Daftar Backend Dockerfile

FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose default port (Railway injects PORT at runtime)
EXPOSE 8000

# Run startup sequence:
# 1) write Firebase credentials file when provided
# 2) run Alembic migrations
# 3) start API server on Railway PORT
CMD ["/bin/sh", "-c", "if [ -n \"$FIREBASE_CREDENTIALS_JSON\" ]; then echo \"$FIREBASE_CREDENTIALS_JSON\" > /app/firebase-credentials.json; fi && alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
