# Flutter E2E against a running backend (http://127.0.0.1:8080)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "Ensure backend is running (port 8080) and test DB is up."
Write-Host "Tip: .\scripts\run-integration-tests.ps1  # starts MySQL/Redis only"
Write-Host "Then: cd backend; dart run bin/server.dart"

Push-Location $Root
$env:RUN_E2E_TESTS = "true"
flutter test integration_test -d windows `
  --dart-define=RUN_E2E_TESTS=true `
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 `
  --concurrency=1
$code = $LASTEXITCODE
Pop-Location
exit $code
