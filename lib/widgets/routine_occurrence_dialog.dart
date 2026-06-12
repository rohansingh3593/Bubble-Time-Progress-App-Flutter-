import 'package:flutter/material.dart';

import '../models/instruction.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';

enum RoutineOccurrenceAction {
  openJournal,
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

bool isDailyJournalSystemTask(Task task) {
  return task.task.trim().toLowerCase() == 'daily journal' &&
      task.category.trim().toLowerCase() == 'journal';
}

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
  required HiveService hiveService,
}) {
  if (isDailyJournalSystemTask(task)) {
    return _showDailyJournalDialog(context: context, task: task);
  }

  final occurrenceUpdated = isRoutineOccurrenceUpdated(task);

  final linkedInstructions = _linkedInstructionsForTask(hiveService, task);
  final selectedStatuses = <String, String>{};
  for (final instruction in linkedInstructions) {
    selectedStatuses[instruction.id] = hiveService.instructionEntryForDate(instruction, task.dueDate)?.status ?? InstructionHistoryEntry.statusNotApplicable;
  }

  return showDialog<RoutineOccurrenceAction>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Update ${task.task} Occurrence'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  occurrenceUpdated
                      ? 'This occurrence is already updated.\n\n${_updatedSummary(task)}\n\nRoutine details are locked here. Use Edit Routine Details to change the routine itself.'
                      : 'Routine details are locked here. Update only the current occurrence, or pause the routine without deleting its history.',
                ),
                const SizedBox(height: 14),
                const Text('Linked Instructions', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (linkedInstructions.isEmpty)
                  const Text('No instructions are linked to this task yet.', style: TextStyle(color: Colors.black54))
                else
                  ...linkedInstructions.map((instruction) {
                    final selected = selectedStatuses[instruction.id] ?? InstructionHistoryEntry.statusNotApplicable;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(instruction.colorValue).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Color(instruction.colorValue).withOpacity(0.18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(instruction.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          if (instruction.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(instruction.description, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              _instructionStatusChoice(
                                label: 'Followed +${instruction.bonusPoints}',
                                value: InstructionHistoryEntry.statusFollowed,
                                selected: selected,
                                enabled: !occurrenceUpdated,
                                onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusFollowed),
                              ),
                              _instructionStatusChoice(
                                label: 'Missed',
                                value: InstructionHistoryEntry.statusMissed,
                                selected: selected,
                                enabled: !occurrenceUpdated,
                                onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusMissed),
                              ),
                              _instructionStatusChoice(
                                label: 'N/A',
                                value: InstructionHistoryEntry.statusNotApplicable,
                                selected: selected,
                                enabled: !occurrenceUpdated,
                                onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusNotApplicable),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
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
                : () async {
                    await _saveLinkedInstructionStatuses(hiveService, task, linkedInstructions, selectedStatuses);
                    if (context.mounted) Navigator.of(context).pop(RoutineOccurrenceAction.missOccurrence);
                  },
            child: const Text('Miss This Occurrence'),
          ),
          ElevatedButton(
            onPressed: !task.routineEnabled || occurrenceUpdated
                ? null
                : () async {
                    await _saveLinkedInstructionStatuses(hiveService, task, linkedInstructions, selectedStatuses);
                    if (context.mounted) Navigator.of(context).pop(RoutineOccurrenceAction.completeOccurrence);
                  },
            child: const Text('Save & Complete Occurrence'),
          ),
        ],
      ),
    ),
  );
}



List<InstructionRule> _linkedInstructionsForTask(HiveService hiveService, Task task) {
  final taskName = task.task.trim().toLowerCase();
  return hiveService.getInstructions().where((instruction) {
    return instruction.enabled && instruction.linkedTask.trim().toLowerCase() == taskName;
  }).toList();
}

Widget _instructionStatusChoice({
  required String label,
  required String value,
  required String selected,
  required bool enabled,
  required VoidCallback onSelected,
}) {
  return ChoiceChip(
    selected: selected == value,
    label: Text(label),
    onSelected: enabled ? (_) => onSelected() : null,
  );
}

Future<void> _saveLinkedInstructionStatuses(
  HiveService hiveService,
  Task task,
  List<InstructionRule> instructions,
  Map<String, String> selectedStatuses,
) async {
  for (final instruction in instructions) {
    final status = selectedStatuses[instruction.id] ?? InstructionHistoryEntry.statusNotApplicable;
    await hiveService.updateInstructionStatus(
      instruction,
      task.dueDate,
      status,
      note: 'Task occurrence: ${task.task} • ${routineOccurrenceLabel(task)}',
    );
  }
}

Future<RoutineOccurrenceAction?> _showDailyJournalDialog({
  required BuildContext context,
  required Task task,
}) {
  final completed = task.done || _normalizedStatus(task) == 'completed';
  final missed = _normalizedStatus(task) == 'missed';
  final status = completed
      ? 'Completed ✅'
      : missed
          ? 'Missed ❌'
          : 'Pending';
  final completedTime = completed ? _timeLabel(task) : null;
  final guidance = completed
      ? 'Your reflection is saved${completedTime == null ? '.' : ' at $completedTime.'}\n\nYou can view or edit the journal entry without earning duplicate points.'
      : missed
          ? 'No journal was written for this day. Open Journal to review your history.'
          : 'Complete this task by writing and saving today’s reflection.';

  return showDialog<RoutineOccurrenceAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('📔 Daily Journal'),
      content: Text('Status: $status\n\n$guidance'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.close),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.openJournal),
          icon: const Icon(Icons.menu_book_rounded),
          label: Text(completed ? 'View / Edit Journal' : 'Open Journal'),
        ),
      ],
    ),
  );
}
