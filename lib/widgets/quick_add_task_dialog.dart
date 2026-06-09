import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../utils/task_time_utils.dart';

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
const List<String> _projectPhaseStatusOptions = ['Not Started', 'In Progress', 'Completed', 'Cancelled'];

const Map<String, int> _taskColorOptions = {
  'Yellow': 0xFFFFC107,
  'Green': 0xFF43A047,
  'Blue': 0xFF1E88E5,
  'Red': 0xFFE53935,
  'Purple': 0xFF7E57C2,
  'Orange': 0xFFFF8F00,
  'Pink': 0xFFE91E63,
};

Future<Task?> showTaskFormDialog(
  BuildContext context, {
  required DateTime date,
  Task? initialTask,
  int? initialHourSlot,
  String title = 'Add Task',
  String actionLabel = 'Add Task',
  Future<void> Function()? onDelete,
}) async {
  final isEditing = initialTask != null;
  final nameController = TextEditingController(text: initialTask?.task ?? '');
  final descriptionController = TextEditingController(text: initialTask?.description ?? '');
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
  bool routineEnabled = initialTask?.routineEnabled ?? true;
  int selectedColorValue = initialTask?.colorValue ?? _taskColorOptions['Blue']!;
  int selectedRoutineMinutes = normalizeTaskDuration(initialTask?.estimatedMinutes);
  final projectPhases = _ProjectPhaseDraft.parseFromDescription(initialTask?.description ?? '');
  void syncStatusForTaskType() {
    if (repeatTask) {
      selectedStatus = 'Not Updated';
      return;
    }
    if (!_statusOptions.contains(selectedStatus)) selectedStatus = 'Not Started';
  }

  if (!categories.contains(selectedCategory)) categories.add(selectedCategory);
  if (selectedDelegate != null && selectedDelegate!.isNotEmpty && !delegates.contains(selectedDelegate)) delegates.add(selectedDelegate!);
  syncStatusForTaskType();

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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat Task'),
                  subtitle: Text(repeatTask ? 'ON' : 'OFF'),
                  value: repeatTask,
                  onChanged: (value) {
                    setDialogState(() {
                      repeatTask = value;
                      if (!repeatTask) repeatFrequency = 'Daily';
                      if (repeatTask && repeatFrequency == 'Daily') {
                        hourSlot = null;
                        selectedDelegate = null;
                      }
                      syncStatusForTaskType();
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
                        ..._repeatFrequencyOptions.map((frequency) => RadioListTile<String>(value: frequency, groupValue: repeatFrequency, title: Text(frequency), dense: true, contentPadding: EdgeInsets.zero, visualDensity: const VisualDensity(horizontal: -4, vertical: -4), onChanged: (value) { if (value != null) setDialogState(() { repeatFrequency = value; if (repeatFrequency == 'Daily') { hourSlot = null; selectedDelegate = null; } }); })),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable in Streak'),
                          subtitle: Text(routineEnabled ? 'Routine appears in Habit/Streak tracking' : 'Routine is paused but history is kept'),
                          value: routineEnabled,
                          onChanged: (value) => setDialogState(() => routineEnabled = value),
                        ),
                        const SizedBox(height: 8),
                        const Text('Task Color', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _taskColorOptions.entries.map((entry) {
                            final selected = selectedColorValue == entry.value;
                            final color = Color(entry.value);
                            return ChoiceChip(
                              selected: selected,
                              label: Text(entry.key),
                              avatar: CircleAvatar(backgroundColor: color, radius: 8),
                              selectedColor: color.withOpacity(0.22),
                              onSelected: (_) => setDialogState(() => selectedColorValue = entry.value),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: selectedRoutineMinutes,
                          decoration: InputDecoration(labelText: 'Routine Time', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: taskDurationOptions.map((minutes) => DropdownMenuItem<int>(value: minutes, child: Text('$minutes min'))).toList(),
                          onChanged: (value) {
                            if (value != null) setDialogState(() => selectedRoutineMinutes = value);
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (hourSlot != null && !(repeatTask && repeatFrequency == 'Daily'))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                    child: Text('Time Slot: ${_formatHour(hourSlot!)}'),
                  ),
                if (hourSlot != null && !(repeatTask && repeatFrequency == 'Daily')) const SizedBox(height: 12),
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
                if (!repeatTask) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                    child: const Text('Non-repeating tasks use phase-based progress. Estimated time is hidden; use phases below.'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!repeatTask) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Project Phases', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...projectPhases.asMap().entries.map((entry) {
                          final index = entry.key;
                          final phase = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              TextField(
                                controller: phase.nameController,
                                decoration: InputDecoration(labelText: 'Phase ${index + 1} Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: phase.descriptionController,
                                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: phase.status,
                                decoration: InputDecoration(labelText: 'Phase Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                items: _projectPhaseStatusOptions.map((status) => DropdownMenuItem<String>(value: status, child: Text(status))).toList(),
                                onChanged: (value) {
                                  if (value != null) setDialogState(() => phase.status = value);
                                },
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: phase.durationMinutes,
                                decoration: InputDecoration(labelText: 'Phase Time', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                items: taskDurationOptions.map((minutes) => DropdownMenuItem<int>(value: minutes, child: Text('$minutes min'))).toList(),
                                onChanged: (value) {
                                  if (value != null) setDialogState(() => phase.durationMinutes = value);
                                },
                              ),
                            ]),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setDialogState(() => projectPhases.add(_ProjectPhaseDraft.empty())),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Phase'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!repeatTask) ...[
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
                ],
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  items: [...categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))), const DropdownMenuItem<String>(value: '__add_category__', child: Text('➕ Add Category'))],
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value == '__add_category__') {
                      final controller = TextEditingController();
                      try {
                        final added = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Add Category'), content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Category name')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))]));
                        if (!context.mounted) return;
                        if (added != null && added.isNotEmpty) {
                          await hiveService.addCategory(added);
                          if (!context.mounted) return;
                          if (!categories.contains(added)) categories.add(added);
                          setDialogState(() => selectedCategory = added);
                        }
                      } finally {
                        controller.dispose();
                      }
                    } else {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                ),
                if (!repeatTask) ...[
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
                        try {
                          final added = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Add Delegate'), content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Person name')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))]));
                          if (!context.mounted) return;
                          if (added != null && added.isNotEmpty) {
                            await hiveService.addDelegate(added);
                            if (!context.mounted) return;
                            if (!delegates.contains(added)) delegates.add(added);
                            setDialogState(() => selectedDelegate = added);
                          }
                        } finally {
                          controller.dispose();
                        }
                      } else {
                        setDialogState(() => selectedDelegate = value);
                      }
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Color(0xFFF8F4FF), borderRadius: BorderRadius.all(Radius.circular(14)), border: Border.fromBorderSide(BorderSide(color: Colors.black12))),
                    child: Text('Routine tasks are tracked in Habit/Streak, so delegate scheduling is hidden.'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isEditing && initialTask?.repeatTask == false && onDelete != null)
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Task?'),
                      content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await onDelete();
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                child: const Text('Delete Task', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task name is required')));
                  return;
                }
                final mergedDescription = !repeatTask
                    ? _ProjectPhaseDraft.mergeIntoDescription(descriptionController.text.trim(), projectPhases)
                    : descriptionController.text.trim();

                Navigator.of(context).pop(Task(
                  task: name,
                  description: mergedDescription,
                  dueDate: dueDate,
                  priority: repeatTask ? 'Medium' : selectedPriority,
                  status: repeatTask ? 'Not Updated' : selectedStatus,
                  category: selectedCategory,
                  delegatedTo: repeatTask ? null : selectedDelegate,
                  done: repeatTask ? false : selectedStatus == 'Completed',
                  repeatTask: repeatTask,
                  repeatFrequency: repeatTask ? repeatFrequency : null,
                  urgent: selectedUrgent,
                  important: selectedImportant,
                  estimatedMinutes: repeatTask ? selectedRoutineMinutes : _ProjectPhaseDraft.totalMinutes(projectPhases),
                  hourSlot: repeatTask && repeatFrequency == 'Daily' ? null : hourSlot,
                  colorValue: selectedColorValue,
                  routineEnabled: repeatTask ? routineEnabled : true,
                ));
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    nameController.dispose();
    descriptionController.dispose();
    for (final phase in projectPhases) {
      phase.dispose();
    }
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

class _ProjectPhaseDraft {
  String status;
  int durationMinutes;
  final TextEditingController nameController;
  final TextEditingController descriptionController;

  _ProjectPhaseDraft({
    required this.status,
    required this.durationMinutes,
    required this.nameController,
    required this.descriptionController,
  });

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
  }

  factory _ProjectPhaseDraft.empty() => _ProjectPhaseDraft(
        status: 'Not Started',
        durationMinutes: defaultTaskDurationMinutes,
        nameController: TextEditingController(),
        descriptionController: TextEditingController(),
      );

  static List<_ProjectPhaseDraft> parseFromDescription(String description) {
    final markerIndex = description.indexOf(taskPhaseMarker);
    if (markerIndex == -1) return [_ProjectPhaseDraft.empty()];
    final phaseChunk = description.substring(markerIndex + taskPhaseMarker.length).trim();
    final lines = phaseChunk.split('\n').where((line) => line.trim().isNotEmpty);
    final phases = <_ProjectPhaseDraft>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length < 3) continue;
      phases.add(
        _ProjectPhaseDraft(
          status: parts[2].trim().isEmpty ? 'Not Started' : parts[2].trim(),
          durationMinutes: _parseDuration(parts.length > 3 ? parts[3] : null),
          nameController: TextEditingController(text: parts[0].trim()),
          descriptionController: TextEditingController(text: parts[1].trim()),
        ),
      );
    }
    return phases.isEmpty ? [_ProjectPhaseDraft.empty()] : phases;
  }

  static String mergeIntoDescription(String baseDescription, List<_ProjectPhaseDraft> phases) {
    final cleanBase = baseDescription.split(taskPhaseMarker).first.trim();
    final serializedPhases = phases
        .where((phase) => phase.nameController.text.trim().isNotEmpty || phase.descriptionController.text.trim().isNotEmpty)
        .map((phase) => serializeTaskPhase(
              name: phase.nameController.text,
              description: phase.descriptionController.text,
              status: phase.status,
              minutes: phase.durationMinutes,
            ))
        .join('\n');
    if (serializedPhases.isEmpty) return cleanBase;
    return '$cleanBase\n\n$taskPhaseMarker\n$serializedPhases'.trim();
  }

  static int totalMinutes(List<_ProjectPhaseDraft> phases) {
    final activePhases = phases.where((phase) => phase.nameController.text.trim().isNotEmpty || phase.descriptionController.text.trim().isNotEmpty).toList();
    final source = activePhases.isEmpty ? phases : activePhases;
    return source.fold<int>(0, (sum, phase) => sum + normalizeTaskDuration(phase.durationMinutes));
  }

  static int _parseDuration(String? rawValue) {
    final parsed = int.tryParse((rawValue ?? '').replaceAll('min', '').trim());
    return normalizeTaskDuration(parsed);
  }

}
