import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';

const List<String> _priorityOptions = [
  'Low',
  'Medium',
  'High',
  'Very High',
  'Urgent (Now)',
];

const List<String> _statusOptions = [
  'Not Started',
  'In Progress',
  'Completed',
  'Cancelled',
  'Overdue',
];

const List<String> _categoryOptions = [
  'Work',
  'Personal',
  'Study',
  'Health',
  'Finance',
];

/// Shows a quick-add task dialog for a given date.
/// Returns true if a task was added, false otherwise.
Future<bool> showQuickAddTaskDialog(
  BuildContext context,
  DateTime date,
  HiveService hiveService,
) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final delegateController = TextEditingController();

  DateTime dueDate = DateTime(date.year, date.month, date.day);
  String selectedPriority = 'Medium';
  String selectedStatus = 'Not Started';
  String selectedCategory = 'Personal';
  bool isDone = false;

  try {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Due Date: ${dueDate.month}/${dueDate.day}/${dueDate.year}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            dueDate = picked;
                          });
                        }
                      },
                      child: const Text('Select'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: _priorityOptions
                      .map((priority) => DropdownMenuItem<String>(
                            value: priority,
                            child: Text(priority),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedPriority = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: _statusOptions
                      .map((status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedStatus = value;
                        isDone = value == 'Completed';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categoryOptions
                      .map((category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: delegateController,
                  decoration: const InputDecoration(
                    labelText: 'Delegate (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Amit / Monika / Ankit',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as completed'),
                  value: isDone,
                  onChanged: (value) {
                    setDialogState(() {
                      isDone = value ?? false;
                      if (isDone) {
                        selectedStatus = 'Completed';
                      } else if (selectedStatus == 'Completed') {
                        selectedStatus = 'Not Started';
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task name is required')),
                  );
                  return;
                }

                Navigator.of(context).pop(
                  Task(
                    task: name,
                    description: descriptionController.text.trim(),
                    dueDate: dueDate,
                    priority: selectedPriority,
                    status: selectedStatus,
                    category: selectedCategory,
                    delegatedTo: delegateController.text.trim().isEmpty
                        ? null
                        : delegateController.text.trim(),
                    done: isDone,
                  ),
                );
              },
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await hiveService.addTask(date, result);
      return true;
    }

    return false;
  } finally {
    nameController.dispose();
    descriptionController.dispose();
    delegateController.dispose();
  }
}
