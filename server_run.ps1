param(
    [string]$VenvName = ".venv_backend",
    [string]$HostAddress = "0.0.0.0",
    [int]$Port = 8000,
    [string]$MongoUrl = "mongodb://localhost:27017",
    [string]$MongoDatabase = "momentum_task_app",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) {
    $root = (Get-Location).Path
}

$backendPath = Join-Path $root "backend"
$requirementsPath = Join-Path $backendPath "requirements.txt"
$venvPath = Join-Path $root $VenvName
$venvPython = Join-Path $venvPath "Scripts\python.exe"

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

function Invoke-SystemPython {
    param([string[]]$Arguments = @())

    $python = Get-PythonCommand
    Invoke-Native -FilePath $python.FilePath -Arguments @($python.Prefix + $Arguments)
}

function Get-LanAddresses {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -ne "WellKnown" -and
            $_.InterfaceAlias -notlike "*VirtualBox*" -and
            $_.InterfaceAlias -notlike "*VMware*" -and
            $_.InterfaceAlias -notlike "*Hyper-V*"
        } |
        Select-Object -ExpandProperty IPAddress -Unique

    if (-not $addresses) {
        $addresses = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
            Where-Object { $_.AddressFamily -eq "InterNetwork" -and $_.IPAddressToString -notlike "127.*" } |
            ForEach-Object { $_.IPAddressToString }
    }

    return $addresses
}

if (-not (Test-Path -LiteralPath $backendPath)) {
    throw "Backend folder was not found at $backendPath."
}

if (-not (Test-Path -LiteralPath $requirementsPath)) {
    throw "Backend requirements file was not found at $requirementsPath."
}

if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host "[run] creating Python environment $VenvName"
    Invoke-SystemPython -Arguments @("-m", "venv", $venvPath)
    Write-Host "[ok] created Python environment $VenvName"
}
else {
    Write-Host "[ok] using Python environment $VenvName"
}

if (-not $SkipInstall) {
    Write-Host "[run] installing backend requirements"
    Invoke-Native -FilePath $venvPython -Arguments @("-m", "pip", "install", "-r", $requirementsPath)
    Write-Host "[ok] installed backend requirements"
}
else {
    Write-Host "[warn] skipped backend requirements install"
}

$env:MONGO_URL = $MongoUrl
$env:MONGO_DATABASE = $MongoDatabase
$env:PYTHONPATH = $backendPath

Write-Host ""
Write-Host "Backend starting:"
Write-Host "  API: http://127.0.0.1:$Port"
Write-Host "  WebSocket: ws://127.0.0.1:$Port/ws?user_id=dev-user"
Write-Host "  Production/API: https://api.momentum.com"
Write-Host "  Production/WebSocket: wss://api.momentum.com/ws"
Write-Host "  MongoDB: $MongoUrl / $MongoDatabase"

$lanAddresses = Get-LanAddresses
if ($lanAddresses) {
    Write-Host ""
    Write-Host "Mobile test URLs:"
    foreach ($address in $lanAddresses) {
        Write-Host "  API: http://$address`:$Port"
        Write-Host "  Tasks: http://$address`:$Port/tasks"
        Write-Host "  WebSocket: ws://$address`:$Port/ws?user_id=dev-user"
    }
}
Write-Host ""

Push-Location $backendPath
try {
    Invoke-Native -FilePath $venvPython -Arguments @(
        "-m",
        "uvicorn",
        "main:app",
        "--host",
        $HostAddress,
        "--port",
        "$Port",
        "--reload"
    )
}
finally {
    Pop-Location
}
