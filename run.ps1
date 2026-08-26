param(
    [switch]$SkipDependencyInstall,
    [switch]$SkipFlutterTest
)

$ErrorActionPreference = "Stop"
$failed = $false
$isWindowsHost = [System.Environment]::OSVersion.Platform -eq "Win32NT"

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [string[]]$Arguments = @()
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "'$FilePath $($Arguments -join ' ')' exited with code $LASTEXITCODE."
    }
}

function Get-PythonCommand {
    $candidates = @(
        @{ FilePath = "python3"; Prefix = @() },
        @{ FilePath = "python"; Prefix = @() },
        @{ FilePath = "py"; Prefix = @("-3") }
    )

    foreach ($candidate in $candidates) {
        try {
            & $candidate.FilePath @($candidate.Prefix + @("--version")) *> $null
            if ($LASTEXITCODE -eq 0) {
                return $candidate
            }
        }
        catch {
            continue
        }
    }

    throw "Python 3 was not found on PATH. Install Python 3 or enable the Python launcher."
}

function Invoke-Python {
    param(
        [string[]]$Arguments = @()
    )

    $python = Get-PythonCommand
    Invoke-Native $python.FilePath @($python.Prefix + $Arguments)
}

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)] [string]$Label,
        [Parameter(Mandatory = $true)] [scriptblock]$Command,
        [switch]$WarningOnly
    )

    Write-Host "`n[run] $Label"

    try {
        & $Command
        Write-Host "[ok] $Label"
    }
    catch {
        if ($WarningOnly) {
            Write-Host "[warn] $Label"
            Write-Host "   $($_.Exception.Message)"
        }
        else {
            Write-Host "[fail] $Label"
            Write-Host "   $($_.Exception.Message)"
            $script:failed = $true
        }
    }
}

Invoke-Check -Label "python -m py_compile backend/main.py backend/database.py backend/models.py backend/websocket_manager.py" -Command {
    Invoke-Python -Arguments @("-m", "py_compile", "backend/main.py", "backend/database.py", "backend/models.py", "backend/websocket_manager.py")
}

Invoke-Check -Label "git diff --check" -Command { Invoke-Native -FilePath git -Arguments @("diff", "--check") }

if ($SkipDependencyInstall) {
    Write-Host "`n[warn] python -m venv <backend venv> && pip install -r backend/requirements.txt"
    Write-Host "   Skipped by -SkipDependencyInstall."
}
else {
    Invoke-Check -Label "python -m venv <backend venv> && pip install -r backend/requirements.txt" -WarningOnly -Command {
        if ($isWindowsHost) {
            Invoke-Python -Arguments @("-m", "venv", ".venv_backend")
            Invoke-Native -FilePath .\.venv_backend\Scripts\python.exe -Arguments @("-m", "pip", "install", "-r", "backend/requirements.txt")
        }
        else {
            Invoke-Python -Arguments @("-m", "venv", "/tmp/momentum_backend_venv")
            Invoke-Native -FilePath /tmp/momentum_backend_venv/bin/python -Arguments @("-m", "pip", "install", "-r", "backend/requirements.txt")
        }
    }
}

if ($SkipFlutterTest) {
    Write-Host "`n[warn] flutter test"
    Write-Host "   Skipped by -SkipFlutterTest."
}
else {
    Invoke-Check -Label "flutter test" -WarningOnly -Command { Invoke-Native -FilePath flutter -Arguments @("test") }
}

if ($failed) {
    exit 1
}
