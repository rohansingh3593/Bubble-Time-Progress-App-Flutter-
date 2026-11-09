import '../models/task_model.dart';
import '../models/task_step.dart';

const List<int> taskDurationOptions = [5, 10, 15, 30, 45, 60, 75, 90, 105, 120];
const int defaultTaskDurationMinutes = 15;
const String taskPhaseMarker = '---PHASES---';

// Compatibility name for callers that present phases rather than steps.
typedef TaskPhaseInfo = TaskStep;

/// Zero/null are the old "unspecified" values. Every positive duration is exact.
int normalizeTaskDuration(int? minutes) {
  if (minutes == null || minutes == 0) return defaultTaskDurationMinutes;
  if (minutes < 0) {
    throw ArgumentError.value(minutes, 'minutes', 'Cannot be negative');
  }
  return minutes;
}

/// Include persisted custom durations so opening a form cannot reset their value.
List<int> taskDurationChoices(int current) =>
    ({...taskDurationOptions, current}.toList()..sort());

/// Structured steps are authoritative, even when the list is empty.
List<TaskStep> taskSteps(Task task) =>
    task.steps ?? parseTaskPhases(task.description, idPrefix: task.id);

/// Legacy read path only. New/edited phases are stored as TaskStep records.
List<TaskStep> parseTaskPhases(String description, {String? idPrefix}) {
  final markerIndex = description.indexOf(taskPhaseMarker);
  if (markerIndex == -1) return const [];
  final lines =
      description.substring(markerIndex + taskPhaseMarker.length).split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (_legacyPhase(lines[i],
              id: idPrefix == null ? null : '$idPrefix:step:$i')
          case final TaskStep step)
        step,
  ];
}

TaskStep? _legacyPhase(String line, {String? id}) {
  final parts = line.split('|');
  if (parts.length < 3 || parts.length > 8) return null;
  int? minutesAt(int index) {
    if (parts.length <= index || parts[index].trim().isEmpty) return null;
    return int.tryParse(parts[index].replaceAll('min', '').trim());
  }

  final minutes = minutesAt(3);
  final actual = minutesAt(6);
  // Retain malformed rows verbatim in the description for manual recovery.
  if ((parts.length > 3 && parts[3].trim().isNotEmpty && minutes == null) ||
      (parts.length > 6 && parts[6].trim().isNotEmpty && actual == null) ||
      (minutes != null && minutes < 0) ||
      (actual != null && actual < 0)) {
    return null;
  }
  final completed = parts.length > 7 && parts[7].trim().isNotEmpty
      ? DateTime.tryParse(parts[7].trim())
      : null;
  if (parts.length > 7 && parts[7].trim().isNotEmpty && completed == null) {
    return null;
  }
  return TaskStep(
    id: id,
    name: parts[0].trim(),
    description: parts[1].trim(),
    status: parts[2].trim().isEmpty ? 'Not Started' : parts[2].trim(),
    minutes: normalizeTaskDuration(minutes),
    urgent: parts.length > 4 && _parseBool(parts[4]),
    important: parts.length > 5 && _parseBool(parts[5]),
    actualMinutes: actual,
    completedAt: completed,
  );
}

/// Hides migrated phase rows in the editor, preserving unrecognized legacy text.
String taskDescriptionForEditing(Task task) {
  final description = task.description;
  final markerIndex = description.indexOf(taskPhaseMarker);
  if (markerIndex == -1) return description;
  final remaining = description
      .substring(markerIndex + taskPhaseMarker.length)
      .split('\n')
      .where((line) => line.trim().isNotEmpty && _legacyPhase(line) == null);
  return [description.substring(0, markerIndex).trim(), ...remaining]
      .where((part) => part.isNotEmpty)
      .join('\n');
}

/// Kept for importing/exporting the old text format, never used for app storage.
String serializeTaskPhase({
  required String name,
  required String description,
  required String status,
  required int minutes,
  bool urgent = false,
  bool important = false,
  int? actualMinutes,
  DateTime? completedAt,
}) {
  if (actualMinutes != null && actualMinutes < 0) {
    throw ArgumentError.value(actualMinutes, 'actualMinutes');
  }
  final actual = actualMinutes == null ? '' : '$actualMinutes';
  final completed = completedAt?.toIso8601String() ?? '';
  return '${name.trim()} | ${description.trim()} | $status | ${normalizeTaskDuration(minutes)} | $urgent | $important | $actual | $completed';
}

int taskPlannedMinutes(Task task) {
  if (task.repeatTask) return normalizeTaskDuration(task.estimatedMinutes);
  final steps = taskSteps(task);
  if (steps.isNotEmpty) {
    return steps.fold<int>(0, (sum, step) => sum + step.minutes);
  }
  return normalizeTaskDuration(task.estimatedMinutes);
}

int taskRecordedMinutesForDay(Task task) {
  if (!task.repeatTask) {
    final steps = taskSteps(task);
    if (steps.isNotEmpty) {
      return steps
          .where((step) => step.isCompleted)
          .fold<int>(0, (sum, step) => sum + step.recordedMinutes);
    }
  }
  return _isCompletedTask(task) ? taskPlannedMinutes(task) : 0;
}

bool _isCompletedTask(Task task) =>
    task.done || task.status.trim().toLowerCase() == 'completed';
bool _parseBool(String value) =>
    const ['true', 'yes', '1'].contains(value.trim().toLowerCase());
