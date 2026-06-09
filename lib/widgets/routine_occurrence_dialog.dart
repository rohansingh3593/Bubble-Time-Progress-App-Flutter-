import 'package:flutter/material.dart';

import '../models/task_model.dart';

enum RoutineOccurrenceAction {
  disableRoutine,
  close,
  editDetails,
  missOccurrence,
  completeOccurrence,
}

String normalizedRoutineFrequency(Task task) {
  final normalized = task.repeatFrequency?.trim().toLowerCase();
  switch (normalized) {
    case 'daily':
    case 'weekly':
    case 'monthly':
    case 'yearly':
      return normalized!;
    default:
      return '';
  }
}

bool isRoutineTask(Task task) => task.repeatTask && normalizedRoutineFrequency(task).isNotEmpty;

String _normalizedStatus(Task task) => task.status.trim().toLowerCase();

bool isRoutineOccurrenceUpdated(Task task) {
  final status = _normalizedStatus(task);
  return task.done || status == 'completed' || status == 'cancelled' || status == 'missed' || status == 'overdue';
}

String routineOccurrenceLabel(Task task) {
  switch (normalizedRoutineFrequency(task)) {
    case 'daily':
      return 'today';
    case 'weekly':
      return 'this week';
    case 'monthly':
      return 'this month';
    case 'yearly':
      return 'this year';
    default:
      return 'this occurrence';
  }
}

String _statusLabel(Task task) {
  if (task.done || _normalizedStatus(task) == 'completed') return 'completed';
  final status = task.status.trim();
  return status.isEmpty ? 'updated' : status.toLowerCase();
}

String _updatedSummary(Task task) {
  final time = _timeLabel(task);
  final occurrence = routineOccurrenceLabel(task);
  final when = time == null ? occurrence : '$occurrence at $time';
  return '${task.task} ${_statusLabel(task)} $when.';
}

String? _timeLabel(Task task) {
  if (task.dueDate.hour == 0 && task.dueDate.minute == 0 && task.hourSlot == null) {
    return null;
  }

  final hour = task.hourSlot ?? task.dueDate.hour;
  final minute = task.hourSlot == null ? task.dueDate.minute : 0;
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final displayMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $period';
}

Future<RoutineOccurrenceAction?> showRoutineOccurrenceDialog({
  required BuildContext context,
  required Task task,
}) {
  final occurrenceUpdated = isRoutineOccurrenceUpdated(task);

  return showDialog<RoutineOccurrenceAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Update ${task.task} Occurrence'),
      content: Text(
        occurrenceUpdated
            ? 'This occurrence is already updated.\n\n${_updatedSummary(task)}\n\nRoutine details are locked here. Use Edit Routine Details to change the routine itself.'
            : 'Routine details are locked here. Update only the current occurrence, or pause the routine without deleting its history.',
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.disableRoutine),
          icon: const Icon(Icons.pause_circle_outline),
          label: const Text('Disable Routine'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.close),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.editDetails),
          child: const Text('Edit Routine Details'),
        ),
        TextButton(
          onPressed: !task.routineEnabled || occurrenceUpdated
              ? null
              : () => Navigator.of(context).pop(RoutineOccurrenceAction.missOccurrence),
          child: const Text('Miss This Occurrence'),
        ),
        ElevatedButton(
          onPressed: !task.routineEnabled || occurrenceUpdated
              ? null
              : () => Navigator.of(context).pop(RoutineOccurrenceAction.completeOccurrence),
          child: const Text('Complete This Occurrence'),
        ),
      ],
    ),
  );
}
