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
│── utils/
│   ├── date_utils.dart
│   └── grid_utils.dart
│── constants/
│   └── colors.dart
```

---

## ▶️ Quick Start

### Prerequisites
- **Flutter SDK**: v3.0.0 or higher
- **Dart SDK**: Included with Flutter
- **Android/iOS SDK**: For running on devices or emulators

### Getting Started

1. **Clone & Navigate**:
   ```bash
   cd Bubble-Time-Progress-App-Flutter-
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Hive Adapters** (if needed):
   ```bash
   flutter pub run build_runner build
   ```

4. **Run the App**:
   ```bash
   flutter run
   ```
   - On Android: Connects to Android emulator or physical device
   - On iOS: Requires Xcode (macOS only)
   - On Web: Run with `-d chrome`
   - On Desktop: Run with `-d windows`, `-d linux`, or `-d macos`

### Example Commands

```bash
# Run on specific device
flutter run -d <device-id>

# Run in release mode
flutter run --release

# Build APK (Android)
flutter build apk

# Build IPA (iOS)
flutter build ios

# Build web
flutter build web

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Troubleshooting

- **Gradle errors on Android?**  
  Run `flutter clean` and then `flutter pub get`

- **Hive adapter not found?**  
  Run `flutter pub run build_runner build --delete-conflicting-outputs`

- **Module imports failing?**  
  Verify all imports use the correct relative paths (e.g., `../utils/date_utils.dart`)

---

---

## ⚙️ Installation

```bash
git clone <your-repo-url>
cd your-project
flutter pub get
flutter run
```

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


