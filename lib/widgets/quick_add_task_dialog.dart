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

const List<String> _repeatFrequencyOptions = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

Future<Task?> showTaskFormDialog(
  BuildContext context, {
  required DateTime date,
  Task? initialTask,
  int? initialHourSlot,
  String title = 'Add Task',
  String actionLabel = 'Add Task',
}) async {
  final isEditing = initialTask != null;
  final nameController = TextEditingController(text: initialTask?.task ?? '');
  final descriptionController = TextEditingController(text: initialTask?.description ?? '');
  final estimatedController = TextEditingController(
    text: (initialTask?.estimatedMinutes ?? 0) > 0 ? '${initialTask!.estimatedMinutes}' : '',
  );

  final hiveService = HiveService.instance;
  final categories = hiveService.getCategories().toList();
  final delegates = hiveService.getDelegates().toList();

  DateTime dueDate = DateTime((initialTask?.dueDate ?? date).year, (initialTask?.dueDate ?? date).month, (initialTask?.dueDate ?? date).day);
  int? hourSlot = initialTask?.hourSlot ?? initialHourSlot;

  String selectedPriority = initialTask?.priority ?? 'Medium';
  String selectedStatus = initialTask?.status ?? 'Not Started';
  String selectedCategory = initialTask?.category ?? (categories.isNotEmpty ? categories.first : 'Personal');
  String? selectedDelegate = initialTask?.delegatedTo;
  bool repeatTask = initialTask?.repeatTask ?? false;
  String repeatFrequency = initialTask?.repeatFrequency ?? 'Daily';
  bool selectedUrgent = initialTask?.urgent ?? false;
  bool selectedImportant = initialTask?.important ?? false;

  if (!categories.contains(selectedCategory)) categories.add(selectedCategory);
  if (selectedDelegate != null && selectedDelegate!.isNotEmpty && !delegates.contains(selectedDelegate)) delegates.add(selectedDelegate!);

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
                  decoration: InputDecoration(labelText: 'Task Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  autofocus: !isEditing,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                if (hourSlot != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                    child: Text('Time Slot: ${_formatHour(hourSlot)}'),
                  ),
                if (hourSlot != null) const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                  child: Row(
                    children: [
                      Expanded(child: Text('Due Date: ${dueDate.month}/${dueDate.day}/${dueDate.year}')),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) setDialogState(() => dueDate = picked);
                        },
                        child: const Text('Select'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Urgent *', style: TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Expanded(child: RadioListTile<bool>(value: true, groupValue: selectedUrgent, title: const Text('Yes'), dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setDialogState(() => selectedUrgent = v ?? false))),
                          Expanded(child: RadioListTile<bool>(value: false, groupValue: selectedUrgent, title: const Text('No'), dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setDialogState(() => selectedUrgent = v ?? false))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Important *', style: TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Expanded(child: RadioListTile<bool>(value: true, groupValue: selectedImportant, title: const Text('Yes'), dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setDialogState(() => selectedImportant = v ?? false))),
                          Expanded(child: RadioListTile<bool>(value: false, groupValue: selectedImportant, title: const Text('No'), dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setDialogState(() => selectedImportant = v ?? false))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: estimatedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Estimated Time (minutes) *', hintText: '30, 60, 120', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: InputDecoration(labelText: 'Priority', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  items: _priorityOptions.map((priority) => DropdownMenuItem<String>(value: priority, child: Text(priority))).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedPriority = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  items: _statusOptions.map((status) => DropdownMenuItem<String>(value: status, child: Text(status))).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedStatus = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  items: [...categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))), const DropdownMenuItem<String>(value: '__add_category__', child: Text('➕ Add Category'))],
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value == '__add_category__') {
                      final controller = TextEditingController();
                      final added = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Add Category'), content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Category name')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))]));
                      if (added != null && added.isNotEmpty) {
                        await hiveService.addCategory(added);
                        if (!categories.contains(added)) categories.add(added);
                        setDialogState(() => selectedCategory = added);
                      }
                    } else {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDelegate ?? '__none__',
                  decoration: InputDecoration(labelText: 'Delegate (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  items: [const DropdownMenuItem<String>(value: '__none__', child: Text('Unassigned')), ...delegates.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))), const DropdownMenuItem<String>(value: '__add_delegate__', child: Text('➕ Add Delegate'))],
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value == '__none__') {
                      setDialogState(() => selectedDelegate = null);
                    } else if (value == '__add_delegate__') {
                      final controller = TextEditingController();
                      final added = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Add Delegate'), content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Person name')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))]));
                      if (added != null && added.isNotEmpty) {
                        await hiveService.addDelegate(added);
                        if (!delegates.contains(added)) delegates.add(added);
                        setDialogState(() => selectedDelegate = added);
                      }
                    } else {
                      setDialogState(() => selectedDelegate = value);
                    }
                  },
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
                      if (!repeatTask) repeatFrequency = 'Daily';
                    });
                  },
                ),
                if (repeatTask)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Repeat Frequency', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ..._repeatFrequencyOptions.map((frequency) => RadioListTile<String>(value: frequency, groupValue: repeatFrequency, title: Text(frequency), dense: true, contentPadding: EdgeInsets.zero, visualDensity: const VisualDensity(horizontal: -4, vertical: -4), onChanged: (value) { if (value != null) setDialogState(() => repeatFrequency = value); })),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                final name = nameController.text.trim();
                final estimatedMinutes = int.tryParse(estimatedController.text.trim()) ?? 0;
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task name is required')));
                  return;
                }
                if (estimatedMinutes <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estimated time is required')));
                  return;
                }

                Navigator.of(context).pop(Task(
                  task: name,
                  description: descriptionController.text.trim(),
                  dueDate: dueDate,
                  priority: selectedPriority,
                  status: selectedStatus,
                  category: selectedCategory,
                  delegatedTo: selectedDelegate,
                  done: selectedStatus == 'Completed',
                  repeatTask: repeatTask,
                  repeatFrequency: repeatTask ? repeatFrequency : null,
                  urgent: selectedUrgent,
                  important: selectedImportant,
                  estimatedMinutes: estimatedMinutes,
                  hourSlot: hourSlot,
                ));
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
    estimatedController.dispose();
  }
}

String _formatHour(int hour) {
  if (hour == 0) return '12 AM';
  if (hour < 12) return '$hour AM';
  if (hour == 12) return '12 PM';
  return '${hour - 12} PM';
}

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
