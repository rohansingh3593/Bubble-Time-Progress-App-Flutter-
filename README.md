# Bubble-Time-Progress-App-Flutter-
# 📱 Bubble Time Progress App (Flutter)

A modern **Flutter-based mobile application** that visualizes **time progress** (Year, Month, Week, Day) using a **bubble (circle) grid UI**, combined with **task management capabilities**.

---

## 🚀 Features

### 📅 Year View

* Displays all **365/366 days** as bubbles
* Fully responsive grid (no scrolling)
* Completed days highlighted
* Inspired by **GitHub heatmap**

---

### 📆 Month View

* Calendar-style layout (7 columns)
* Dynamically adapts to month length
* Shows progress of current month

---

### 📊 Week View

* 7 bubbles (Monday → Sunday)
* Current day highlighted
* Day labels included

---

### ⏰ Day View

* 24 bubbles representing hours
* Highlights current hour

---

## 📝 Task Management (NEW 🔥)

### 👉 Tap on Any Day Bubble

* Opens a **task screen / bottom sheet**
* Displays:

  * ✅ Completed tasks
  * 📌 Pending tasks

---

### ➕ Add Tasks

* Add new tasks for a specific day
* Tasks are linked to that date

---

### ✏️ Manage Tasks

* Mark task as complete/incomplete
* Delete tasks
* Edit tasks (optional)

---

### 📊 Visual Integration

* Bubble color can reflect:

  * 🟢 All tasks completed
  * 🟠 Some tasks pending
  * ⚪ No tasks

---

## 🎨 Responsive UI

* Adapts to all screen sizes
* Uses **square grid → perfect circles**
* Clean and minimal design

---

## 📱 Wallpaper Capability (Future Scope)

* Convert UI → Image
* Set as wallpaper (Android)

---

## 🧠 Concept

The app divides the screen into **equal square units**, and each unit renders a **circular bubble**:

* 🟢 Completed → Green
* ⚪ Remaining → Gray
* 🟠 Current → Highlighted
* 🔵 Has tasks → Optional indicator

---

## 🛠️ Tech Stack

* Flutter 💙
* Dart
* GridView / CustomPainter
* Hive (Local Storage)
* MediaQuery (responsive layout)

---

## 💾 Data Storage

The app uses **Hive (NoSQL local database)** to store tasks.

### Example Data Model:

```dart
{
  "2026-03-29": [
    { "task": "Workout", "done": true },
    { "task": "Study Flutter", "done": false }
  ]
}
```

---

## 📂 Project Structure

```bash
lib/
│── main.dart
│── screens/
│   ├── year_view.dart
│   ├── month_view.dart
│   ├── week_view.dart
│   ├── day_view.dart
│   └── task_screen.dart
│── widgets/
│   └── bubble_widget.dart
│── models/
│   └── task_model.dart
│── services/
│   └── hive_service.dart
```

---

## 📚 Documentation

- [Complete Task Management Guide](docs/COMPLETE_TASK_MANAGEMENT_GUIDE.md)
- [Production Architecture Roadmap](docs/PRODUCTION_ARCHITECTURE.md)

---

## ⚙️ Installation

```bash
git clone <your-repo-url>
cd your-project
flutter pub get
flutter run
```

---


## 🔄 Working Sync Starter

This repository now includes a minimal FastAPI + MongoDB backend and a Flutter WebSocket client service for live task sync:

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

On Windows/PowerShell, run the repository checks with:

```powershell
.\run.ps1
```

- Backend health check: `http://localhost:8000`
- REST API endpoint: `http://<your-windows-ip>:8000/tasks`
- WebSocket endpoint: `ws://<your-windows-ip>:8000/ws?user_id=dev-user`
- Production API endpoint: `https://api.momentum.com`
- Production WebSocket endpoint: `wss://api.momentum.com/ws`
- Development owner header: `X-User-Id: dev-user`
- Flutter REST client: `lib/services/api_client.dart`
- Flutter sync helper: `lib/services/sync_service.dart`

Working flow:

```text
Windows Flutter → WebSocket → FastAPI → MongoDB → Broadcast → Mobile Flutter
Mobile Flutter → WebSocket → FastAPI → MongoDB → Broadcast → Windows Flutter
```

---
## 🐛 Troubleshooting

### Windows `LNK1168` / `momentum.exe` cannot be opened for writing?
- This means the previous Windows app process is still running and locking `build\windows\x64\runner\Debug\momentum.exe`.
- Close the running Momentum/Bubble Time Progress window, or stop it from Task Manager.
- If needed, run `taskkill /F /IM momentum.exe`, then run `flutter clean` and launch again with `flutter run -d windows`.

### Android Kotlin daemon `Could not close incremental caches`?
- This is usually a stale Gradle/Kotlin daemon or corrupted generated cache, often under `build\image_picker_android\kotlin`.
- Run `powershell -ExecutionPolicy Bypass -File .\activate.ps1`; the script stops the related daemons and clears generated build caches before rebuilding.

### Test mobile/laptop API sync locally

Start the API:

```powershell
powershell -ExecutionPolicy Bypass -File .\server_run.ps1
```

Run the Flutter app with cloud sync pointed at your laptop LAN IP:

```powershell
powershell -ExecutionPolicy Bypass -File .\mobile_api_run.ps1 -DeviceId <device-id>
```

When enabled, task add/edit/complete/delete changes save to Hive first, then sync to FastAPI/MongoDB. Other clients pull `/tasks` and refresh when FastAPI broadcasts task WebSocket events.

---

## 📱 Build APK

```bash
flutter build apk
```

---

## 🎯 Core Logic

### Detect Click on Bubble

```dart
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TaskScreen(date: selectedDate),
    ),
  );
}
```

---

## 🎨 UI Strategy

* Use `GridView.builder`
* Calculate square size:

```dart
double size = min(screenWidth / cols, screenHeight / rows);
```

* Bubble UI:

```dart
Container(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: bubbleColor,
  ),
)
```

---

## 🔥 Future Improvements

* 🎨 Gradient heatmap (GitHub style)
* 🌙 Dark/Light themes
* 🔄 Auto-refresh UI
* 📱 Live wallpaper integration
* ✨ Animations
* ☁️ Cloud sync (Firebase)

---


## Project documentation

Project analysis and plans live in [docs/](docs/). Consult them when investigating
or extending the app, and check the implementation-status notes against current code.

- [Repository analysis and verified changes](docs/details.md)
- [Product requirements](docs/PRD.md)
- [Architecture](docs/architecture.md)
- [Technical design](docs/design.md)
- [Delivery phases](docs/phases.md)
- [Quick start](docs/QUICK_START.md)

Older implementation reports are retained in docs/ as historical references.

Offline voice tasks: see [setup, commands and verification](docs/OFFLINE_VOICE.md).
