import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/hive_service.dart';
import '../widgets/quick_add_task_dialog.dart';

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
  /// Adds a new task with full details dialog.
  /// No setState needed - reactive ValueListenableBuilder will trigger rebuild.
  Future<void> _addTaskWithDialog() async {
    await showQuickAddTaskDialog(context, widget.date, widget.hiveService);
  }


  /// Edits task with full form and saves updates.
  Future<void> _editTask(int index) async {
    final tasks = widget.hiveService.getTasksForDate(widget.date);
    if (index < 0 || index >= tasks.length) return;

    final updated = await showTaskFormDialog(
      context,
      date: widget.date,
      initialTask: tasks[index],
      title: 'Update Task',
      actionLabel: 'Save Task',
    );

    if (updated != null) {
      await widget.hiveService.updateTask(widget.date, index, updated);
    }
  }

  /// Deletes a task with confirmation.
  /// No setState needed - reactive ValueListenableBuilder will trigger rebuild.
  Future<void> _deleteTask(int index) async {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final tasks = widget.hiveService.getTasksForDate(widget.date);

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
              // Date header
              Text(
                '${widget.date.month}/${widget.date.day}/${widget.date.year}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Task list
              Flexible(
                child: tasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No tasks for this date',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final taskColor = Color(task.colorValue);
                          final isCompleted = task.done || task.status == 'Completed';

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
                                      _TaskColorChip(label: task.priority, icon: Icons.flag, color: taskColor),
                                      _TaskColorChip(label: task.status, icon: Icons.timeline, color: taskColor),
                                      _TaskColorChip(label: task.category, icon: Icons.category, color: taskColor),
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
                                  if (task.repeatTask)
                                    Text('Repeats: ${task.repeatFrequency ?? 'Daily'}'),
                                ],
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: taskColor),
                                    onPressed: () => _editTask(index),
                                    tooltip: 'Update task',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteTask(index),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
