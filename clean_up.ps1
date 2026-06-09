param(
  [switch]$DeepScan
)

$ErrorActionPreference = 'Continue'

Write-Host '--- Flutter Windows local data cleanup ---' -ForegroundColor Cyan

# Known app identifiers from windows runner files.
$appExeName = 'momentum'
$appProductNames = @('momentum', 'Bubble-Time-Progress-App-Flutter-')

# Stop likely running app processes (safe if not running)
$processNames = @($appExeName, 'Runner') + $appProductNames
foreach ($name in $processNames | Select-Object -Unique) {
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

# Deterministic app-data cleanup locations for Flutter Windows apps.
$exactTargets = New-Object System.Collections.Generic.HashSet[string]
$baseDirs = @("$env:LOCALAPPDATA", "$env:APPDATA")

foreach ($base in $baseDirs) {
  if (-not (Test-Path $base)) { continue }

  foreach ($name in $appProductNames + @($appExeName, 'com.example')) {
    [void]$exactTargets.Add((Join-Path $base $name))
  }

  # Typical Flutter path_provider app support locations.
  [void]$exactTargets.Add((Join-Path $base (Join-Path 'com.example' $appExeName)))
}

# Fast keyword folder scan (top-level only, avoids hangs)
$keywords = @('bubble', 'progress', 'task', 'streak', 'journal', 'journey')
foreach ($root in $baseDirs) {
  if (-not (Test-Path $root)) { continue }
  Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $n = $_.Name.ToLowerInvariant()
    if ($keywords | Where-Object { $n -like "*$_*" }) {
      [void]$exactTargets.Add($_.FullName)
    }
  }
}

# Delete known directories first.
foreach ($target in $exactTargets) {
  if (Test-Path $target) {
    Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $target)) {
      Write-Host "Deleted app data: $target"
    } else {
      Write-Host "Could not fully delete (in use/permission): $target" -ForegroundColor Yellow
    }
  }
}

# Optional deep scan for remaining DB/storage files under appdata.
if ($DeepScan) {
  Write-Host 'DeepScan enabled: searching recursively for storage files. This can take time...' -ForegroundColor Yellow
  foreach ($root in $baseDirs) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
      $_.Extension -in '.hive', '.lock', '.db', '.sqlite', '.sqlite3', '.isar'
    } | ForEach-Object {
      $file = $_.FullName
      Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
      if (-not (Test-Path $file)) {
        Write-Host "Deleted storage file: $file"
      }
    }
  }
}

Write-Host 'Cleanup complete.' -ForegroundColor Cyan
