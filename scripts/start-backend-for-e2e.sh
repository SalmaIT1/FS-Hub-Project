#!/usr/bin/env bash
# Start Shelf backend for Flutter E2E (CI / local). Waits for /healthz.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/backend"

export PORT="${PORT:-8080}"
export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-3306}"
export DB_USER="${DB_USER:-root}"
export DB_PASSWORD="${DB_PASSWORD:-test}"
export DB_NAME="${DB_NAME:-fs_hub_test}"
export DB_SECURE="${DB_SECURE:-false}"
export REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
export REDIS_PORT="${REDIS_PORT:-6379}"
export JWT_SECRET="${JWT_SECRET:-e2e-jwt-secret-min-32-characters-long}"
export DISABLE_RATE_LIMIT="${DISABLE_RATE_LIMIT:-true}"

dart run bin/server.dart &
SERVER_PID=$!
echo "$SERVER_PID" > /tmp/fs_hub_e2e_server.pid

for i in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:${PORT}/healthz" >/dev/null; then
    echo "Backend ready on port ${PORT} (pid ${SERVER_PID})"
    exit 0
  fi
  sleep 2
done

echo "Backend failed to become healthy"
kill "$SERVER_PID" 2>/dev/null || true
exit 1
