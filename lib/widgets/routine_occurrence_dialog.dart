import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';
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
  savedOccurrence,
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

bool hasTaskLinkedInstructions(HiveService hiveService, Task task) {
  return _linkedInstructionsForTask(hiveService, task, includeDisabled: true).isNotEmpty;
}

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

  final routineTask = isRoutineTask(task);
  final style = DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
  final occurrenceUpdated = isRoutineOccurrenceUpdated(task);
  final existingCompleted = task.done || _normalizedStatus(task) == 'completed';
  final existingMissed = _normalizedStatus(task) == 'missed' || _normalizedStatus(task) == 'overdue';

  final linkedInstructions = _linkedInstructionsForTask(hiveService, task);
  final selectedStatuses = <String, String>{};
  for (final instruction in linkedInstructions) {
    final existingStatus = hiveService.instructionEntryForDate(instruction, task.dueDate)?.status;
    selectedStatuses[instruction.id] = existingStatus == InstructionHistoryEntry.statusFollowed || existingStatus == InstructionHistoryEntry.statusMissed
        ? existingStatus!
        : '';
  }
  var occurrenceStatus = existingCompleted
      ? 'completed'
      : existingMissed
          ? 'missed'
          : '';

  return showDialog<RoutineOccurrenceAction>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final taskCompleted = occurrenceStatus == 'completed';
        final taskMissed = occurrenceStatus == 'missed';
        final readOnly = occurrenceUpdated;
        final instructionChoicesEnabled = !readOnly && taskCompleted;
        final followedCount = linkedInstructions.where((instruction) => selectedStatuses[instruction.id] == InstructionHistoryEntry.statusFollowed).length;
        final allInstructionsSelected = linkedInstructions.every((instruction) {
          final status = selectedStatuses[instruction.id];
          return status == InstructionHistoryEntry.statusFollowed || status == InstructionHistoryEntry.statusMissed;
        });
        final currentEmoji = _routineDialogMood(style, taskCompleted, taskMissed, followedCount, linkedInstructions.length);
        final instructionProgressLabel = linkedInstructions.isEmpty ? 'No linked instructions' : '$followedCount / ${linkedInstructions.length} Completed';
        final reward = _routineDialogReward(task, linkedInstructions, selectedStatuses, taskCompleted: taskCompleted);
        final canSaveCompleted = taskCompleted && allInstructionsSelected;

        return AlertDialog(
          title: Text(readOnly
              ? '${existingCompleted ? '✅ Already Completed Today' : '⚠️ Already Updated Today'}'
              : taskCompleted
                  ? '✅ ${task.task} Completed'
                  : '📝 ${task.task}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 540,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (readOnly) ...[
                    Text(
                      existingCompleted
                          ? 'Completed at: ${_timeLabel(task) ?? 'Recorded today'}\n\nThis record is view only.'
                          : '${_updatedSummary(task)}\n\nThis record is view only.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ] else ...[
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: !task.routineEnabled ? null : () => setDialogState(() => occurrenceStatus = 'completed'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete This Task'),
                        ),
                        OutlinedButton.icon(
                          onPressed: !task.routineEnabled
                              ? null
                              : () async {
                                  await _saveRoutineOccurrence(
                                    hiveService: hiveService,
                                    task: task,
                                    completed: false,
                                    linkedInstructions: linkedInstructions,
                                    selectedStatuses: selectedStatuses,
                                  );
                                  if (context.mounted) Navigator.of(context).pop(RoutineOccurrenceAction.savedOccurrence);
                                },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Miss This Task'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      taskCompleted
                          ? 'Task marked complete in this popup. Instructions are unlocked; choose Followed or Missed for each one, then Save & Finish.'
                          : 'Instructions are locked until you complete the task first.',
                      style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text('📋 Instructions', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (linkedInstructions.isNotEmpty && !taskCompleted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '🔒 Complete the task first to unlock instructions.',
                        style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (linkedInstructions.isEmpty)
                    Text('No instructions are linked to this task yet.', style: TextStyle(color: style.textMuted))
                  else
                    ...linkedInstructions.map((instruction) {
                      final selected = taskMissed ? '' : selectedStatuses[instruction.id] ?? '';
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
                                child: Text(instruction.description, style: TextStyle(color: style.textMuted, fontSize: 12)),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _instructionRadioOption(
                                  label: 'Followed +${instruction.bonusPoints}',
                                  value: InstructionHistoryEntry.statusFollowed,
                                  selected: selected,
                                  enabled: instructionChoicesEnabled,
                                  style: style,
                                  onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusFollowed),
                                ),
                                _instructionRadioOption(
                                  label: 'Missed',
                                  value: InstructionHistoryEntry.statusMissed,
                                  selected: selected,
                                  enabled: instructionChoicesEnabled,
                                  style: style,
                                  onSelected: () => setDialogState(() => selectedStatuses[instruction.id] = InstructionHistoryEntry.statusMissed),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
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
                        Text('Instruction Progress: $instructionProgressLabel', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Current Emoji  ${currentEmoji.emoji} ${currentEmoji.label}', style: TextStyle(color: currentEmoji.color, fontWeight: FontWeight.w900)),
                        if (taskCompleted && linkedInstructions.isNotEmpty && followedCount < linkedInstructions.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Potential Reward: 🤩 Complete all instructions for bonus XP', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Bonus ${readOnly ? 'Earned' : 'Preview'}: +${reward.totalXp} XP • +${reward.coins} Coins${reward.onTime ? ' • 🎯 On Time' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Base +${reward.baseXp} XP • Instructions +${reward.instructionXp} XP • Timing +${reward.timingXp} XP • Streak +${reward.streakXp} XP',
                          style: TextStyle(color: style.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (!readOnly && taskCompleted && linkedInstructions.isNotEmpty && !allInstructionsSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Select Followed or Missed for every instruction before saving.', style: TextStyle(color: style.accent, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
          ),
          actions: readOnly
              ? [
                  const TextButton(onPressed: null, child: Text('View Only')),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(RoutineOccurrenceAction.close), child: const Text('Close')),
                ]
              : [
                  if (routineTask)
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
                    child: Text(routineTask ? 'Edit Routine Details' : 'Edit Task Details'),
                  ),
                  ElevatedButton.icon(
                    onPressed: !canSaveCompleted
                        ? null
                        : () async {
                            await _saveRoutineOccurrence(
                              hiveService: hiveService,
                              task: task,
                              completed: true,
                              linkedInstructions: linkedInstructions,
                              selectedStatuses: selectedStatuses,
                            );
                            if (context.mounted) Navigator.of(context).pop(RoutineOccurrenceAction.savedOccurrence);
                          },
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save & Finish'),
                  ),
                ],
        );
      },
    ),
  );
}


List<InstructionRule> _linkedInstructionsForTask(HiveService hiveService, Task task, {bool includeDisabled = false}) {
  final taskName = task.task.trim();
  return hiveService.getInstructions().where((instruction) {
    return (includeDisabled || instruction.enabled) && instruction.isLinkedToTask(taskName);
  }).toList();
}


class _RoutineDialogMood {
  final String emoji;
  final String label;
  final Color color;

  const _RoutineDialogMood({required this.emoji, required this.label, required this.color});
}

_RoutineDialogMood _routineDialogMood(DashboardThemeStyle style, bool taskCompleted, bool taskMissed, int followed, int total) {
  if (taskMissed) return _RoutineDialogMood(emoji: '😞', label: 'Missed Today', color: style.accent);
  if (!taskCompleted) return _RoutineDialogMood(emoji: '😐', label: 'Task Pending', color: style.textMuted);
  if (total == 0) return _RoutineDialogMood(emoji: '🙂', label: 'Task Complete', color: style.primary);
  final ratio = followed / total;
  if (ratio >= 1) return _RoutineDialogMood(emoji: '🤩', label: 'Perfect', color: style.primary);
  if (ratio >= 0.75) return _RoutineDialogMood(emoji: '😄', label: 'Excellent', color: Color.lerp(style.primary, style.accent, 0.35) ?? style.primary);
  if (ratio >= 0.5) return _RoutineDialogMood(emoji: '😊', label: 'Good', color: style.secondary);
  if (ratio >= 0.25) return _RoutineDialogMood(emoji: '🙂', label: 'Can Improve', color: style.accent);
  return _RoutineDialogMood(emoji: '😐', label: 'Instructions Ignored', color: style.textMuted);
}

Widget _instructionRadioOption({
  required String label,
  required String value,
  required String selected,
  required bool enabled,
  required DashboardThemeStyle style,
  required VoidCallback onSelected,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(999),
    onTap: enabled ? onSelected : null,
    child: Opacity(
      opacity: enabled ? 1 : 0.54,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected == value ? style.primary : style.primary.withOpacity(0.18)),
          color: selected == value ? style.primary.withOpacity(0.14) : style.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: value,
              groupValue: selected.isEmpty ? null : selected,
              onChanged: enabled ? (_) => onSelected() : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: style.textPrimary)),
          ],
        ),
      ),
    ),
  );
}

class _RoutineDialogReward {
  final int baseXp;
  final int instructionXp;
  final int timingXp;
  final int streakXp;
  final int coins;
  final bool onTime;

  const _RoutineDialogReward({
    required this.baseXp,
    required this.instructionXp,
    required this.timingXp,
    required this.streakXp,
    required this.coins,
    required this.onTime,
  });

  int get totalXp => baseXp + instructionXp + timingXp + streakXp;
}

_RoutineDialogReward _routineDialogReward(
  Task task,
  List<InstructionRule> instructions,
  Map<String, String> selectedStatuses, {
  required bool taskCompleted,
}) {
  if (!taskCompleted) {
    return const _RoutineDialogReward(baseXp: 0, instructionXp: 0, timingXp: 0, streakXp: 0, coins: 0, onTime: false);
  }

  const baseXp = 20;
  const streakXp = 5;
  final instructionXp = instructions.fold<int>(0, (sum, instruction) {
    return sum + (selectedStatuses[instruction.id] == InstructionHistoryEntry.statusFollowed ? instruction.xpEarned : 0);
  });
  final onTime = _isRoutineCompletionOnTime(task);
  final timingXp = onTime ? 10 : 0;
  final totalXp = baseXp + instructionXp + timingXp + streakXp;
  final coins = (totalXp ~/ 10) + (onTime ? 5 : 0);
  return _RoutineDialogReward(baseXp: baseXp, instructionXp: instructionXp, timingXp: timingXp, streakXp: streakXp, coins: coins, onTime: onTime);
}

bool _isRoutineCompletionOnTime(Task task) {
  final schedule = _scheduleWindowForTask(task);
  if (schedule == null) return false;
  final now = task.done || _normalizedStatus(task) == 'completed' ? task.dueDate : DateTime.now();
  var completed = (now.hour * 60) + now.minute;
  final start = schedule.$1;
  var end = schedule.$2;
  if (end < start) {
    end += 24 * 60;
    if (completed < start) completed += 24 * 60;
  }
  return completed >= start && completed <= end;
}

(int, int)? _scheduleWindowForTask(Task task) {
  int? start;
  int? end;
  for (final line in task.description.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('⏰ Schedule Start:')) {
      start = _parseScheduleMinutes(trimmed.substring('⏰ Schedule Start:'.length).trim());
    } else if (trimmed.startsWith('⏰ Schedule End:')) {
      end = _parseScheduleMinutes(trimmed.substring('⏰ Schedule End:'.length).trim());
    }
  }
  return start == null || end == null ? null : (start, end);
}

int? _parseScheduleMinutes(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour * 60) + minute;
}

Future<void> _saveRoutineOccurrence({
  required HiveService hiveService,
  required Task task,
  required bool completed,
  required List<InstructionRule> linkedInstructions,
  required Map<String, String> selectedStatuses,
}) async {
  await hiveService.updateTaskByReference(
    task,
    task.copyWith(done: completed, status: completed ? 'Completed' : 'Missed', repeatTask: task.repeatTask),
  );

  if (!completed) return;

  for (final instruction in linkedInstructions) {
    final status = selectedStatuses[instruction.id];
    if (status != InstructionHistoryEntry.statusFollowed && status != InstructionHistoryEntry.statusMissed) continue;
    await hiveService.updateInstructionStatus(
      instruction,
      task.dueDate,
      status!,
      note: 'Task occurrence: ${task.task} • ${routineOccurrenceLabel(task)} • completed',
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
