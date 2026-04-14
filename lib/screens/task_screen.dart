import 'package:flutter/material.dart';
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

  /// Toggles task completion status.
  /// No setState needed - reactive ValueListenableBuilder will trigger rebuild.
  Future<void> _toggleTask(int index) async {
    await widget.hiveService.toggleTaskStatus(widget.date, index);
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 3,
                            shadowColor: const Color(0xFFB6A9EA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              leading: Checkbox(
                                value: task.done,
                                onChanged: (_) => _toggleTask(index),
                              ),
                              title: Text(
                                task.task,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: task.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.done ? Colors.grey : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (task.description.isNotEmpty)
                                    Text(task.description),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Due: ${task.dueDate.month}/${task.dueDate.day}/${task.dueDate.year} • ${task.priority}',
                                  ),
                                  Text('Status: ${task.status} • Category: ${task.category}'),
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
                                    icon: const Icon(Icons.edit, color: Color(0xFF6F55C7)),
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