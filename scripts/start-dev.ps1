# FS-Hub - demarre backend, ai-service, ngrok et (optionnel) Flutter en une commande.
# Usage:
#   .\scripts\start-dev.ps1
#   .\scripts\start-dev.ps1 -Device D6NRSGV4IVAMIJTC
#   .\scripts\start-dev.ps1 -Emulator          # API = http://10.0.2.2:8080, sans ngrok
#   .\scripts\start-dev.ps1 -ServicesOnly      # pas de Flutter
#   .\scripts\start-dev.ps1 -StopFirst         # libere les ports avant de demarrer

param(
    [string]$Device = "",
    [switch]$Emulator,
    [switch]$ServicesOnly,
    [switch]$StopFirst,
    [switch]$NoNgrok,
    [int]$BackendPort = 8080,
    [int]$AiPort = 8001
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$DevDir = Join-Path $Root ".dev"
$LogDir = Join-Path $DevDir "logs"
$PidFile = Join-Path $DevDir "pids.json"
$BackendDir = Join-Path $Root "backend"
$AiDir = Join-Path $Root "ai-service"

function Write-Dev($msg, $color = "Cyan") {
    Write-Host "[dev] $msg" -ForegroundColor $color
}

function Ensure-DevDir {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

function Read-DotEnvValue($path, $key) {
    if (-not (Test-Path $path)) { return $null }
    Get-Content $path | ForEach-Object {
        if ($_ -match "^\s*$key\s*=\s*(.+)\s*$") {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

function Sync-AiEnv {
    $backendEnv = Join-Path $BackendDir ".env"
    $aiEnv = Join-Path $AiDir ".env"
    $aiExample = Join-Path $AiDir ".env.example"
    $key = Read-DotEnvValue $backendEnv "AI_API_KEY"
    if (-not $key) {
        $key = Read-DotEnvValue (Join-Path $Root ".env") "AI_API_KEY"
    }
    if (-not (Test-Path $aiEnv)) {
        if (Test-Path $aiExample) {
            Copy-Item $aiExample $aiEnv
            Write-Dev "Cree ai-service/.env depuis .env.example"
        } else {
            Set-Content $aiEnv "AI_API_KEY=dev-ai-key-change-me`nAI_ALLOW_DEV_KEY=true`n"
        }
    }
    if ($key) {
        $content = Get-Content $aiEnv -Raw
        if ($content -match "^\s*AI_API_KEY\s*=") {
            $content = $content -replace "^\s*AI_API_KEY\s*=.*", "AI_API_KEY=$key"
        } else {
            $content = "AI_API_KEY=$key`n" + $content
        }
        Set-Content $aiEnv $content.TrimEnd() -NoNewline
        Add-Content $aiEnv "`n"
    }
}

function Get-PythonExe {
    $venvPy = Join-Path $AiDir "venv\Scripts\python.exe"
    if (Test-Path $venvPy) { return $venvPy }
    return "python"
}

function Stop-PortListener($port) {
    $pids = @()
    try {
        $pids = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -Unique
    } catch {
        netstat -ano | Select-String ":$port\s" | ForEach-Object {
            if ($_ -match '\s+(\d+)\s*$') { $pids += [int]$Matches[1] }
        }
    }
    $pids | Select-Object -Unique | ForEach-Object {
        if ($_ -gt 0) {
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        }
    }
}

function Wait-HttpOk($url, $label, $maxSeconds = 90) {
    $deadline = (Get-Date).AddSeconds($maxSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) {
                Write-Dev "$label OK ($url)" "Green"
                return $true
            }
        } catch { }
        Start-Sleep -Seconds 2
    }
    Write-Dev "$label pas pret apres ${maxSeconds}s ($url)" "Yellow"
    return $false
}

function Get-NgrokHttpsUrl {
    $deadline = (Get-Date).AddSeconds(45)
    while ((Get-Date) -lt $deadline) {
        try {
            $api = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 3
            $tunnel = $api.tunnels | Where-Object { $_.public_url -like "https://*" } | Select-Object -First 1
            if ($tunnel.public_url) { return $tunnel.public_url.TrimEnd('/') }
        } catch { }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Get-FlutterDevicesMachine {
    $list = @()
    $raw = flutter devices --machine 2>$null
    if (-not $raw) { return $list }
    foreach ($line in $raw) {
        $t = $line.Trim()
        if (-not $t) { continue }
        try { $list += ($t | ConvertFrom-Json) } catch { }
    }
    return $list
}

function Get-FlutterDeviceId {
    if ($Device) { return $Device }

    $all = Get-FlutterDevicesMachine
    if ($all.Count -eq 0) { return $null }

    $supported = @($all | Where-Object { $_.isSupported -and $_.targetPlatform -ne "web" })
    if ($Emulator) {
        $emu = @($supported | Where-Object { $_.emulator -eq $true })
        if ($emu.Count -ge 1) { return $emu[0].id }
    }

    $physical = @($supported | Where-Object { $_.emulator -eq $false })
    if ($physical.Count -ge 1) {
        $android = $physical | Where-Object { $_.targetPlatform -eq "android" } | Select-Object -First 1
        if ($android) { return $android.id }
        return $physical[0].id
    }

    if ($supported.Count -ge 1) { return $supported[0].id }
    return $null
}

function Show-FlutterDevices {
    Write-Dev "Appareils Flutter detectes :" "Yellow"
    flutter devices 2>$null | ForEach-Object { Write-Host "  $_" }
}

function Start-DevProcess($name, $workDir, $command, $logName) {
    $logPath = Join-Path $LogDir "$logName.log"
    $proc = Start-Process -FilePath "powershell" -WorkingDirectory $workDir -PassThru -WindowStyle Minimized `
        -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
            "`$host.UI.RawUI.WindowTitle = 'FS-Hub: $name'; $command 2>&1 | Tee-Object -FilePath '$logPath'"
        )
    return @{ name = $name; id = $proc.Id; log = $logPath }
}

# --- main ---
Ensure-DevDir
if ($StopFirst) {
    Write-Dev "Arret des processus sur les ports $BackendPort et $AiPort"
    Stop-PortListener $BackendPort
    Stop-PortListener $AiPort
    if (Test-Path $PidFile) {
        (Get-Content $PidFile | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
            Stop-Process -Id ([int]$_.Value) -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

Sync-AiEnv

$py = Get-PythonExe
Write-Dev "Demarrage ai-service (port $AiPort)"
$aiProc = Start-DevProcess "ai-service" $AiDir "& '$py' -m uvicorn main:app --host 127.0.0.1 --port $AiPort" "ai-service"

Write-Dev "Demarrage backend (port $BackendPort)"
$beProc = Start-DevProcess "backend" $BackendDir "dart run bin/server.dart" "backend"

$pids = @{
    ai_service = $aiProc.id
    backend    = $beProc.id
}

Wait-HttpOk "http://127.0.0.1:$AiPort/health" "AI service" 60 | Out-Null
Wait-HttpOk "http://127.0.0.1:$BackendPort/healthz" "Backend" 90 | Out-Null

$apiBaseUrl = "http://127.0.0.1:$BackendPort"
if ($Emulator) {
    $apiBaseUrl = "http://10.0.2.2:$BackendPort"
    Write-Dev "Mode emulateur Android : $apiBaseUrl" "Green"
} elseif (-not $NoNgrok) {
    Write-Dev "Demarrage ngrok http $BackendPort"
    $ngProc = Start-DevProcess "ngrok" $Root "ngrok http $BackendPort" "ngrok"
    $pids.ngrok = $ngProc.id
    $public = Get-NgrokHttpsUrl
    if ($public) {
        $apiBaseUrl = $public
        Set-Content (Join-Path $DevDir "ngrok-url.txt") $public
        Write-Dev "URL publique : $public" "Green"
    } else {
        Write-Dev "ngrok URL introuvable - utilisez 127.0.0.1 ou relancez" "Yellow"
    }
}

$pids | ConvertTo-Json | Set-Content $PidFile

Write-Host ""
Write-Host "========== FS-Hub dev stack ==========" -ForegroundColor Green
Write-Host "  Backend : http://127.0.0.1:$BackendPort/healthz"
Write-Host "  AI      : http://127.0.0.1:$AiPort/health"
Write-Host "  API app : $apiBaseUrl"
Write-Host "  Logs    : $LogDir"
Write-Host "  Arret   : .\scripts\stop-dev.ps1"
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

if ($ServicesOnly) {
    Write-Dev "Services lances (-ServicesOnly). Flutter non demarre."
    Write-Dev "Commande manuelle :"
    Write-Host "  flutter run --dart-define=API_BASE_URL=$apiBaseUrl"
    exit 0
}

$flutterDevice = Get-FlutterDeviceId
if (-not $flutterDevice) {
    Write-Dev "Aucun appareil Flutter utilisable (USB debug / emulateur ?)." "Yellow"
    Show-FlutterDevices
    Write-Dev "Relancez avec l ID de votre telephone :" "Yellow"
    Write-Host ('  .\dev.ps1 -Device VOTRE_ID -StopFirst')
    Write-Host ('  flutter run -d VOTRE_ID --dart-define=API_BASE_URL=' + $apiBaseUrl)
    Write-Dev "Services toujours actifs en arriere-plan."
    exit 0
}

Write-Dev ('Lancement Flutter sur ' + $flutterDevice) "Green"
Set-Location $Root
flutter run -d $flutterDevice --dart-define=API_BASE_URL=$apiBaseUrl
