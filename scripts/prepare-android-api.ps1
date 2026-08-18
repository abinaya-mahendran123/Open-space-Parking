$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$lock = Join-Path $root 'build\app\intermediates\assets\debug\mergeDebugAssets'

if (Test-Path -LiteralPath $lock) {
    Get-ChildItem -LiteralPath $lock -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Attributes = 'Normal' }
    Remove-Item -LiteralPath $lock -Recurse -Force -ErrorAction SilentlyContinue
}

adb reverse tcp:3000 tcp:3000 2>$null | Out-Null

$ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*' } |
    Select-Object -First 1 -ExpandProperty IPAddress
if ($ip) {
    Write-Host "PC Wi-Fi IP: $ip"
}

if (-not (Test-Path env:SKIP_API_CHECK)) {
    try {
        Invoke-WebRequest -Uri http://127.0.0.1:3000/api/health -TimeoutSec 3 -UseBasicParsing | Out-Null
        Write-Host 'API ok on :3000'
    } catch {
        Write-Host 'WARNING: backend not running. In a terminal: cd backend && npm start'
    }
}

exit 0
