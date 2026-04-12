import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';

/// Shows a quick-add task dialog for a given date
/// Returns true if a task was added, false otherwise
Future<bool> showQuickAddTaskDialog(
  BuildContext context,
  DateTime date,
  HiveService hiveService,
) async {
  final controller = TextEditingController();

  try {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter task description',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 2,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add Task'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final task = Task(task: result.trim());
      await hiveService.addTask(date, task);
      return true;
    }

    return false;
  } finally {
    controller.dispose();
  }
}
