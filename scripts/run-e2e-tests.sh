#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Ensure backend is running on http://127.0.0.1:8080"
cd "$ROOT"
export RUN_E2E_TESTS=true
flutter test integration_test \
  --dart-define=RUN_E2E_TESTS=true \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --concurrency=1
