import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/hive_service.dart';
import '../models/task_model.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/app_text.dart';
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



  String _formatTaskDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Master task list header and filters
              Text(
                'Master Tasks • ${taskEntries.length}/${allTaskEntries.length}',
                style: TextStyle(fontSize: responsiveFont(context, 20), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 400;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _taskFilters.map((filter) {
                      final selected = filter == _selectedTaskFilter;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(filter, style: TextStyle(fontSize: narrow ? 10 : null)),
                        labelPadding: narrow ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3) : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: narrow ? VisualDensity.compact : null,
                        onSelected: (_) => setState(() => _selectedTaskFilter = filter),
                      );
                    }).toList(),
                  );
                },
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

                          final screenWidth = MediaQuery.sizeOf(context).width;
                          final narrow = screenWidth < 400;
                          final chipFontSize = narrow ? 10.0 : 11.0;
                          final chipPadding = narrow ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3) : const EdgeInsets.symmetric(horizontal: 8, vertical: 5);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1.5,
                            color: taskColor.withOpacity(0.07),
                            shadowColor: taskColor.withOpacity(0.18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: taskColor.withOpacity(isCompleted ? 0.55 : 0.24), width: 1),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 12, vertical: narrow ? 8 : 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: taskColor, size: narrow ? 18 : 20),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          task.task,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: narrow ? 14 : 15,
                                            fontWeight: FontWeight.w900,
                                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                                            color: isCompleted ? taskColor.withOpacity(0.72) : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: taskColor, size: narrow ? 18 : 20),
                                        onPressed: () => _editTaskByReference(task),
                                        tooltip: 'Update task',
                                        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                      if (!task.repeatTask)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          onPressed: () => _deleteTaskByReference(task),
                                          tooltip: 'Delete task',
                                          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                          padding: EdgeInsets.zero,
                                        )
                                      else if (isDailyJournalSystemTask(task))
                                        IconButton(
                                          icon: Icon(Icons.menu_book_rounded, color: taskColor, size: 20),
                                          onPressed: () => _openJournalForTask(task),
                                          tooltip: 'Open journal',
                                          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                          padding: EdgeInsets.zero,
                                        )
                                      else
                                        IconButton(
                                          icon: Icon(task.routineEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline, color: task.routineEnabled ? Colors.orange : Colors.green, size: 20),
                                          onPressed: () => widget.hiveService.setRecurringTaskEnabledByReference(task, !task.routineEnabled),
                                          tooltip: task.routineEnabled ? 'Disable routine' : 'Enable routine',
                                          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                          padding: EdgeInsets.zero,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _TaskColorChip(label: repeatType, icon: Icons.calendar_today_rounded, color: taskColor, fontSize: chipFontSize, padding: chipPadding),
                                      _TaskColorChip(label: task.category.isEmpty ? 'No Category' : task.category, icon: Icons.local_fire_department_rounded, color: taskColor, fontSize: chipFontSize, padding: chipPadding),
                                      _TaskColorChip(label: task.priority.isEmpty ? 'Priority' : task.priority, icon: Icons.star_rounded, color: taskColor, fontSize: chipFontSize, padding: chipPadding),
                                      if (task.repeatTask && !task.routineEnabled) _TaskColorChip(label: 'Paused', icon: Icons.pause_circle_rounded, color: Colors.orange, fontSize: chipFontSize, padding: chipPadding),
                                      if (hasProjectPhases) _TaskColorChip(label: 'Project Phases', icon: Icons.account_tree_rounded, color: taskColor, fontSize: chipFontSize, padding: chipPadding),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text('Due: ${_formatTaskDate(task.dueDate)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: narrow ? 11 : 12)),
                                  const SizedBox(height: 3),
                                  Text('Urgent: ${task.urgent ? 'Yes' : 'No'} • Important: ${task.important ? 'Yes' : 'No'} • ${_durationLabel(task.estimatedMinutes)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: narrow ? 11 : 12)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    children: [
                                      Text('📋 $instructionCount Instructions', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54, fontSize: narrow ? 11 : 12)),
                                      Text('🎯 ${hasGoalLink ? 'Goal Linked' : 'No Goal'}', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54, fontSize: narrow ? 11 : 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addTaskWithDialog,
            icon: const Icon(Icons.add),
            label: const Text('+ Add Task'),
          ),
        ),
      ),
    );
  }
}

class _TaskColorChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const _TaskColorChip({required this.label, required this.icon, required this.color, this.fontSize, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
              style: TextStyle(color: color, fontSize: fontSize ?? responsiveFont(context, 11), fontWeight: FontWeight.w800),
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
