Write-Host "====================================="
Write-Host "Branch Pull setup Started."
Write-Host "====================================="
Write-Host "====================================="
# $BRANCH_NAME = "main"
# # $BRANCH_NAME = "codex/propose-production-ready-architecture-for-app"
# # $BRANCH_NAME = "codex/add-log-earn-dashboard"

# git fetch origin
# git checkout $BRANCH_NAME
# git pull origin $BRANCH_NAME
Write-Host "====================================="
Write-Host "Branch Pull setup completed."
Write-Host "====================================="

Write-Host "====================================="
Write-Host "Environment setup Started."
Write-Host "====================================="

function Stop-ProcessIfRunning {
    param([Parameter(Mandatory = $true)] [string]$ImageName)

    taskkill /F /IM $ImageName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[ok] stopped $ImageName"
    }
}

function Remove-GeneratedPath {
    param([Parameter(Mandatory = $true)] [string]$Path)

    $resolvedRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
    $target = Join-Path $PSScriptRoot $Path
    if (-not (Test-Path -LiteralPath $target)) {
        return
    }

    $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
    if (-not $resolvedTarget.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside repository: $resolvedTarget"
    }

    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    Write-Host "[ok] removed generated path $Path"
}

Stop-ProcessIfRunning "momentum.exe"
Stop-ProcessIfRunning "flutter_tester.exe"
Stop-ProcessIfRunning "dart.exe"

if (Test-Path -LiteralPath ".\android\gradlew.bat") {
    Push-Location ".\android"
    try {
        .\gradlew.bat --stop
    }
    finally {
        Pop-Location
    }
}

Remove-GeneratedPath "build"
Remove-GeneratedPath ".dart_tool"
Remove-GeneratedPath "android\.gradle"
Remove-GeneratedPath "android\.kotlin"

flutter clean
flutter pub get
# flutter analyze   # Flutter SDK is not installed in this environment (flutter: command not found).
# flutter test      # Flutter SDK is not installed in this environment (flutter: command not found).

Write-Host ""
Write-Host "====================================="
Write-Host "Environment setup completed."
Write-Host "====================================="
Write-Host "Application Running"
flutter config --enable-windows-desktop
flutter config --enable-web
flutter create .
flutter run -d windows

# Default build for easy installation with Play Protect
# flutter build apk --release --flavor safe
