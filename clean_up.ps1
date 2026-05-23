param(
  [switch]$DeepScan
)

$ErrorActionPreference = 'Continue'

Write-Host '--- Flutter Windows local data cleanup ---' -ForegroundColor Cyan

# Stop likely running app processes (safe if not running)
$processNames = @(
  'bubble_time_progress_app_flutter',
  'Bubble-Time-Progress-App-Flutter-',
  'Runner'
)

foreach ($name in $processNames) {
  Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Flutter-generated project cleanup
if (Get-Command flutter -ErrorAction SilentlyContinue) {
  flutter clean
} else {
  Write-Host 'flutter command not found; skipping flutter clean.' -ForegroundColor Yellow
}

# Remove project-local generated folders if they still exist
$projectPaths = @(
  '.dart_tool',
  'build',
  'windows/flutter/ephemeral'
)

foreach ($path in $projectPaths) {
  if (Test-Path $path) {
    Remove-Item -Path $path -Recurse -Force
    Write-Host "Deleted: $path"
  } else {
    Write-Host "Not found: $path"
  }
}

# Fast cleanup: only top-level app folders in AppData (no expensive recursion)
$candidateRoots = @(
  "$env:LOCALAPPDATA",
  "$env:APPDATA"
)

$keywords = @(
  'bubble',
  'progress',
  'task',
  'streak',
  'journal',
  'journey'
)

$targets = New-Object System.Collections.Generic.HashSet[string]

foreach ($root in $candidateRoots) {
  if (-not (Test-Path $root)) { continue }

  Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $n = $_.Name.ToLowerInvariant()
    if ($keywords | Where-Object { $n -like "*$_*" }) {
      [void]$targets.Add($_.FullName)
    }
  }
}

# Optional deep scan for storage files can be enabled explicitly.
if ($DeepScan) {
  Write-Host 'DeepScan enabled: searching for storage files recursively. This can take time...' -ForegroundColor Yellow
  foreach ($root in $candidateRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
      $_.Extension -in '.hive', '.lock', '.db', '.sqlite', '.sqlite3', '.isar'
    } | ForEach-Object {
      [void]$targets.Add($_.FullName)
    }
  }
}

if ($targets.Count -eq 0) {
  Write-Host 'No matching app-data targets found automatically.' -ForegroundColor Yellow
} else {
  Write-Host "Found $($targets.Count) potential local-data targets." -ForegroundColor Green
}

foreach ($target in $targets) {
  if (Test-Path $target) {
    Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $target)) {
      Write-Host "Deleted app data: $target"
    } else {
      Write-Host "Could not fully delete (in use/permission): $target" -ForegroundColor Yellow
    }
  }
}

Write-Host 'Cleanup complete.' -ForegroundColor Cyan
