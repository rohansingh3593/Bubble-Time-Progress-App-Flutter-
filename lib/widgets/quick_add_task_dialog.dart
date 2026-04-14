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

const List<String> _repeatFrequencyOptions = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

/// Opens the reusable task form dialog.
Future<Task?> showTaskFormDialog(
  BuildContext context, {
  required DateTime date,
  Task? initialTask,
  String title = 'Add Task',
  String actionLabel = 'Add Task',
}) async {
  final isEditing = initialTask != null;
  final nameController = TextEditingController(text: initialTask?.task ?? '');
  final descriptionController = TextEditingController(text: initialTask?.description ?? '');
  final delegateController = TextEditingController(text: initialTask?.delegatedTo ?? '');

  DateTime dueDate = DateTime(
    (initialTask?.dueDate ?? date).year,
    (initialTask?.dueDate ?? date).month,
    (initialTask?.dueDate ?? date).day,
  );

  String selectedPriority = initialTask?.priority ?? 'Medium';
  String selectedStatus = initialTask?.status ?? 'Not Started';
  String selectedCategory = initialTask?.category ?? 'Personal';
  bool repeatTask = initialTask?.repeatTask ?? false;
  String repeatFrequency = initialTask?.repeatFrequency ?? 'Daily';

  try {
    return await showDialog<Task>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Task Name *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8F4FF),
                  ),
                  autofocus: !isEditing,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8F4FF),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F4FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
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
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8F4FF),
                  ),
                  items: _priorityOptions
                      .map((priority) => DropdownMenuItem<String>(value: priority, child: Text(priority)))
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
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8F4FF),
                  ),
                  items: _statusOptions
                      .map((status) => DropdownMenuItem<String>(value: status, child: Text(status)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8F4FF),
                  ),
                  items: _categoryOptions
                      .map((category) => DropdownMenuItem<String>(value: category, child: Text(category)))
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
                  decoration: InputDecoration(
                    labelText: 'Delegate (Optional)',
                    hintText: 'Amit / Monika / Ankit',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8F4FF),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat Task'),
                  subtitle: Text(repeatTask ? 'ON' : 'OFF'),
                  value: repeatTask,
                  onChanged: (value) {
                    setDialogState(() {
                      repeatTask = value;
                      if (!repeatTask) {
                        repeatFrequency = 'Daily';
                      }
                    });
                  },
                ),
                if (repeatTask)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F4FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Repeat Frequency',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        ..._repeatFrequencyOptions.map(
                          (frequency) => RadioListTile<String>(
                            value: frequency,
                            groupValue: repeatFrequency,
                            title: Text(frequency),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  repeatFrequency = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
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
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
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
                    delegatedTo: delegateController.text.trim().isEmpty ? null : delegateController.text.trim(),
                    done: selectedStatus == 'Completed',
                    repeatTask: repeatTask,
                    repeatFrequency: repeatTask ? repeatFrequency : null,
                  ),
                );
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  } finally {
    nameController.dispose();
    descriptionController.dispose();
    delegateController.dispose();
  }
}

/// Shows a quick-add task dialog for a given date.
/// Returns true if a task was added, false otherwise.
Future<bool> showQuickAddTaskDialog(
  BuildContext context,
  DateTime date,
  HiveService hiveService,
) async {
  final result = await showTaskFormDialog(context, date: date);

  if (result != null) {
    await hiveService.addTask(date, result);
    return true;
  }

  return false;
}
