#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Starting test containers..."
docker compose -f "$ROOT/docker-compose.test.yml" up -d

echo "Waiting for MySQL..."
for i in $(seq 1 30); do
  if docker compose -f "$ROOT/docker-compose.test.yml" exec -T mysql-test mysqladmin ping -h localhost -ptest &>/dev/null; then
    break
  fi
  sleep 2
done

cd "$ROOT/backend"
export RUN_INTEGRATION_TESTS=true
export DB_PORT=3307
export REDIS_PORT=6380

echo "Running integration tests..."
dart test --tags integration --concurrency=1
