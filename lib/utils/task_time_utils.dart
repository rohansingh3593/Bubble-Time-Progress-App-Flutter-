import '../models/task_model.dart';

const List<int> taskDurationOptions = [15, 30, 45, 60, 75, 90, 105, 120];
const int defaultTaskDurationMinutes = 15;
const String taskPhaseMarker = '---PHASES---';

class TaskPhaseInfo {
  final String name;
  final String description;
  final String status;
  final int minutes;
  final bool urgent;
  final bool important;
  final int? actualMinutes;
  final DateTime? completedAt;

  const TaskPhaseInfo({
    required this.name,
    required this.description,
    required this.status,
    required this.minutes,
    this.urgent = false,
    this.important = false,
    this.actualMinutes,
    this.completedAt,
  });

  bool get isCompleted => status.trim().toLowerCase() == 'completed';
  int get recordedMinutes => normalizeTaskDuration(actualMinutes ?? minutes);
}

int normalizeTaskDuration(int? minutes) {
  final value = minutes ?? defaultTaskDurationMinutes;
  return taskDurationOptions.contains(value) ? value : defaultTaskDurationMinutes;
}

List<TaskPhaseInfo> parseTaskPhases(String description) {
  final markerIndex = description.indexOf(taskPhaseMarker);
  if (markerIndex == -1) return const <TaskPhaseInfo>[];

  final phaseChunk = description.substring(markerIndex + taskPhaseMarker.length).trim();
  final lines = phaseChunk.split('\n').where((line) => line.trim().isNotEmpty);
  final phases = <TaskPhaseInfo>[];

  for (final line in lines) {
    final parts = line.split('|');
    if (parts.length < 3) continue;
    phases.add(
      TaskPhaseInfo(
        name: parts[0].trim(),
        description: parts[1].trim(),
        status: parts[2].trim().isEmpty ? 'Not Started' : parts[2].trim(),
        minutes: _parseDuration(parts.length > 3 ? parts[3] : null),
        urgent: _parseBool(parts.length > 4 ? parts[4] : null),
        important: _parseBool(parts.length > 5 ? parts[5] : null),
        actualMinutes: parts.length > 6 ? _parseOptionalDuration(parts[6]) : null,
        completedAt: parts.length > 7 ? DateTime.tryParse(parts[7].trim()) : null,
      ),
    );
  }

  return phases;
}

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
  final actual = actualMinutes == null ? '' : '${normalizeTaskDuration(actualMinutes)}';
  final completed = completedAt?.toIso8601String() ?? '';
  return '${name.trim()} | ${description.trim()} | $status | ${normalizeTaskDuration(minutes)} | ${urgent ? 'true' : 'false'} | ${important ? 'true' : 'false'} | $actual | $completed';
}

int taskPlannedMinutes(Task task) {
  if (task.repeatTask) return normalizeTaskDuration(task.estimatedMinutes);

  final phases = parseTaskPhases(task.description);
  if (phases.isNotEmpty) {
    return phases.fold<int>(0, (sum, phase) => sum + normalizeTaskDuration(phase.minutes));
  }

  return normalizeTaskDuration(task.estimatedMinutes);
}

int taskRecordedMinutesForDay(Task task) {
  if (task.repeatTask) {
    return _isCompletedTask(task) ? normalizeTaskDuration(task.estimatedMinutes) : 0;
  }

  final phases = parseTaskPhases(task.description);
  if (phases.isNotEmpty) {
    return phases
        .where((phase) => phase.isCompleted)
        .fold<int>(0, (sum, phase) => sum + phase.recordedMinutes);
  }

  return _isCompletedTask(task) ? taskPlannedMinutes(task) : 0;
}

bool _isCompletedTask(Task task) {
  return task.done || task.status.trim().toLowerCase() == 'completed';
}

bool _parseBool(String? rawValue) {
  final normalized = (rawValue ?? '').trim().toLowerCase();
  return normalized == 'true' || normalized == 'yes' || normalized == '1';
}

int _parseDuration(String? rawValue) {
  final parsed = int.tryParse((rawValue ?? '').replaceAll('min', '').trim());
  return normalizeTaskDuration(parsed);
}

int? _parseOptionalDuration(String? rawValue) {
  final parsed = int.tryParse((rawValue ?? '').replaceAll('min', '').trim());
  if (parsed == null) return null;
  return normalizeTaskDuration(parsed);
}
