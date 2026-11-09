param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8080,
    [switch]$SkipConfig,
    [switch]$SkipPubGet,
    [switch]$StaticBuild,
    [switch]$SkipBuild,
    [switch]$StrictPort,
    [switch]$StopExisting,
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) {
    $root = (Get-Location).Path
}

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

function Get-PortOwners {
    param(
        [Parameter(Mandatory = $true)] [string]$Address,
        [Parameter(Mandatory = $true)] [int]$PortNumber
    )

    $connections = Get-NetTCPConnection -LocalPort $PortNumber -ErrorAction SilentlyContinue |
        Where-Object {
            $_.State -eq "Listen" -and
            ($_.LocalAddress -eq $Address -or $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "::")
        }

    return $connections | Select-Object -ExpandProperty OwningProcess -Unique
}

function Test-PortInUse {
    param(
        [Parameter(Mandatory = $true)] [string]$Address,
        [Parameter(Mandatory = $true)] [int]$PortNumber
    )

    $owners = @(Get-PortOwners -Address $Address -PortNumber $PortNumber)
    return $owners.Count -gt 0
}

function Stop-PortOwners {
    param(
        [Parameter(Mandatory = $true)] [string]$Address,
        [Parameter(Mandatory = $true)] [int]$PortNumber
    )

    $owners = @(Get-PortOwners -Address $Address -PortNumber $PortNumber)
    foreach ($owner in $owners) {
        $process = Get-Process -Id $owner -ErrorAction SilentlyContinue
        if ($null -ne $process) {
            Stop-Process -Id $owner -Force
            Write-Host "[ok] stopped $($process.ProcessName) on port $PortNumber (pid $owner)"
        }
    }
}

function Resolve-WebPort {
    param(
        [Parameter(Mandatory = $true)] [string]$Address,
        [Parameter(Mandatory = $true)] [int]$RequestedPort
    )

    if ($StopExisting -and (Test-PortInUse -Address $Address -PortNumber $RequestedPort)) {
        Stop-PortOwners -Address $Address -PortNumber $RequestedPort
    }

    if (-not (Test-PortInUse -Address $Address -PortNumber $RequestedPort)) {
        return $RequestedPort
    }

    if ($StrictPort) {
        throw "Port $RequestedPort is already in use. Stop the existing server or run without -StrictPort."
    }

    for ($candidate = $RequestedPort + 1; $candidate -le ($RequestedPort + 50); $candidate++) {
        if (-not (Test-PortInUse -Address $Address -PortNumber $candidate)) {
            Write-Host "[warn] port $RequestedPort is busy; using port $candidate instead"
            return $candidate
        }
    }

    throw "No free web port found between $RequestedPort and $($RequestedPort + 50)."
}

Push-Location $root
try {
    if (-not $SkipConfig) {
        Write-Host "[run] enabling Flutter web"
        Invoke-Native -FilePath flutter -Arguments @("config", "--enable-web")
    }
    else {
        Write-Host "[warn] skipped flutter config --enable-web"
    }

    if (-not $SkipPubGet) {
        Write-Host "[run] fetching Flutter packages"
        Invoke-Native -FilePath flutter -Arguments @("pub", "get")
    }
    else {
        Write-Host "[warn] skipped flutter pub get"
    }

    $resolvedPort = Resolve-WebPort -Address $HostAddress -RequestedPort $Port
    $url = "http://$HostAddress`:$resolvedPort"

    if ($StaticBuild) {
        if (-not $SkipBuild) {
            Write-Host "[run] building Flutter web"
            Invoke-Native -FilePath flutter -Arguments @("build", "web")
        }
        else {
            Write-Host "[warn] skipped flutter build web"
        }

        $webBuildPath = Join-Path $root "build\web"
        if (-not (Test-Path -LiteralPath $webBuildPath)) {
            throw "Web build folder was not found at $webBuildPath. Run without -SkipBuild first."
        }

        $python = Get-PythonCommand
        Write-Host ""
        Write-Host "Static web page serving:"
        Write-Host "  $url"
        Write-Host ""

        if ($OpenBrowser) {
            Start-Process $url
        }

        Push-Location $webBuildPath
        try {
            Invoke-Native -FilePath $python.FilePath -Arguments @($python.Prefix + @("-m", "http.server", "$resolvedPort", "--bind", $HostAddress))
        }
        finally {
            Pop-Location
        }

        return
    }

    Write-Host ""
    Write-Host "Flutter web starting:"
    Write-Host "  $url"
    Write-Host ""

    if ($OpenBrowser) {
        Start-Process $url
    }

    Invoke-Native -FilePath flutter -Arguments @(
        "run",
        "-d",
        "web-server",
        "--web-hostname",
        $HostAddress,
        "--web-port",
        "$resolvedPort"
    )
}
finally {
    Pop-Location
}
