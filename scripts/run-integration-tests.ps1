# FS-Hub backend integration tests (MySQL + Redis via Docker)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "Starting test containers..."
docker compose -f "$Root\docker-compose.test.yml" up -d

Write-Host "Waiting for MySQL..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
  docker compose -f "$Root\docker-compose.test.yml" exec -T mysql-test mysqladmin ping -h localhost -ptest 2>$null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $ready) {
  Write-Error "MySQL did not become ready in time. Is Docker Desktop running?"
}

Push-Location "$Root\backend"
$env:RUN_INTEGRATION_TESTS = "true"
$env:DB_PORT = "3307"
$env:REDIS_PORT = "6380"

Write-Host "Running integration tests..."
dart test --tags integration --concurrency=1
$code = $LASTEXITCODE
Pop-Location
exit $code
