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
  var occurrenceStatus = '';

  return showDialog<RoutineOccurrenceAction>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final taskCompleted = occurrenceStatus == 'completed';
        final taskMissed = occurrenceStatus == 'missed';
        final instructionChoicesEnabled = !occurrenceUpdated && taskCompleted;
        final followedCount = linkedInstructions.where((instruction) => selectedStatuses[instruction.id] == InstructionHistoryEntry.statusFollowed).length;
        final currentEmoji = _routineDialogMood(taskCompleted, taskMissed, followedCount, linkedInstructions.length);
        final instructionProgressLabel = linkedInstructions.isEmpty ? 'No linked instructions' : '$followedCount / ${linkedInstructions.length} Complete';
        final remainingXp = linkedInstructions.fold<int>(0, (sum, instruction) {
          return sum + (selectedStatuses[instruction.id] == InstructionHistoryEntry.statusFollowed ? 0 : instruction.xpEarned);
        });
        return AlertDialog(
          title: Text('Update ${task.task} Today'),
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
                        : 'Choose the task status first. Completing the task unlocks linked instructions, but instructions must still be confirmed manually.',
                  ),
                  const SizedBox(height: 14),
                  const Text('Task Status', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        selected: taskCompleted,
                        label: const Text('☑ Complete'),
                        onSelected: !task.routineEnabled || occurrenceUpdated
                            ? null
                            : (_) => setDialogState(() => occurrenceStatus = 'completed'),
                      ),
                      ChoiceChip(
                        selected: taskMissed,
                        label: const Text('☐ Missed'),
                        onSelected: !task.routineEnabled || occurrenceUpdated
                            ? null
                            : (_) => setDialogState(() => occurrenceStatus = 'missed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text('Instructions', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentEmoji.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: currentEmoji.color.withOpacity(0.24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Emoji  ${currentEmoji.emoji} ${currentEmoji.label}', style: TextStyle(color: currentEmoji.color, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(instructionProgressLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (taskCompleted && linkedInstructions.isNotEmpty && followedCount < linkedInstructions.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Potential: 🤩 Complete remaining instructions for +$remainingXp XP', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (linkedInstructions.isNotEmpty && !taskCompleted && !occurrenceUpdated)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '🔒 Complete the task first to unlock its instructions.',
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (linkedInstructions.isEmpty)
                    const Text('No instructions are linked to this task yet.', style: TextStyle(color: Colors.black54))
                  else
                    ...linkedInstructions.map((instruction) {
                      final selected = taskMissed
                          ? InstructionHistoryEntry.statusMissed
                          : selectedStatuses[instruction.id] ?? InstructionHistoryEntry.statusNotApplicable;
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
                                  label: instructionChoicesEnabled ? '☑ Followed +${instruction.bonusPoints}' : '🔒 Followed +${instruction.bonusPoints}',
                                  value: InstructionHistoryEntry.statusFollowed,
                                  selected: selected,
                                  enabled: instructionChoicesEnabled,
                                  onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusFollowed),
                                ),
                                _instructionStatusChoice(
                                  label: instructionChoicesEnabled ? '☐ Missed' : '🔒 Missed',
                                  value: InstructionHistoryEntry.statusMissed,
                                  selected: selected,
                                  enabled: instructionChoicesEnabled,
                                  onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusMissed),
                                ),
                                _instructionStatusChoice(
                                  label: instructionChoicesEnabled ? '○ N/A' : '🔒 N/A',
                                  value: InstructionHistoryEntry.statusNotApplicable,
                                  selected: selected,
                                  enabled: instructionChoicesEnabled,
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
            ElevatedButton(
              onPressed: !task.routineEnabled || occurrenceUpdated || occurrenceStatus.isEmpty
                  ? null
                  : () async {
                      final completed = occurrenceStatus == 'completed';
                      await _saveLinkedInstructionStatuses(
                        hiveService,
                        task,
                        linkedInstructions,
                        selectedStatuses,
                        occurrenceCompleted: completed,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(completed ? RoutineOccurrenceAction.completeOccurrence : RoutineOccurrenceAction.missOccurrence);
                      }
                    },
              child: const Text('Save Occurrence'),
            ),
          ],
        );
      },
    ),
  );
}



List<InstructionRule> _linkedInstructionsForTask(HiveService hiveService, Task task) {
  final taskName = task.task.trim();
  return hiveService.getInstructions().where((instruction) {
    return instruction.enabled && instruction.isLinkedToTask(taskName);
  }).toList();
}


class _RoutineDialogMood {
  final String emoji;
  final String label;
  final Color color;

  const _RoutineDialogMood({required this.emoji, required this.label, required this.color});
}

_RoutineDialogMood _routineDialogMood(bool taskCompleted, bool taskMissed, int followed, int total) {
  if (taskMissed) return const _RoutineDialogMood(emoji: '😞', label: 'Missed Today', color: Colors.redAccent);
  if (!taskCompleted) return const _RoutineDialogMood(emoji: '➖', label: 'Complete task first', color: Colors.blueGrey);
  if (total == 0) return const _RoutineDialogMood(emoji: '🤩', label: 'Task Complete', color: Colors.green);
  final ratio = followed / total;
  if (ratio >= 1) return const _RoutineDialogMood(emoji: '🤩', label: 'Perfect', color: Colors.green);
  if (ratio >= 0.75) return const _RoutineDialogMood(emoji: '😄', label: 'Excellent', color: Colors.lightGreen);
  if (ratio >= 0.5) return const _RoutineDialogMood(emoji: '😊', label: 'Good', color: Colors.amber);
  if (followed > 0) return const _RoutineDialogMood(emoji: '🙂', label: 'Can Improve', color: Colors.blueAccent);
  return const _RoutineDialogMood(emoji: '😐', label: 'Instructions Ignored', color: Colors.blueGrey);
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
  Map<String, String> selectedStatuses, {
  required bool occurrenceCompleted,
}) async {
  for (final instruction in instructions) {
    final status = occurrenceCompleted
        ? selectedStatuses[instruction.id] ?? InstructionHistoryEntry.statusNotApplicable
        : InstructionHistoryEntry.statusMissed;
    await hiveService.updateInstructionStatus(
      instruction,
      task.dueDate,
      status,
      note: 'Task occurrence: ${task.task} • ${routineOccurrenceLabel(task)} • ${occurrenceCompleted ? 'completed' : 'missed'}',
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
