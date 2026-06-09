Write-Host "====================================="
Write-Host "Branch Pull setup Started."
Write-Host "====================================="
Write-Host "====================================="
# $BRANCH_NAME = "codex/redesign-the-dashboard-j91d2m"
$BRANCH_NAME = "main"
git fetch origin
git checkout $BRANCH_NAME
git pull origin $BRANCH_NAME
Write-Host "====================================="
Write-Host "Branch Pull setup completed."
Write-Host "====================================="

Write-Host "====================================="
Write-Host "Environment setup Started."
Write-Host "====================================="

taskkill /F /IM excel_voice_reader.exe
taskkill /F /IM flutter_tester.exe
taskkill /F /IM dart.exe
taskkill /F /IM dart.exe
taskkill /F /IM dart.exe

flutter clean
flutter pub get
# flutter analyze   # Flutter SDK is not installed in this environment (flutter: command not found).
# flutter test      # Flutter SDK is not installed in this environment (flutter: command not found).

Write-Host ""
Write-Host "====================================="
Write-Host "Environment setup completed."
Write-Host "====================================="
Write-Host "Application Running"
flutter config --enable-windows-desktop
flutter config --enable-web
flutter create .
flutter run -d windows


# Default build for easy installation with Play Protect
# flutter build apk --release --flavor safe
