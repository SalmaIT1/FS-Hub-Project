# FS-Hub — Enterprise Testing Strategy

> **Stack:** Flutter (Provider) · Dart Shelf backend · FastAPI AI service · MySQL · Redis · JWT/RBAC · WebSocket

This document defines the **complete testing architecture** for FS-Hub. Implemented sample tests live under `backend/test/`, `test/`, and `ai-service/tests/`.

---

## 1. Global Testing Strategy

### Testing layers (pyramid)

| Layer | Scope | Tools | FS-Hub target |
|-------|--------|-------|----------------|
| **Unit** | Pure logic, validators, middleware with faked context | `test`, `flutter_test`, `pytest` | Domain rules, RBAC, JWT, heuristics |
| **Widget** | UI components, forms, guards | `flutter_test` | Login, dashboards (mocked Provider) |
| **Integration** | HTTP routes + DB/Redis | `shelf` test harness, Testcontainers (future) | Auth login, invoice create, leave flow |
| **E2E** | Full user journeys | `integration_test` | Login → project → task (Phase 3) |

### Philosophy

1. **Test behavior, not implementation** — assert HTTP status, JSON shape, and business outcomes.
2. **Pure domain first** — extract rules from services (`InvoiceBusinessRules`, `LeaveBusinessRules`) so finance/HR/security logic is testable without MySQL.
3. **Fail closed on security** — auth middleware, revoked tokens, RBAC 403s are mandatory high-coverage paths.
4. **No flaky network in unit tests** — mock HTTP at repository boundary; reserve real API for integration job.

### Mocking strategy

| Dependency | Unit test approach |
|------------|-------------------|
| MySQL | `mocktail` fake repositories; never hit DB in unit job |
| Redis | Inject `RedisService` interface or skip in unit (integration only) |
| `AuthService` / JWT | `initSecretForTests()` + in-memory tickets |
| Flutter `http` | `MockClient` / override `ApiService` (Phase 2) |
| AI model files | Test heuristic engine; mock `registry.get_engine` for ML path |

### Isolation

- Each test file resets static state (`PermissionGuard.resetForTest()`).
- Backend middleware tests use `authenticatedRequest()` — no full pipeline.
- AI tests set env **before** `from main import app` in `conftest.py`.

### Dependency injection (roadmap)

Current services use static singletons (`FinanceService`, `AuthService`). **Phase 2** introduces constructor injection for repositories to enable `mocktail` fakes without refactoring handlers.

---

## 2. Backend Unit Tests (Dart + Shelf)

### Folder structure

```
backend/
├── lib/shared/domain/          # Pure business rules (NEW)
│   ├── credit_score_calculator.dart
│   ├── invoice_business_rules.dart
│   ├── leave_business_rules.dart
│   ├── project_financial_rules.dart
│   ├── task_workflow_rules.dart
│   └── project_status.dart
└── test/
    ├── fixtures/
    │   └── auth_fixtures.dart
    ├── helpers/
    │   └── shelf_request_factory.dart
    ├── mocks/
    │   └── repository_mocks.dart
    └── unit/
        ├── auth/
        │   ├── auth_tickets_test.dart
        │   ├── jwt_verify_test.dart
        │   └── password_complexity_test.dart
        ├── domain/
        │   ├── credit_score_calculator_test.dart
        │   ├── invoice_business_rules_test.dart
        │   ├── leave_business_rules_test.dart
        │   ├── project_financial_rules_test.dart
        │   ├── project_status_test.dart
        │   └── task_workflow_rules_test.dart
        ├── middleware/
        │   └── permission_middleware_test.dart
        └── services/
            ├── auth_service_login_test.dart
            ├── finance_service_test.dart
            └── hr_service_test.dart
```

### Repository ports & test injection (Phase 2)

| Port | Production impl | Service hook |
|------|-----------------|--------------|
| `FinanceRepositoryPort` | `FinanceRepository` | `FinanceService.bindForTest(finance:, project:)` |
| `ProjectRepositoryPort` | `ProjectRepository` | same |
| `HrRepositoryPort` | `HrRepository` | `HrService.bindForTest(hr:)` |
| `AuthRepositoryPort` | `AuthRepository` | `AuthService.bindForTest(auth:)` |

Mocks live in `test/mocks/repository_mocks.dart`. Always call `resetBindings()` in `tearDown` to clear overrides (no DB required).

### Naming conventions

- Files: `{subject}_test.dart`
- Groups: `group('ClassName — workflow', () { ... })`
- Cases: `test('expected behavior when condition', () { ... })`

### Run

```bash
cd backend && dart pub get && dart test
```

### Example scenarios (implemented)

| Workflow | Test file | What is verified |
|----------|-----------|------------------|
| Login / password reset | `password_complexity_test.dart` | Weak passwords rejected |
| JWT | `jwt_verify_test.dart` | Valid, expired, tampered tokens |
| RBAC | `permission_middleware_test.dart` | 401/403/Admin bypass/finance roles |
| Create invoice | `invoice_business_rules_test.dart` | Timbre, TTC, quote approval |
| Create leave | `leave_business_rules_test.dart` | Overlap, quota, self-approval |
| Assign task | `task_workflow_rules_test.dart` | Status FSM, membership |
| Payment / credit | `credit_score_calculator_test.dart` | Score bands, clamping |
| Project workflow | `project_status_test.dart` | ENUM normalization |

### Edge cases to add (integration phase)

- Expired Bearer → 401 `Invalid or expired token`
- Revoked token → 401 `Token revoked`
- Duplicate `X-Idempotency-Key` → cached 200 + `X-Idempotency-Cache: HIT`
- Rate limit on `/v1/auth/login` → 429

---

## 3. Frontend Unit & Widget Tests (Flutter)

### Folder structure

```
test/
├── fixtures/
│   └── auth_fixtures.dart
├── unit/
│   ├── permission_guard_test.dart
│   ├── project_status_test.dart
│   ├── financial_rules_test.dart
│   └── login_validators_test.dart
├── widget/
│   └── login_page_test.dart
└── widget_test.dart              # smoke
```

### State management

- **Provider** for `SettingsController`, `ChatController`.
- Widget tests wrap with `ChangeNotifierProvider` (see `login_page_test.dart`).
- `PermissionGuard.seedForTest()` avoids real `AuthService` HTTP.

### Run

```bash
flutter pub get && flutter test
```

### Roadmap

| Area | Approach |
|------|----------|
| Chat WebSocket | `FakeWebSocketChannel`, pump event, assert message list |
| Dashboard loading | Mock `AIService` returning delayed `Future` |
| Golden tests | `golden_toolkit` for `GlassNavBar` (optional) |
| `integration_test/` | Login E2E on emulator (CI macOS job) |

---

## 4. AI Service Tests (FastAPI)

### Structure

```
ai-service/
├── requirements-dev.txt    # pytest, httpx<0.28 (Starlette compat)
└── tests/
    ├── conftest.py
    ├── test_smoke.py           # HeuristicEngine unit
    ├── test_api_auth.py        # X-API-Key 403/200
    ├── test_api_predictions.py # v1 endpoints
    └── test_schemas.py         # Pydantic validation
```

### Run

```bash
cd ai-service
pip install -r requirements-dev.txt
export AI_ALLOW_DEV_KEY=true AI_API_KEY=test-key
pytest tests/ -q
```

### Coverage

- Prediction confidence bounds (`delay_probability` ∈ [0,1])
- Malformed JSON → 422
- Missing `X-API-Key` → 403
- Expense anomalies via `/v1/detect/expense-anomalies`

---

## 5. Mocking & Test Data

### Fixtures location

| Layer | Path |
|-------|------|
| Backend RBAC | `backend/test/fixtures/auth_fixtures.dart` |
| Flutter RBAC | `test/fixtures/auth_fixtures.dart` |
| AI env | `ai-service/tests/conftest.py` |

### Fake JWT (backend tests)

```dart
AuthService.initSecretForTests('test-jwt-secret-for-unit-tests-only-32chars');
final token = JWT({'userId': 'u1', 'role': 'Admin', 'exp': ...}).sign(SecretKey(secret));
```

### Sample datasets

- **Users:** Admin, Manager, Employé with permission lists in `AuthFixtures`
- **Invoice:** HT=1000, TVA=190, timbre=1, TTC=1191
- **Leave:** overlapping 2026-06-10..15 vs request 2026-06-12..14
- **AI delay:** 20 tasks, 8 done, 5 delayed → HIGH/CRITICAL band

---

## 6. Business Rule Testing

### A. Finance

| Rule | Implementation | Test |
|------|----------------|------|
| Timbre mandatory on INVOICE | `InvoiceBusinessRules.validateTimbreForType` | `invoice_business_rules_test.dart` |
| TTC = HT + TVA + timbre | `isTtcConsistent` | same |
| Quote approved before invoice | `validateQuoteApproved` | same |
| Project start after deposit | `ProjectFinancialRules.canStartProject` | `project_financial_rules_test.dart` |
| Client credit score | `CreditScoreCalculator` | `credit_score_calculator_test.dart` |

### B. RH

| Rule | Test |
|------|------|
| Leave overlap | `leave_business_rules_test.dart` |
| Paid quota | same |
| Self-approval blocked | same |

### C. Projects

| Rule | Test |
|------|------|
| Status ENUM / legacy map | `project_status_test.dart` (backend + Flutter) |
| Task status FSM | `task_workflow_rules_test.dart` |
| Sprint/deadline | extend `TaskWorkflowRules.isValidDeadline` |

### D. Security

| Rule | Test |
|------|------|
| `requirePermission` 403 | `permission_middleware_test.dart` |
| Admin bypass | same |
| Finance role gate | `requireRoleOrPermission` |
| Route guard (Flutter) | `permission_guard_test.dart` |
| AI API key | `test_api_auth.py` |

---

## 7. Test Coverage Strategy

### Targets

| Module | Line coverage target | Rationale |
|--------|---------------------|-----------|
| `shared/domain/*` | **≥ 90%** | Pure business rules |
| `core/middleware/*` | **≥ 85%** | Security surface |
| `auth/domain/services` | **≥ 80%** | Tokens, passwords |
| Feature services | **≥ 60%** | After repository mocks |
| Flutter `core/security` | **≥ 80%** | PermissionGuard |
| UI screens | **≥ 40%** | Widget smoke + critical forms |
| AI `app/ml/heuristic` | **≥ 85%** | Prediction contracts |

### Can stay lightly tested

- Email templates, migration SQL strings, generated assets
- One-off admin scripts, UML docs

### Mutation testing (Phase 4)

Run `stryker`/`mutmut` on `InvoiceBusinessRules` and `CreditScoreCalculator` — aim to kill >75% mutants before release.

---

## 8. CI/CD Test Automation

See `.github/workflows/ci-cd.yml`:

1. `flutter analyze` + `dart analyze`
2. `pytest tests/` (AI, `requirements-dev.txt`)
3. `dart test` (backend) — **must pass** (no `|| echo` fallback)
4. `flutter test` — **must pass**
5. Docker build only if tests green

### Failing pipeline conditions

- Any test failure
- Analyzer error (warning policy: tighten over time)
- Coverage drop below threshold (when `coverage` job added)

### Pre-commit (recommended)

```yaml
# .pre-commit-config.yaml (add locally)
- repo: local
  hooks:
    - id: backend-test
      name: dart test
      entry: bash -c 'cd backend && dart test'
      language: system
```

---

## 9. Error Detection & Debugging

| Problem | Mitigation |
|---------|------------|
| **Flaky tests** | No `Future.delayed` without `fake_async`; seed random; avoid wall-clock |
| **Async failures** | `await` every handler; use `response.readAsString()` once |
| **WebSocket timing** | Deterministic fake channel; don't assert on connection order |
| **Race conditions** | Serial integration tests per DB schema; use transactions |
| **State sync bugs** | `tearDown` resets static guards; unique idempotency keys per test |

### Debug commands

```bash
dart test --chain-stack-traces -r expanded
flutter test --plain-name "PermissionGuard"
pytest tests/test_api_auth.py -vv
```

---

## 10. Implementation Roadmap

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **1 — Foundation** ✅ | Done | Domain rules, 41 backend + 17 Flutter + 17 AI tests, this doc |
| **2 — Repository mocks** ✅ | Done | Ports + `bindForTest` + service tests (login, invoice, leave) |
| **3 — Integration** ✅ | Done | `HttpApp` + in-process Shelf tests; MySQL/Redis via CI services + `docker-compose.test.yml` |
| **4 — E2E & coverage** ✅ | Done | `integration_test/`, CI `flutter_e2e` + `coverage` jobs, `codecov.yml` |
| **5 — WebSocket & chat** ✅ | Done | `ChatWsEventParser`, `ChatController` tests, WS ticket unit + integration |

### Conventions checklist

- [ ] New business rule → add to `lib/shared/domain/` + unit test
- [ ] New permission → update `AuthFixtures` + middleware test + `PermissionGuard` route map
- [ ] New API route → AI schema test + backend integration test
- [ ] PR blocked if `dart test` / `flutter test` / `pytest` fail

---

## Quick reference

```bash
# All unit tests
cd backend && dart test
cd .. && flutter test
cd ai-service && pytest tests/ -q
```

### Integration tests (Phase 3)

```
backend/test/integration/
├── integration_config.dart
├── integration_harness.dart
├── health_integration_test.dart
├── auth_login_integration_test.dart
├── finance_invoice_integration_test.dart
├── hr_leave_integration_test.dart
└── idempotency_integration_test.dart
```

**Local run:**

```bash
docker compose -f docker-compose.test.yml up -d
cd backend
set RUN_INTEGRATION_TESTS=true
set DB_PORT=3307
set REDIS_PORT=6380
dart test --tags integration
```

**CI:** job `backend_integration` with GitHub Actions MySQL + Redis services.

**Total implemented tests:** 59 backend unit · ~13 backend integration · 17 Flutter unit/widget · 2+ Flutter E2E · 17 AI

### Flutter E2E (Phase 4)

```
integration_test/
├── support/
│   ├── e2e_config.dart
│   ├── e2e_app.dart
│   └── e2e_auth.dart
├── login_validation_test.dart   # always runnable
└── login_api_e2e_test.dart      # RUN_E2E_TESTS=true + live backend
```

**CI:** `flutter_e2e` starts Shelf on :8080 with MySQL/Redis, then `flutter test integration_test`.

### WebSocket & chat (Phase 5)

```
lib/features/chat/data/datasources/chat_ws_event_parser.dart
test/unit/chat_ws_event_parser_test.dart
test/unit/chat_controller_test.dart
test/mocks/chat_mocks.dart
backend/test/unit/chat/websocket_auth_test.dart
backend/test/integration/ws_ticket_integration_test.dart
```

**Run:**

```bash
flutter test test/unit/chat_ws_event_parser_test.dart test/unit/chat_controller_test.dart
cd backend && dart test test/unit/chat
```

---

## Architecture globale du pipeline

L'architecture du pipeline FS-Hub est conçue pour garantir une montée en qualité progressive, depuis le développement local jusqu'à la production. Elle combine des analyses statiques, des tests unitaires/Widget/interopérables, des tests d'intégration, des tests E2E et des builds conditionnels.

### Schéma du pipeline

```text
Développement local
      │
      ▼
Analyse statique
      │
      ▼
Tests unitaires
      │
      ▼
Tests d'intégration
      │
      ▼
Tests E2E
      │
      ▼
Build Docker / Publication conditionnelle
```

### 1. Étapes principales

1. Analyse statique
   - `flutter analyze` pour le frontend Flutter
   - `dart analyze` pour le backend Shelf
   - `pylint` / `mypy` ou équivalent pour `ai-service` si applicable

2. Tests unitaires
   - `flutter test` pour les règles, validateurs et widgets critiques
   - `dart test` pour la logique backend, RBAC, JWT, services métier
   - `pytest` pour les routes AI, schémas Pydantic et logique heuristique

3. Tests d'intégration
   - Backend Shelf en-tête via `docker-compose.test.yml` (MySQL + Redis)
   - Tests d'intégration backend marqués `--tags integration`
   - Exécution d'un backend de test in-process pour valider la chaîne complète route → DB/Redis

4. Tests E2E
   - `integration_test` Flutter sur simulateur/emulateur
   - Parcours utilisateur complet : connexion, navigation, actions métier
   - Dépendance à un backend live configuré pour l'environnement d'E2E

5. Build et publication conditionnelle
   - Construction des images Docker si toutes les étapes précédentes sont validées
   - Déploiement ou packaging déclenché seulement après succès des tests

### 2. Flux de données et composants

- Code source Flutter (`lib/`, `test/`) → analyse statique + tests widget/ unité
- Backend Dart (`backend/lib/`, `backend/test/`) → tests unitaires et d'intégration
- AI service Python (`ai-service/`) → tests Pytest de l’API et des schémas
- `docker-compose.test.yml` orchestre MySQL/Redis pour la validation d’intégration
- `backend` et `ai-service` exposent des endpoints sécurisés et testés par clé API / JWT

### 3. Principe “shift-left”

- Les règles métier pures sont isolées dans des modules testables sans dépendances externes
- Les tests unitaires sont prioritaires pour attraper les régressions tôt
- Les tests d’intégration vérifient la cohérence entre le code métier et les services comme MySQL ou Redis
- Les E2E valident le parcours utilisateur complet avec des conditions proches de la production

### 4. CI/CD et gating

- Le pipeline CI exécute d’abord l’analyse statique et les tests unitaires
- Si ces étapes réussissent, il lance les tests d’intégration puis les E2E selon le job
- Les builds Docker sont bloqués tant que le pipeline échoue sur une étape critique
- Les retours sont configurés pour échouer rapidement sur les erreurs de sécurité ou de tests

### 5. Résilience et débogage

- Logs détaillés lors d’échec de tests d’intégration et E2E
- Une étape de rollback ou stop est prévue si des tests de sécurité ou d’authentification échouent
- Les tests isolés `backend/test/`, `test/` et `ai-service/tests/` peuvent être exécutés localement pour reproduire rapidement un échec
