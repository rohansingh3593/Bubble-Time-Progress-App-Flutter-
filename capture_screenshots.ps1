[CmdletBinding()]
param(
    [ValidateSet('light', 'dark', 'both')][string]$Theme = 'both',
    [Parameter(Position = 0)]
    [Alias('ThemeName')]
    [string]$Palette = 'all',
    [string]$OutputDirectory = '',
    [string]$FontDirectory = (Join-Path $env:APPDATA 'com.example\Momentum'),
    [string]$Screen = '',
    [switch]$Resume,
    [switch]$InventoryOnly
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $availablePalettes = [ordered]@{
        forestGlow   = 'Forest Glow'
        emeraldGrey  = 'Emerald Grey'
        oceanTeal    = 'Ocean Teal'
        royalFocus   = 'Royal Focus'
        purpleHaze   = 'Purple Haze'
        roseBlush    = 'Rose Blush'
        sunsetOrange = 'Sunset Orange'
        minimalCream = 'Minimal Cream'
        arcticBlue   = 'Arctic Blue'
        oliveLuxe    = 'Olive Luxe'
        mochaEarth   = 'Mocha Earth'
        midnightNavy = 'Midnight Navy'
    }
    if ($Palette -ne 'all') {
        $matchedPalette = $availablePalettes.Keys |
            Where-Object { $_ -ieq $Palette } |
            Select-Object -First 1
        if (!$matchedPalette) {
            $matchedPalette = $availablePalettes.GetEnumerator() |
                Where-Object { $_.Value -ieq $Palette } |
                Select-Object -ExpandProperty Key -First 1
        }
        if (!$matchedPalette) {
            $available = @($availablePalettes.GetEnumerator() | ForEach-Object {
                "$($_.Value) ($($_.Key))"
            }) -join ', '
            throw "Unknown theme/palette '$Palette'. Choose one of: $available. Use 'all' to capture every palette."
        }
        $Palette = $matchedPalette
    }

    if (!$OutputDirectory) {
        if ($InventoryOnly) {
            throw 'Supply -OutputDirectory when using -InventoryOnly.'
        }
        $OutputDirectory = Join-Path $PSScriptRoot ('screenshots\phone\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    $OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

    if ($InventoryOnly) {
        if (!(Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
            throw "Screenshot directory not found: $OutputDirectory"
        }
        if (!(Get-Command python -ErrorAction SilentlyContinue)) {
            throw 'Python 3 must be on PATH to build the screenshot inventory.'
        }
        $registryDirectory = $OutputDirectory
        $manifests = Get-ChildItem -LiteralPath $OutputDirectory -Filter 'manifest.json' -File -Recurse
        if ($manifests.Count -gt 0) {
            $registryDirectory = Split-Path -Parent $OutputDirectory
        }
        $registryPath = Join-Path $registryDirectory '.screenshot-inventory-index.json'
        & python tool/build_screenshot_gallery.py $OutputDirectory --inventory-only --registry $registryPath
        if ($LASTEXITCODE -ne 0) { throw 'Screenshot inventory generation failed.' }
        Write-Host "Inventory: $OutputDirectory\screenshot-inventory.md"
        return
    }

    if (!(Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter must be on PATH.' }
    if (!(Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python 3 must be on PATH for the gallery.' }
    if (!(Test-Path -LiteralPath $FontDirectory)) {
        throw 'Font cache missing. Supply -FontDirectory pointing to cached Inter TTF files. See docs/SCREENSHOTS.md.'
    }

    # Never clear an existing folder or overwrite a completed capture variant.
    if (Test-Path -LiteralPath $OutputDirectory) {
        if (!$Resume) { throw "Choose a new output directory or use -Resume: $OutputDirectory already exists." }
    } else {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }
    $capturePalettes = if ($Palette -eq 'all') {
        @($availablePalettes.Keys)
    } else {
        @($Palette)
    }
    $captureThemes = if ($Theme -eq 'both') { @('light', 'dark') } else { @($Theme) }
    foreach ($capturePalette in $capturePalettes) {
        $paletteOutput = Join-Path $OutputDirectory $capturePalette
        foreach ($captureVariant in $captureThemes) {
            $variantOutput = Join-Path $paletteOutput $captureVariant
            if ($Resume -and (Test-Path -LiteralPath (Join-Path $variantOutput 'manifest.json'))) {
                Write-Host "Skipping completed capture: $capturePalette / $captureVariant"
                continue
            }
            $arguments = @(
                '--no-version-check', '--suppress-analytics', 'test', '--no-pub', 'tool/capture_screenshots_test.dart',
                "--dart-define=CAPTURE_OUTPUT=$paletteOutput",
                "--dart-define=CAPTURE_FONTS=$FontDirectory",
                "--dart-define=CAPTURE_THEME=$captureVariant",
                "--dart-define=CAPTURE_PALETTE=$capturePalette",
                "--dart-define=CAPTURE_SCREEN=$Screen",
                '--dart-define=MOMENTUM_CLOUD_SYNC_ENABLED=false'
            )
            & flutter @arguments
            if ($LASTEXITCODE -ne 0) {
                throw "Capture failed for palette $capturePalette / $captureVariant. Partial output: $OutputDirectory"
            }
        }
    }
    $registryPath = Join-Path (Split-Path -Parent $OutputDirectory) '.screenshot-inventory-index.json'
    & python tool/build_screenshot_gallery.py $OutputDirectory --registry $registryPath
    if ($LASTEXITCODE -ne 0) { throw 'Gallery generation failed.' }
    Write-Host "Open this file in your browser: $OutputDirectory\index.html"
    Write-Host "Screenshot inventory: $OutputDirectory\screenshot-inventory.md"
    Write-Host 'Reference widgets, synthetic data, 390x844 layout, 780x1688 PNGs.'
    if ($Resume) { Write-Host 'Completed palette/mode runs were preserved; only missing runs were captured.' }
} finally {
    Pop-Location
}
