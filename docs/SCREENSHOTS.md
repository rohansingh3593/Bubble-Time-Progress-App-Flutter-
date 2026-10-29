# Phone screenshots

Generate reference images from the production Flutter widgets without editing application source or opening the user's Hive database.

## Generate the complete phone set

From the repository root in PowerShell:

~~~powershell
.\capture_screenshots.ps1
~~~

If script execution is restricted for this invocation:

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\capture_screenshots.ps1
~~~

This captures both light and dark themes at **390 × 844 logical pixels**, writing **780 × 1688 PNGs**. Each run gets a new folder:

~~~text
screenshots/phone/YYYYMMDD-HHmmss/
  index.html
  capture-report.json
  light/
    00-app-shell-01.png
    ...
    manifest.json
  dark/
    ...
    manifest.json
~~~

Open index.html in your browser. Click a thumbnail for the full-size PNG. Pages 02, 03, etc. continue down the screen with overlap. The gallery works offline and does not upload images.

Options:

~~~powershell
# One theme
.\capture_screenshots.ps1 -Theme light

# A single screen, including its associated representative forms
.\capture_screenshots.ps1 -Theme light -Screen 06-tasks

# A chosen NEW destination; existing folders are rejected to protect prior runs
.\capture_screenshots.ps1 -OutputDirectory screenshots\phone\my-review
~~~

Screen IDs: 00-app-shell, 01-dashboard, 02-year, 03-month, 04-week, 05-day, 06-tasks, 07-streak, 08-instructions, 09-goals, 10-money, 11-motivation, 12-progress-reports, 13-log-earn, 14-journal, 15-journey, 16-voice.

## Requirements and fidelity

- Flutter SDK and existing project dependencies, plus Python 3 for the HTML gallery. No new package dependencies.
- Cached Inter TTF files. The Windows default is %APPDATA%\com.example\Momentum, where the app has already downloaded fonts. Override with -FontDirectory if needed.
- The capture tool reads only font files from that cache. It initializes Hive in a separately created temporary directory, seeds synthetic tasks/journal/goals, disables cloud sync, then removes its own temporary database.
- It renders actual screen widgets using the application's theme. It explicitly loads Material Icons and Windows emoji/Hindi fallback fonts and removes the development DEBUG banner.
- The microphone adapter is stubbed; the voice screen can render without accessing native recording hardware.
- These are **reference renders**, not photographs/screenshots of a physical Android/iOS device. OS chrome, actual keyboards, permission prompts, camera/gallery sheets, platform-specific font fallback and system behavior are not captured.
- Individual screens are opened as routes for coverage; the root shell/navigation is captured separately. Some back-button behavior can differ from entering a top-level destination in the shell.
- Long primary scroll areas and form bodies are paginated. Nested task lists are not exhaustively scrolled, and all possible data/interaction states are not covered.
- Reports shares its implementation with Progress and is captured once.
- The existing Settings panel is unreachable through the active UI, so it is not included. This tooling does not change application navigation to expose it.

Rendering errors are collected in manifest.json and capture-report.json and shown below the gallery. Successful capture completion means the images were written; it does **not** mean the app passed layout/accessibility tests. Existing overflow stripes are deliberately preserved.

## Capture your actual Android device or emulator

Open the desired screen in the running app, then:

~~~powershell
flutter devices
New-Item -ItemType Directory -Force screenshots\manual | Out-Null
flutter screenshot -d DEVICE_ID --out screenshots/manual/01-dashboard.png
~~~

Replace DEVICE_ID with the ID listed by flutter devices. Navigate to each desired screen and repeat using a different filename. The Flutter device-screenshot command requires a device that supports screenshots; it is not a universal Windows-app capture command.

If Android capture through Flutter is unavailable, use Android platform-tools:

~~~powershell
adb -s DEVICE_ID shell screencap -p /sdcard/momentum-capture.png
adb -s DEVICE_ID pull /sdcard/momentum-capture.png screenshots/manual/01-dashboard.png
~~~

If adb is not on PATH, use its full path, usually:

~~~powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
~~~

Use adb pull rather than redirecting binary PNG output with > in Windows PowerShell. Device screenshots may contain your real task/journal data; inspect them before sharing.

To launch an emulator/device build first:

~~~powershell
flutter run -d DEVICE_ID
~~~

## Implementation

- capture_screenshots.ps1: repeatable entry point, fresh output folders, explicit theme/screen options.
- tool/capture_screenshots_test.dart: isolated fixtures and PNG capture through RenderRepaintBoundary.toImage.
- tool/build_screenshot_gallery.py: standard-library-only local gallery/report builder.

The capture tool is outside test/ and runs only when explicitly requested. The normal flutter test suite is unaffected.

Flutter documents PNG capture via [RenderRepaintBoundary.toImage](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html). Native screenshots and platform interactions require a real app/device session.

