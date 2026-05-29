# FS-Hub Testing

| Document | Description |
|----------|-------------|
| [TESTING_STRATEGY.md](./TESTING_STRATEGY.md) | Full enterprise testing architecture (layers, CI, coverage, roadmap) |

## Run all tests

```bash
# Unit tests (no Docker)
cd backend && dart test test/unit
cd .. && flutter test
cd ai-service && pip install -r requirements-dev.txt && pytest tests/ -q

# Integration tests (Docker Desktop + MySQL + Redis)
# From repo root (PowerShell):
.\scripts\run-integration-tests.ps1

# Or manually:
docker compose -f docker-compose.test.yml up -d
cd backend
$env:RUN_INTEGRATION_TESTS="true"; $env:DB_PORT="3307"; $env:REDIS_PORT="6380"
dart test --tags integration --concurrency=1
```

Integration tests use `RuntimeConfig` overrides (not `Platform.environment` mutation) and `test/integration/.env.integration` for DB `fs_hub_test` on port **3307**.

If MySQL was created before `mysql_native_password` was added to `docker-compose.test.yml`, either recreate the test DB container or set `$env:DB_SECURE="true"` when running tests locally.

## Flutter E2E (`integration_test/`)

Offline validation (no backend):

```bash
flutter test integration_test/login_validation_test.dart
```

Full login E2E (backend on port 8080 + test DB):

```powershell
.\scripts\run-e2e-tests.ps1
```

Or:

```bash
cd backend && dart run bin/server.dart   # separate terminal
flutter test integration_test --dart-define=RUN_E2E_TESTS=true --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

## Chat / WebSocket tests (Phase 5)

```bash
flutter test test/unit/chat_ws_event_parser_test.dart test/unit/chat_controller_test.dart
cd backend && dart test test/unit/chat
# Integration (with MySQL):
cd backend && dart test test/integration/ws_ticket_integration_test.dart --tags integration
```

## Coverage (Codecov)

CI job `coverage` uploads LCOV/XML to Codecov (optional `CODECOV_TOKEN` secret). Local:

```bash
cd backend && dart test --coverage=coverage test/unit && dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
flutter test --coverage
cd ai-service && pytest tests/ --cov=app --cov-report=term-missing
```
