[CmdletBinding()]
param(
    [ValidateSet('light', 'dark', 'both')][string]$Theme = 'both',
    [string]$OutputDirectory = '',
    [string]$FontDirectory = (Join-Path $env:APPDATA 'com.example\Momentum'),
    [string]$Screen = ''
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (!(Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter must be on PATH.' }
    if (!(Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python 3 must be on PATH for the gallery.' }
    if (!(Test-Path -LiteralPath $FontDirectory)) {
        throw 'Font cache missing. Supply -FontDirectory pointing to cached Inter TTF files. See docs/SCREENSHOTS.md.'
    }
    if (!$OutputDirectory) {
        $OutputDirectory = Join-Path $PSScriptRoot ('screenshots\phone\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    $OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
    # Never clear an existing folder or overwrite an earlier capture run.
    if (Test-Path -LiteralPath $OutputDirectory) { throw "Choose a new output directory: $OutputDirectory already exists." }
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $captureThemes = if ($Theme -eq 'both') { @('light', 'dark') } else { @($Theme) }
    foreach ($captureVariant in $captureThemes) {
        $arguments = @(
            'test', '--no-pub', 'tool/capture_screenshots_test.dart',
            "--dart-define=CAPTURE_OUTPUT=$OutputDirectory",
            "--dart-define=CAPTURE_FONTS=$FontDirectory",
            "--dart-define=CAPTURE_THEME=$captureVariant",
            "--dart-define=CAPTURE_SCREEN=$Screen",
            '--dart-define=MOMENTUM_CLOUD_SYNC_ENABLED=false'
        )
        & flutter @arguments
        if ($LASTEXITCODE -ne 0) { throw "Capture failed for $captureVariant. Partial output: $OutputDirectory" }
    }
    & python tool/build_screenshot_gallery.py $OutputDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Gallery generation failed.' }
    Write-Host "Open this file in your browser: $OutputDirectory\index.html"
    Write-Host 'Reference widgets, synthetic data, 390x844 layout, 780x1688 PNGs.'
} finally {
    Pop-Location
}

