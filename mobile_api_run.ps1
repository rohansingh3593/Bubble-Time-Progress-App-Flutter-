param(
    [string]$DeviceId = "",
    [string]$ApiHost = "",
    [int]$Port = 8000,
    [string]$UserId = "dev-user",
    [switch]$SkipPubGet
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

function Get-LanAddress {
    $address = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -notlike "192.168.56.*" -and
            $_.InterfaceAlias -notlike "*VirtualBox*" -and
            $_.InterfaceAlias -notlike "*VMware*" -and
            $_.InterfaceAlias -notlike "*Hyper-V*"
        } |
        Select-Object -ExpandProperty IPAddress -First 1

    if ($address) {
        return $address
    }

    return ipconfig |
        Select-String "IPv4 Address" |
        ForEach-Object {
            if ($_.Line -match ":\s*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)") {
                $matches[1]
            }
        } |
        Where-Object {
            $_ -notlike "127.*" -and
            $_ -notlike "169.254.*" -and
            $_ -notlike "192.168.56.*"
        } |
        Select-Object -First 1
}

$resolvedHost = if ([string]::IsNullOrWhiteSpace($ApiHost)) { Get-LanAddress } else { $ApiHost }
if ([string]::IsNullOrWhiteSpace($resolvedHost)) {
    throw "Could not find a LAN IPv4 address. Pass -ApiHost manually, for example -ApiHost 192.168.1.8."
}

$apiBaseUrl = "http://$resolvedHost`:$Port"
$wsUrl = "ws://$resolvedHost`:$Port/ws"

Push-Location $root
try {
    if (-not $SkipPubGet) {
        Write-Host "[run] fetching Flutter packages"
        Invoke-Native -FilePath flutter -Arguments @("pub", "get")
    }

    Write-Host ""
    Write-Host "Running Momentum with cloud sync:"
    Write-Host "  API: $apiBaseUrl"
    Write-Host "  WebSocket: $wsUrl"
    Write-Host "  User: $UserId"
    Write-Host ""

    $arguments = @(
        "run",
        "--dart-define=MOMENTUM_CLOUD_SYNC_ENABLED=true",
        "--dart-define=MOMENTUM_API_BASE_URL=$apiBaseUrl",
        "--dart-define=MOMENTUM_WS_URL=$wsUrl",
        "--dart-define=MOMENTUM_USER_ID=$UserId"
    )

    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $arguments = @("run", "-d", $DeviceId) + $arguments[1..($arguments.Count - 1)]
    }

    Invoke-Native -FilePath flutter -Arguments $arguments
}
finally {
    Pop-Location
}
