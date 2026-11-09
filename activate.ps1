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

flutter test

Write-Host ""
Write-Host "====================================="
Write-Host "Testing completed."
Write-Host "====================================="
Write-Host "Application Running"


flutter config --enable-windows-desktop
flutter config --enable-web
flutter create .
flutter run -d windows

function Get-FirstFlutterEmulatorId {
    param([string[]]$Output)

    foreach ($line in $Output) {
        if ($line -match '^\s*(\S+)\s+•' -and $Matches[1] -ne 'Id') {
            return $Matches[1]
        }
    }

    return $null
}

$emulatorId = $env:ANDROID_EMULATOR_ID
if ([string]::IsNullOrWhiteSpace($emulatorId)) {
    $emulatorOutput = flutter emulators
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list Flutter emulators."
    }

    $emulatorId = Get-FirstFlutterEmulatorId -Output $emulatorOutput
}

if ([string]::IsNullOrWhiteSpace($emulatorId)) {
    Write-Host "No Android emulator is configured. Creating a Pixel emulator..."
    flutter emulators --create --name BubbleTimeAndroid
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create an Android emulator. Install Android Studio and its Android SDK, or set ANDROID_EMULATOR_ID to an existing emulator."
    }

    $emulatorOutput = flutter emulators
    if ($LASTEXITCODE -ne 0) {
        throw "Android emulator creation completed, but Flutter could not list emulators."
    }

    $emulatorId = Get-FirstFlutterEmulatorId -Output $emulatorOutput
}

if ([string]::IsNullOrWhiteSpace($emulatorId)) {
    throw "No Android emulator is available. Create one in Android Studio, or set ANDROID_EMULATOR_ID to an existing emulator."
}

Write-Host "Launching Android emulator '$emulatorId'."
flutter emulators --launch $emulatorId
if ($LASTEXITCODE -ne 0) {
    throw "Flutter could not launch Android emulator '$emulatorId'."
}

$androidDeviceId = $null
$emulatorTimeout = (Get-Date).AddMinutes(3)
while ((Get-Date) -lt $emulatorTimeout) {
    Start-Sleep -Seconds 5
    $devicesOutput = flutter devices --machine | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Could not check whether the Android emulator is ready."
    }

    $androidDevice = @($devicesOutput | ConvertFrom-Json) |
        Where-Object {
            $_.targetPlatform -like 'android-*' -and $_.emulator -eq $true
        } |
        Select-Object -First 1
    if ($null -ne $androidDevice) {
        $androidDeviceId = $androidDevice.id
        break
    }
    Write-Host "Waiting for Android emulator to become ready..."
}

if ([string]::IsNullOrWhiteSpace($androidDeviceId)) {
    throw "Android emulator '$emulatorId' did not become available within 3 minutes."
}

Write-Host "Running the app on Android device '$androidDeviceId'."
flutter run -d $androidDeviceId

# Default build for easy installation with Play Protect
# flutter build apk --release --flavor safe
