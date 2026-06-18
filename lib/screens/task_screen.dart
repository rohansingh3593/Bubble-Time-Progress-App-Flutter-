import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/hive_service.dart';
import '../models/task_model.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../utils/task_time_utils.dart';
import 'journal_view.dart';

class TaskScreen extends StatefulWidget {
  final DateTime date;
  final HiveService hiveService;

  const TaskScreen({
    super.key,
    required this.date,
    required this.hiveService,
  });

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  String _selectedTaskFilter = 'All';

  static const List<String> _taskFilters = ['All', 'Daily', 'Weekly', 'Monthly', 'Yearly', 'Non-Routine', 'Completed', 'Disabled'];

  /// Adds a new task with full details dialog.
  /// No setState needed - reactive ValueListenableBuilder will trigger rebuild.
  Future<void> _addTaskWithDialog() async {
    await showQuickAddTaskDialog(context, widget.date, widget.hiveService);
  }


  /// Edits task with full form and saves updates.


  void _openJournalForTask(Task task) {
    Navigator.of(context).push(
      JournalView.route(hiveService: widget.hiveService, initialDate: task.dueDate),
    );
  }

  Future<void> _editTask(int index) async {
    final tasks = widget.hiveService.getTasksForDate(widget.date);
    if (index < 0 || index >= tasks.length) return;
    final currentTask = tasks[index];

    if (isRoutineTask(currentTask) || hasTaskLinkedInstructions(widget.hiveService, currentTask)) {
      final action = await showRoutineOccurrenceDialog(context: context, task: currentTask, hiveService: widget.hiveService);
      if (action == null || action == RoutineOccurrenceAction.close) return;

      switch (action) {
        case RoutineOccurrenceAction.openJournal:
          _openJournalForTask(currentTask);
          return;
        case RoutineOccurrenceAction.disableRoutine:
          await widget.hiveService.setRecurringTaskEnabledByReference(currentTask, false);
          return;
        case RoutineOccurrenceAction.editDetails:
          final edited = await showTaskFormDialog(
            context,
            date: currentTask.dueDate,
            initialTask: currentTask,
            title: isRoutineTask(currentTask) ? 'Edit Routine Details' : 'View Task Details',
            actionLabel: isRoutineTask(currentTask) ? 'Save Routine' : 'Save Task',
          );
          if (edited != null) {
            if (isRoutineTask(currentTask)) {
              await widget.hiveService.updateRecurringTaskSeriesByReference(currentTask, edited.copyWith(repeatTask: true));
            } else {
              await widget.hiveService.updateTask(widget.date, index, edited);
            }
          }
          return;
        case RoutineOccurrenceAction.missOccurrence:
          await widget.hiveService.updateTask(widget.date, index, currentTask.copyWith(done: false, status: 'Missed'));
          return;
        case RoutineOccurrenceAction.completeOccurrence:
          await widget.hiveService.updateTask(widget.date, index, currentTask.copyWith(done: true, status: 'Completed'));
          return;
        case RoutineOccurrenceAction.close:
          return;
      }
    }

    final updated = await showTaskFormDialog(
      context,
      date: widget.date,
      initialTask: currentTask,
      title: 'Update Task',
      actionLabel: 'Save Task',
      onDelete: () => widget.hiveService.deleteTask(widget.date, index),
    );

    if (updated != null) {
      await widget.hiveService.updateTask(widget.date, index, updated);
    }
  }

  Future<void> _deleteTask(int index) async {
    final tasks = widget.hiveService.getTasksForDate(widget.date);
    if (index < 0 || index >= tasks.length || tasks[index].repeatTask) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.hiveService.deleteTask(widget.date, index);
    }
  }

  Future<void> _editTaskByReference(Task currentTask) async {
    if (isRoutineTask(currentTask) || hasTaskLinkedInstructions(widget.hiveService, currentTask)) {
      final action = await showRoutineOccurrenceDialog(context: context, task: currentTask, hiveService: widget.hiveService);
      if (action == null || action == RoutineOccurrenceAction.close) return;

      switch (action) {
        case RoutineOccurrenceAction.openJournal:
          _openJournalForTask(currentTask);
          return;
        case RoutineOccurrenceAction.disableRoutine:
          await widget.hiveService.setRecurringTaskEnabledByReference(currentTask, false);
          return;
        case RoutineOccurrenceAction.editDetails:
          final edited = await showTaskFormDialog(
            context,
            date: currentTask.dueDate,
            initialTask: currentTask,
            title: isRoutineTask(currentTask) ? 'Edit Routine Details' : 'View Task Details',
            actionLabel: isRoutineTask(currentTask) ? 'Save Routine' : 'Save Task',
          );
          if (edited != null) {
            if (isRoutineTask(currentTask)) {
              await widget.hiveService.updateRecurringTaskSeriesByReference(currentTask, edited.copyWith(repeatTask: true));
            } else {
              await widget.hiveService.updateTaskByReference(currentTask, edited);
            }
          }
          return;
        case RoutineOccurrenceAction.missOccurrence:
          await widget.hiveService.updateTaskByReference(currentTask, currentTask.copyWith(done: false, status: 'Missed'));
          return;
        case RoutineOccurrenceAction.completeOccurrence:
          await widget.hiveService.updateTaskByReference(currentTask, currentTask.copyWith(done: true, status: 'Completed'));
          return;
        case RoutineOccurrenceAction.close:
          return;
      }
    }

    final updated = await showTaskFormDialog(
      context,
      date: currentTask.dueDate,
      initialTask: currentTask,
      title: 'Update Task',
      actionLabel: 'Save Task',
      onDelete: () => widget.hiveService.deleteTaskByReference(currentTask),
    );
    if (updated != null) {
      await widget.hiveService.updateTaskByReference(currentTask, updated);
    }
  }

  Future<void> _deleteTaskByReference(Task task) async {
    if (task.repeatTask) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.hiveService.deleteTaskByReference(task);
    }
  }

  String _repeatTypeFor(Task task) {
    if (!task.repeatTask) return 'One-Time';
    final frequency = task.repeatFrequency?.trim();
    if (frequency == null || frequency.isEmpty) return 'Daily';
    return frequency[0].toUpperCase() + frequency.substring(1).toLowerCase();
  }

  int _instructionCountFor(Task task) {
    return widget.hiveService.getTaskLinkedInstructions().where((instruction) => instruction.enabled && instruction.isLinkedToTask(task.task)).length;
  }

  bool _hasProjectPhases(Task task) => parseTaskPhases(task.description).isNotEmpty;

  bool _matchesTaskFilter(Task task) {
    final repeatType = _repeatTypeFor(task);
    switch (_selectedTaskFilter) {
      case 'Daily':
      case 'Weekly':
      case 'Monthly':
      case 'Yearly':
        return task.repeatTask && repeatType == _selectedTaskFilter;
      case 'Non-Routine':
        return !task.repeatTask;
      case 'Completed':
        return task.done || task.status.trim().toLowerCase() == 'completed';
      case 'Disabled':
        return task.repeatTask && !task.routineEnabled;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final allTaskEntries = widget.hiveService
            .getAllTasksByDate()
            .entries
            .expand((entry) => entry.value.map((task) => _TaskListEntry(date: entry.key, task: task)))
            .where((entry) => !isDailyJournalSystemTask(entry.task))
            .toList();
        final taskEntries = allTaskEntries.where((entry) => _matchesTaskFilter(entry.task)).toList();

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7F3FF), Color(0xFFF3FBFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Master task list header and filters
              Text(
                'Master Tasks • ${taskEntries.length}/${allTaskEntries.length}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _taskFilters.map((filter) {
                    final selected = filter == _selectedTaskFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(filter),
                        onSelected: (_) => setState(() => _selectedTaskFilter = filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Task list
              Flexible(
                child: taskEntries.isEmpty
                    ? const Center(
                        child: Text(
                          'No tasks match this filter',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: taskEntries.length,
                        itemBuilder: (context, index) {
                          final taskEntry = taskEntries[index];
                          final task = taskEntry.task;
                          final taskColor = Color(task.colorValue);
                          final isCompleted = task.done || task.status == 'Completed';
                          final repeatType = _repeatTypeFor(task);
                          final instructionCount = _instructionCountFor(task);
                          final hasGoalLink = task.category.toLowerCase().contains('goal') || task.description.toLowerCase().contains('goal');
                          final hasProjectPhases = _hasProjectPhases(task);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 3,
                            color: taskColor.withOpacity(0.08),
                            shadowColor: taskColor.withOpacity(0.28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: taskColor.withOpacity(isCompleted ? 0.65 : 0.32), width: 1.4),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: taskColor.withOpacity(isCompleted ? 0.22 : 0.16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: taskColor.withOpacity(0.45)),
                                ),
                                child: Icon(
                                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: taskColor,
                                ),
                              ),
                              title: Text(
                                task.task,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  color: isCompleted ? taskColor.withOpacity(0.72) : AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (task.description.isNotEmpty)
                                    Text(task.description),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _TaskColorChip(label: 'Repeat: $repeatType', icon: Icons.repeat_rounded, color: taskColor),
                                      _TaskColorChip(label: 'Status: ${task.status}', icon: Icons.timeline, color: taskColor),
                                      _TaskColorChip(label: 'Category: ${task.category}', icon: Icons.category, color: taskColor),
                                      _TaskColorChip(label: 'Priority: ${task.priority}', icon: Icons.flag, color: taskColor),
                                      _TaskColorChip(label: 'Instructions: $instructionCount', icon: Icons.rule_rounded, color: taskColor),
                                      _TaskColorChip(label: 'Goal Linked: ${hasGoalLink ? 'Yes' : 'No'}', icon: Icons.flag_circle_rounded, color: taskColor),
                                      if (hasProjectPhases) _TaskColorChip(label: 'Project Phases', icon: Icons.account_tree_rounded, color: taskColor),
                                      if (task.repeatTask && !task.routineEnabled) _TaskColorChip(label: 'Disabled Routine', icon: Icons.pause_circle_rounded, color: Colors.orange),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Due: ${task.dueDate.month}/${task.dueDate.day}/${task.dueDate.year}',
                                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                                  ),
                                  Text('Urgent: ${task.urgent ? 'Yes' : 'No'} • Important: ${task.important ? 'Yes' : 'No'} • ${task.estimatedMinutes} min'),
                                  if (task.delegatedTo != null && task.delegatedTo!.isNotEmpty)
                                    Text('Delegate: ${task.delegatedTo}'),
                                  Text('Repeat Type: $repeatType'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: taskColor),
                                    onPressed: () => _editTaskByReference(task),
                                    tooltip: 'Update task',
                                  ),
                                  if (!task.repeatTask)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteTaskByReference(task),
                                      tooltip: 'Delete task',
                                    )
                                  else if (isDailyJournalSystemTask(task))
                                    IconButton(
                                      icon: Icon(Icons.menu_book_rounded, color: taskColor),
                                      onPressed: () => _openJournalForTask(task),
                                      tooltip: 'Open journal',
                                    )
                                  else
                                    IconButton(
                                      icon: Icon(
                                        task.routineEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                        color: task.routineEnabled ? Colors.orange : Colors.green,
                                      ),
                                      onPressed: () => widget.hiveService.setRecurringTaskEnabledByReference(task, !task.routineEnabled),
                                      tooltip: task.routineEnabled ? 'Disable routine' : 'Enable routine',
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Add task button
              ElevatedButton.icon(
                onPressed: _addTaskWithDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskColorChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _TaskColorChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}


class _TaskListEntry {
  final DateTime date;
  final Task task;

  const _TaskListEntry({required this.date, required this.task});
}
