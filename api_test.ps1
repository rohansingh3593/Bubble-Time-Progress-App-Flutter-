param(
    [string]$VenvName = "test1",
    [string]$HostAddress = "0.0.0.0",
    [int]$Port = 8000,
    [string]$MongoUrl = "mongodb://localhost:27017",
    [string]$MongoDatabase = "momentum_task_app",
    [int]$TimeoutSeconds = 30,
    [switch]$SkipInstall,
    [switch]$NoDatabaseTest,
    [switch]$NoWebSocketTest,
    [switch]$NoKeepAlive
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
$apiUrl = "http://127.0.0.1:$Port"
$wsUrl = "ws://127.0.0.1:$Port/ws?user_id=dev-user"
$logPath = Join-Path $root "api_test_server.log"
$errorLogPath = Join-Path $root "api_test_server_error.log"
$serverProcess = $null

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

function Test-HttpJson {
    param(
        [Parameter(Mandatory = $true)] [string]$Url,
        [Parameter(Mandatory = $true)] [string]$Name,
        [switch]$WarningOnly
    )

    Write-Host "[run] $Name"
    try {
        $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5
        Write-Host "[ok] $Name"
        return $response
    }
    catch {
        if ($WarningOnly) {
            Write-Host "[warn] $Name"
            Write-Host "   $($_.Exception.Message)"
            return $null
        }

        throw
    }
}

function Test-HttpJsonWithHeaders {
    param(
        [Parameter(Mandatory = $true)] [string]$Url,
        [Parameter(Mandatory = $true)] [string]$Name,
        [hashtable]$Headers = @{},
        [switch]$WarningOnly
    )

    Write-Host "[run] $Name"
    try {
        $response = Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers -TimeoutSec 5
        Write-Host "[ok] $Name"
        return $response
    }
    catch {
        if ($WarningOnly) {
            Write-Host "[warn] $Name"
            Write-Host "   $($_.Exception.Message)"
            return $null
        }

        throw
    }
}

function Test-WebSocket {
    Write-Host "[run] websocket handshake $wsUrl"

    $script = @"
import asyncio
import websockets

async def main():
    async with websockets.connect("$wsUrl", open_timeout=5):
        return

asyncio.run(main())
"@

    $script | & $venvPython -
    if ($LASTEXITCODE -ne 0) {
        throw "Websocket handshake failed."
    }

    Write-Host "[ok] websocket handshake $wsUrl"
}

function Test-TaskRestCrud {
    Write-Host "[run] REST task CRUD with owner header"

    $headers = @{ "X-User-Id" = "dev-user" }
    $taskId = "api-test-$([guid]::NewGuid().ToString('N'))"
    $body = @{
        task_id = $taskId
        title = "API Test Task"
        start_time = "07:00"
        end_time = "08:00"
        status = "scheduled"
    } | ConvertTo-Json

    $created = Invoke-RestMethod -Uri "$apiUrl/tasks" -Method Post -Headers $headers -Body $body -ContentType "application/json" -TimeoutSec 5
    if ($created.task.task_id -ne $taskId -or $created.task.user_id -ne "dev-user") {
        throw "POST /tasks did not return the expected owned task."
    }

    $updateBody = @{
        title = "API Test Task"
        status = "completed"
        done = $true
    } | ConvertTo-Json
    $updated = Invoke-RestMethod -Uri "$apiUrl/tasks/$taskId" -Method Put -Headers $headers -Body $updateBody -ContentType "application/json" -TimeoutSec 5
    if ($updated.task.status -ne "completed" -or -not $updated.task.done) {
        throw "PUT /tasks/$taskId did not update completion state."
    }

    Invoke-RestMethod -Uri "$apiUrl/tasks/$taskId" -Method Delete -Headers $headers -TimeoutSec 5 | Out-Null

    Write-Host "[ok] REST task CRUD with owner header"
}

function Get-LanAddresses {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Select-Object -ExpandProperty IPAddress -Unique

    if (-not $addresses) {
        $addresses = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
            Where-Object { $_.AddressFamily -eq "InterNetwork" -and $_.IPAddressToString -notlike "127.*" } |
            ForEach-Object { $_.IPAddressToString }
    }

    return $addresses
}

try {
    if (-not (Test-Path $backendPath)) {
        throw "Backend folder was not found at $backendPath."
    }

    if (-not (Test-Path $requirementsPath)) {
        throw "Backend requirements file was not found at $requirementsPath."
    }

    if (-not (Test-Path $venvPython)) {
        Write-Host "[run] creating Python environment '$VenvName'"
        Invoke-SystemPython -Arguments @("-m", "venv", $venvPath)
        Write-Host "[ok] creating Python environment '$VenvName'"
    }
    else {
        Write-Host "[ok] using Python environment '$VenvName'"
    }

    if (-not $SkipInstall) {
        Write-Host "[run] installing API test dependencies"
        Invoke-Native -FilePath $venvPython -Arguments @("-m", "pip", "install", "-r", $requirementsPath, "websockets")
        Write-Host "[ok] installing API test dependencies"
    }
    else {
        Write-Host "[warn] installing API test dependencies"
        Write-Host "   Skipped by -SkipInstall."
    }

    Write-Host "[run] starting API server"
    $previousMongoUrl = $env:MONGO_URL
    $previousMongoDatabase = $env:MONGO_DATABASE
    $previousPythonPath = $env:PYTHONPATH

    try {
        $env:MONGO_URL = $MongoUrl
        $env:MONGO_DATABASE = $MongoDatabase
        $env:PYTHONPATH = $backendPath

        $serverProcess = Start-Process `
            -FilePath $venvPython `
            -ArgumentList @("-m", "uvicorn", "main:app", "--host", $HostAddress, "--port", "$Port") `
            -WorkingDirectory $backendPath `
            -RedirectStandardOutput $logPath `
            -RedirectStandardError $errorLogPath `
            -PassThru `
            -WindowStyle Hidden
    }
    finally {
        $env:MONGO_URL = $previousMongoUrl
        $env:MONGO_DATABASE = $previousMongoDatabase
        $env:PYTHONPATH = $previousPythonPath
    }

    Write-Host "[ok] started API server, pid $($serverProcess.Id)"

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $health = $null
    do {
        Start-Sleep -Milliseconds 500
        try {
            $health = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 2
        }
        catch {
            if ($serverProcess.HasExited) {
                throw "API server exited early. Check $errorLogPath."
            }
        }
    } while ($null -eq $health -and (Get-Date) -lt $deadline)

    if ($null -eq $health) {
        throw "API did not become ready within $TimeoutSeconds seconds. Check $errorLogPath."
    }

    Write-Host "[ok] health check $apiUrl"
    Write-Host "   status: $($health.status)"

    if (-not $NoWebSocketTest) {
        Test-WebSocket
    }
    else {
        Write-Host "[warn] websocket handshake $wsUrl"
        Write-Host "   Skipped by -NoWebSocketTest."
    }

    if (-not $NoDatabaseTest) {
        Test-TaskRestCrud

        $tasks = Test-HttpJson -Url "$apiUrl/tasks" -Name "database-backed GET /tasks" -WarningOnly
        if ($null -ne $tasks) {
            Write-Host "   tasks returned: $($tasks.Count)"
        }
    }
    else {
        Write-Host "[warn] database-backed GET /tasks"
        Write-Host "   Skipped by -NoDatabaseTest."
    }

    Write-Host ""
    Write-Host "API is ready for this computer:"
    Write-Host "   $apiUrl"
    Write-Host "   $wsUrl"

    $lanAddresses = Get-LanAddresses
    if ($lanAddresses) {
        Write-Host ""
        Write-Host "Use one of these from your mobile app when the phone is on the same network:"
        foreach ($address in $lanAddresses) {
            $lanApiUrl = "http://$address`:$Port"
            $lanWsUrl = "ws://$address`:$Port/ws?user_id=dev-user"
            Write-Host "   $lanApiUrl"
            Write-Host "   $lanWsUrl"

            $lanTasks = Test-HttpJsonWithHeaders `
                -Url "$lanApiUrl/tasks" `
                -Name "LAN GET /tasks at $lanApiUrl" `
                -Headers @{ "X-User-Id" = "dev-user" } `
                -WarningOnly
            if ($null -ne $lanTasks) {
                Write-Host "   LAN tasks returned: $($lanTasks.Count)"
            }
        }
    }

    Write-Host ""
    Write-Host "Server logs:"
    Write-Host "   $logPath"
    Write-Host "   $errorLogPath"

    if ($NoKeepAlive) {
        Write-Host "[ok] tests complete; stopping API server because -NoKeepAlive was used."
    }
    else {
        Write-Host ""
        Write-Host "API server is still running for mobile app testing. Press Ctrl+C to stop it."
        while (-not $serverProcess.HasExited) {
            Start-Sleep -Seconds 1
        }
    }
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force
        Write-Host "[ok] stopped API server"
    }
}
