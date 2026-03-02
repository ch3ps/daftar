#!/bin/sh
set -e

# Write Firebase credentials from env var if provided
if [ -n "$FIREBASE_CREDENTIALS_JSON" ]; then
  echo "$FIREBASE_CREDENTIALS_JSON" > /app/firebase-credentials.json
  echo "[start] Firebase credentials written"
fi

# Run database migrations
echo "[start] Running database migrations..."
alembic upgrade head
echo "[start] Migrations done"

# Start the server on Railway's PORT (defaults to 8000 locally)
PORT="${PORT:-8000}"
echo "[start] Starting server on port $PORT"
exec uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
