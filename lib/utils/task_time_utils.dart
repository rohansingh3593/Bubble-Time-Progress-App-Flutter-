import '../models/task_model.dart';

const List<int> taskDurationOptions = [15, 30, 45, 60, 75, 90, 105, 120];
const int defaultTaskDurationMinutes = 15;
const String taskPhaseMarker = '---PHASES---';

class TaskPhaseInfo {
  final String name;
  final String description;
  final String status;
  final int minutes;

  const TaskPhaseInfo({
    required this.name,
    required this.description,
    required this.status,
    required this.minutes,
  });

  bool get isCompleted => status.trim().toLowerCase() == 'completed';
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
}) {
  return '${name.trim()} | ${description.trim()} | $status | ${normalizeTaskDuration(minutes)}';
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
        .fold<int>(0, (sum, phase) => sum + normalizeTaskDuration(phase.minutes));
  }

  return _isCompletedTask(task) ? taskPlannedMinutes(task) : 0;
}

bool _isCompletedTask(Task task) {
  return task.done || task.status.trim().toLowerCase() == 'completed';
}
