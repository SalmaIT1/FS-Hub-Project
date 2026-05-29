# Arrête la stack FS-Hub lancée par start-dev.ps1
param(
    [int]$BackendPort = 8080,
    [int]$AiPort = 8001
)

$Root = Split-Path $PSScriptRoot -Parent
$PidFile = Join-Path $Root ".dev\pids.json"

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
            Write-Host "[dev] Arrêt PID $_ (port $port)"
        }
    }
}

if (Test-Path $PidFile) {
    $pids = Get-Content $PidFile | ConvertFrom-Json
    $pids.PSObject.Properties | ForEach-Object {
        $id = [int]$_.Value
        if ($id -gt 0) {
            Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
            Write-Host "[dev] Arrêt $($_.Name) (PID $id)"
        }
    }
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

Stop-PortListener $BackendPort
Stop-PortListener $AiPort
Stop-PortListener 4040

Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "[dev] Stack arrêtée." -ForegroundColor Green
