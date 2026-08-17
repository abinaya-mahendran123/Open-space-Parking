# One command: start Mongo/API if needed, USB-forward port 3000, run Flutter on phone.
# Usage (from repo root):
#   .\run_android_device.ps1
#   .\run_android_device.ps1 -DeviceId 10BCC31CBU001QY

param(
  [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$backend = Join-Path $root "backend"

function Test-ApiHealth {
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:3000/api/health" -TimeoutSec 2 -UseBasicParsing
    return $r.StatusCode -eq 200
  } catch {
    return $false
  }
}

if (-not (Test-ApiHealth)) {
  Write-Host "Backend not running — starting Mongo + API..."
  Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c", "cd /d `"$backend`" && npm start" `
    -WindowStyle Minimized

  $deadline = (Get-Date).AddSeconds(60)
  do {
    Start-Sleep -Seconds 2
    if (Test-ApiHealth) { break }
  } while ((Get-Date) -lt $deadline)

  if (-not (Test-ApiHealth)) {
    Write-Error "API did not become ready on http://127.0.0.1:3000. Check the minimized backend window."
  }
  Write-Host "Backend is up."
} else {
  Write-Host "Backend already running."
}

$lanIp = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*' } |
  Where-Object { $_.IPAddress -notlike '127.*' } |
  Select-Object -First 1 -ExpandProperty IPAddress)

if (-not $lanIp) {
  Write-Error "Could not detect LAN IP."
}

# Prefer USB reverse so 127.0.0.1 on the phone tunnels to this PC.
# Also pass the current Wi-Fi IP so the app works without the USB cable.
$apiUrl = "http://127.0.0.1:3000"
Write-Host "Using BASE_API_URL=$apiUrl (via adb reverse -> this PC)"
Write-Host "Using HOST_LAN_IP=$lanIp (Wi-Fi fallback)"

if ($DeviceId) {
  adb -s $DeviceId reverse tcp:3000 tcp:3000 | Out-Null
} else {
  adb reverse tcp:3000 tcp:3000 | Out-Null
}

$flutterArgs = @(
  "run",
  "--dart-define=BASE_API_URL=$apiUrl",
  "--dart-define=HOST_LAN_IP=$lanIp",
  "--android-skip-build-dependency-validation"
)
if ($DeviceId) {
  $flutterArgs += @("-d", $DeviceId)
}

flutter @flutterArgs
