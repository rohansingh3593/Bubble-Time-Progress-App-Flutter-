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

bool hasTaskLinkedInstructions(HiveService hiveService, Task task) => _linkedInstructionsForTask(hiveService, task).isNotEmpty;

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
    final entry = hiveService.instructionEntryForDate(instruction, task.dueDate);
    selectedStatuses[instruction.id] = entry?.hasLevel == true ? 'level:${entry!.levelId}' : (entry?.status ?? InstructionHistoryEntry.statusNotApplicable);
  }
  var occurrenceStatus = '';

  return showDialog<RoutineOccurrenceAction>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final savedCompleted = task.done || _normalizedStatus(task) == 'completed';
        final savedMissed = _normalizedStatus(task) == 'missed' || _normalizedStatus(task) == 'cancelled' || _normalizedStatus(task) == 'overdue';
        final savedInstructionResults = linkedInstructions.any(
          (instruction) => hiveService.instructionEntryForDate(instruction, task.dueDate) != null,
        );
        final showCompletionSummary = linkedInstructions.isNotEmpty && !savedMissed && (savedCompleted || savedInstructionResults);
        final taskCompleted = showCompletionSummary || occurrenceStatus == 'completed';
        final taskMissed = occurrenceStatus == 'missed';
        final instructionChoicesEnabled = !occurrenceUpdated && taskCompleted;
        if (showCompletionSummary) {
          return _completionSummaryDialog(context, task, linkedInstructions, hiveService);
        }
        return AlertDialog(
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
                        : 'Choose the occurrence status first. Linked instruction bonuses can only be updated when the task is completed.',
                  ),
                  const SizedBox(height: 14),
                  const Text('Task Status', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        selected: taskCompleted,
                        label: const Text('Completed'),
                        onSelected: !task.routineEnabled || occurrenceUpdated
                            ? null
                            : (_) => setDialogState(() => occurrenceStatus = 'completed'),
                      ),
                      ChoiceChip(
                        selected: taskMissed,
                        label: const Text('Missed'),
                        onSelected: !task.routineEnabled || occurrenceUpdated
                            ? null
                            : (_) => setDialogState(() => occurrenceStatus = 'missed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Linked Instructions', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (linkedInstructions.isNotEmpty && !taskCompleted && !occurrenceUpdated)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Complete the task first to update linked instructions.',
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
                              children: instruction.isLevelBased
                                  ? [
                                      _instructionStatusChoice(
                                        label: 'Missed',
                                        value: InstructionHistoryEntry.statusMissed,
                                        selected: selected,
                                        enabled: instructionChoicesEnabled,
                                        onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusMissed),
                                      ),
                                      ...instruction.levels.map((level) => _instructionStatusChoice(
                                            label: '${level.displayLabel} (+${level.bonusPoints})',
                                            value: 'level:${level.id}',
                                            selected: selected,
                                            enabled: instructionChoicesEnabled,
                                            onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = 'level:${level.id}'),
                                          )),
                                      _instructionStatusChoice(
                                        label: 'N/A',
                                        value: InstructionHistoryEntry.statusNotApplicable,
                                        selected: selected,
                                        enabled: instructionChoicesEnabled,
                                        onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusNotApplicable),
                                      ),
                                    ]
                                  : [
                                      _instructionStatusChoice(
                                        label: 'Followed +${instruction.bonusPoints}',
                                        value: InstructionHistoryEntry.statusFollowed,
                                        selected: selected,
                                        enabled: instructionChoicesEnabled,
                                        onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusFollowed),
                                      ),
                                      _instructionStatusChoice(
                                        label: 'Missed',
                                        value: InstructionHistoryEntry.statusMissed,
                                        selected: selected,
                                        enabled: instructionChoicesEnabled,
                                        onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusMissed),
                                      ),
                                      _instructionStatusChoice(
                                        label: 'N/A',
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
            if (isRoutineTask(task))
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
              child: Text(isRoutineTask(task) ? 'Edit Routine Details' : 'Edit Task Details'),
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




AlertDialog _completionSummaryDialog(
  BuildContext context,
  Task task,
  List<InstructionRule> linkedInstructions,
  HiveService hiveService,
) {
  final completedTime = _timeLabel(task) ?? 'Saved for ${routineOccurrenceLabel(task)}';
  final entries = [
    for (final instruction in linkedInstructions)
      MapEntry(instruction, hiveService.instructionEntryForDate(instruction, task.dueDate)),
  ];
  final followedCount = entries.where((entry) => entry.value?.followed ?? false).length;
  final instructionBonus = entries.fold<int>(0, (sum, entry) => sum + (entry.value?.bonusPoints ?? 0));
  final xpBonus = entries.fold<int>(0, (sum, entry) => sum + (entry.value?.xpEarned ?? 0));
  final mood = _completionMood(followedCount, linkedInstructions.length);
  final basePoints = task.priority.trim().toLowerCase() == 'high' ? 30 : task.priority.trim().toLowerCase() == 'low' ? 10 : 20;
  final totalPoints = basePoints + instructionBonus;

  return AlertDialog(
    title: const Text('✅ Task Completed'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Task: ${task.task}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Completed at: $completedTime'),
            const Divider(height: 28),
            const Text('📋 Instructions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            ...entries.map((entry) {
              final instruction = entry.key;
              final history = entry.value;
              final followed = history?.followed ?? false;
              final points = history?.bonusPoints ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(followed ? '✅' : '❌', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(instruction.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            '${followed ? 'Followed' : 'Missed'} • +$points bonus points',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            Text('Instruction Progress: $followedCount / ${linkedInstructions.length} Completed', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Current Emoji: ${mood.emoji} ${mood.label}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const Divider(height: 28),
            const Text('🏆 Reward Summary', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            _rewardLine('Base Points', basePoints),
            _rewardLine('Instruction Bonus', instructionBonus),
            _rewardLine('Timing Bonus', 0),
            _rewardLine('Streak Bonus', 0),
            _rewardLine('Instruction XP', xpBonus),
            const SizedBox(height: 6),
            _rewardLine('Total Points', totalPoints, bold: true),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.close),
        child: const Text('Close'),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.close),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('View Details'),
      ),
    ],
  );
}

Widget _rewardLine(String label, int points, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
        Text('+$points', style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
      ],
    ),
  );
}

_CompletionMood _completionMood(int followed, int total) {
  if (total <= 0) return const _CompletionMood('🙂', 'Completed');
  final ratio = followed / total;
  if (ratio >= 1) return const _CompletionMood('🤩', 'Perfect Execution');
  if (ratio >= 0.5) return const _CompletionMood('😊', 'Good Completion');
  if (ratio > 0) return const _CompletionMood('🙂', 'Completed');
  return const _CompletionMood('😐', 'Instructions Ignored');
}

class _CompletionMood {
  final String emoji;
  final String label;

  const _CompletionMood(this.emoji, this.label);
}

List<InstructionRule> _linkedInstructionsForTask(HiveService hiveService, Task task) {
  final taskName = task.task.trim();
  return hiveService.getInstructions().where((instruction) {
    return instruction.enabled && instruction.isLinkedToTask(taskName);
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
  Map<String, String> selectedStatuses, {
  required bool occurrenceCompleted,
}) async {
  for (final instruction in instructions) {
    final rawStatus = occurrenceCompleted
        ? selectedStatuses[instruction.id] ?? InstructionHistoryEntry.statusNotApplicable
        : InstructionHistoryEntry.statusMissed;
    final isLevelStatus = rawStatus.startsWith('level:');
    final level = isLevelStatus
        ? instruction.levels.firstWhere((item) => item.id == rawStatus.substring('level:'.length), orElse: () => instruction.levels.first)
        : null;
    await hiveService.updateInstructionStatus(
      instruction,
      task.dueDate,
      isLevelStatus ? InstructionHistoryEntry.statusFollowed : rawStatus,
      level: level,
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
