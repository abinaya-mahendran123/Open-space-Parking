$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot

function Clear-LockedPath {
    param([string]$RelativePath)

    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return
    }

    Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Attributes = 'Normal' }
    Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
}

# Web and Android folders often stay locked on Windows / OneDrive.
Clear-LockedPath 'build\flutter_assets'
Clear-LockedPath 'build\app\intermediates\assets\debug\mergeDebugAssets'
Clear-LockedPath 'build\app\intermediates\merged_native_libs'

exit 0
