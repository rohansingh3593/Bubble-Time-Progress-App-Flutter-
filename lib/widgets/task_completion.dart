import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/instruction.dart';
import '../services/hive_service.dart';
import '../screens/journal_view.dart';

bool taskCompleted(Task task) =>
    task.done || task.status.toLowerCase() == 'completed';

Future<bool> changeTaskCompletion(BuildContext context, HiveService service,
    Task task, DateTime date, bool complete) async {
  final day = DateUtils.dateOnly(date);
  if (day.isAfter(DateUtils.dateOnly(DateTime.now()))) return false;
  if (service.isDailyJournalTask(task)) {
    await Navigator.of(context)
        .push(JournalView.route(hiveService: service, initialDate: day));
    return false;
  }
  try {
    final rules = service
        .getTaskLinkedInstructions()
        .where((r) => r.enabled && r.isLinkedToTask(task.task))
        .toList();
    if (complete &&
        rules.isNotEmpty &&
        !await reviewTaskInstructions(context, service, day, task, rules))
      return false;
    if (!context.mounted) return false;
    await service.setTaskOccurrenceCompleted(task, day, complete);
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(complete ? 'Task completed' : 'Task reopened')));
    return true;
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update this task. Please retry.')));
    return false;
  }
}

Future<bool> reviewTaskInstructions(BuildContext context, HiveService service,
    DateTime day, Task task, List<InstructionRule> rules) async {
  final selected = <String, Set<InstructionOption>>{};
  bool saving = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final instructionWidgets = <Widget>[];
          for (final rule in rules) {
            instructionWidgets.add(
              Text(
                rule.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
            if (rule.options.isEmpty) {
              instructionWidgets.add(
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Instruction followed'),
                  value: selected[rule.id]?.isNotEmpty ?? false,
                  onChanged: (value) {
                    setDialogState(() {
                      selected[rule.id] = value == true
                          ? {
                              const InstructionOption(
                                id: '__followed__',
                                name: 'Followed',
                                bonusPoints: 0,
                                pointsEarned: 0,
                              ),
                            }
                          : <InstructionOption>{};
                    });
                  },
                ),
              );
              continue;
            }

            for (final option in rule.options) {
              instructionWidgets.add(
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.displayLabel),
                  subtitle: Text(
                    '+${option.bonusPoints + option.pointsEarned}',
                  ),
                  value: selected[rule.id]?.contains(option) ?? false,
                  onChanged: (value) {
                    setDialogState(() {
                      final values = selected.putIfAbsent(
                        rule.id,
                        () => <InstructionOption>{},
                      );
                      if (value == true) {
                        values.add(option);
                      } else {
                        values.remove(option);
                      }
                    });
                  },
                ),
              );
            }
          }

          return AlertDialog(
            title: Text(task.task),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select everything followed:',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ...instructionWidgets,
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          for (final rule in rules) {
                            final values =
                                selected[rule.id] ?? <InstructionOption>{};
                            await service.updateInstructionStatus(
                              rule,
                              day,
                              values.isEmpty
                                  ? InstructionHistoryEntry.statusMissed
                                  : InstructionHistoryEntry.statusFollowed,
                              options: values
                                  .where(
                                      (option) => option.id != '__followed__')
                                  .toList(),
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (_) {
                          if (dialogContext.mounted)
                            setDialogState(() {
                              saving = false;
                              error =
                                  'Could not save instruction review. Please retry.';
                            });
                        }
                      },
                child: const Text('Save & Finish'),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}
