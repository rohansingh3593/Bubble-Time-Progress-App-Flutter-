param(
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

function Get-LanAddresses {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.InterfaceAlias -notlike "*VirtualBox*" -and
            $_.InterfaceAlias -notlike "*VMware*" -and
            $_.InterfaceAlias -notlike "*Hyper-V*"
        } |
        Select-Object -ExpandProperty IPAddress -Unique

    if (-not $addresses) {
        $addresses = ipconfig |
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
            Select-Object -Unique
    }

    return $addresses
}

Write-Host "Momentum mobile LAN check"
Write-Host ""

$listeners = @(netstat -ano | Select-String ":$Port\s")
if ($listeners.Count -eq 0) {
    Write-Host "[fail] Nothing is listening on port $Port."
    Write-Host "Start the backend first:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\server_run.ps1"
    exit 1
}

Write-Host "[ok] Port $Port is listening:"
$listeners | ForEach-Object { Write-Host "  $($_.Line.Trim())" }

$lanAddresses = @(Get-LanAddresses)
if ($lanAddresses.Count -eq 0) {
    Write-Host "[fail] No LAN IPv4 address found."
    exit 1
}

Write-Host ""
Write-Host "Try these URLs on the PHONE browser:"
foreach ($address in $lanAddresses) {
    $url = "http://$address`:$Port"
    try {
        Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 3 | Out-Null
        Write-Host "  [ok from laptop] $url"
    }
    catch {
        Write-Host "  [fail from laptop] $url"
    }
}

Write-Host ""
Write-Host "If URLs work on laptop but not phone, fix one of these:"
Write-Host "  1. Phone must be on same Wi-Fi as this computer."
Write-Host "  2. Disable guest Wi-Fi/AP isolation on the router."
Write-Host "  3. Allow inbound TCP $Port in Windows Firewall."
Write-Host ""
Write-Host "Admin firewall command:"
Write-Host "  New-NetFirewallRule -DisplayName `"Momentum FastAPI Dev Server $Port`" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Any"
