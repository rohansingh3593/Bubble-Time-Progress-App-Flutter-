param(
    [switch]$SkipDependencyInstall,
    [switch]$SkipFlutterTest
)

$ErrorActionPreference = "Stop"
$failed = $false

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)] [string]$Label,
        [Parameter(Mandatory = $true)] [scriptblock]$Command,
        [switch]$WarningOnly
    )

    Write-Host "`n▶ $Label"

    try {
        & $Command
        Write-Host "✅ $Label"
    }
    catch {
        if ($WarningOnly) {
            Write-Host "⚠️ $Label"
            Write-Host "   $($_.Exception.Message)"
        }
        else {
            Write-Host "❌ $Label"
            Write-Host "   $($_.Exception.Message)"
            $script:failed = $true
        }
    }
}

Invoke-Check -Label "python3 -m py_compile backend/main.py backend/database.py backend/models.py backend/websocket_manager.py" -Command { python3 -m py_compile backend/main.py backend/database.py backend/models.py backend/websocket_manager.py }

Invoke-Check -Label "git diff --check" -Command { git diff --check }

if ($SkipDependencyInstall) {
    Write-Host "`n⚠️ python3 -m venv /tmp/momentum_backend_venv && /tmp/momentum_backend_venv/bin/pip install -r backend/requirements.txt"
    Write-Host "   Skipped by -SkipDependencyInstall."
}
else {
    Invoke-Check -Label "python3 -m venv /tmp/momentum_backend_venv && /tmp/momentum_backend_venv/bin/pip install -r backend/requirements.txt" -WarningOnly -Command {
            if ($IsWindows) {
                python -m venv .venv_backend
                .\.venv_backend\Scripts\python.exe -m pip install -r backend/requirements.txt
            }
            else {
                python3 -m venv /tmp/momentum_backend_venv
                /tmp/momentum_backend_venv/bin/pip install -r backend/requirements.txt
            }
        }
}

if ($SkipFlutterTest) {
    Write-Host "`n⚠️ flutter test"
    Write-Host "   Skipped by -SkipFlutterTest."
}
else {
    Invoke-Check -Label "flutter test" -WarningOnly -Command { flutter test }
}

if ($failed) {
    exit 1
}
