import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/instruction.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../utils/task_time_utils.dart';
import '../utils/text_formatters.dart';

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
const String _legacyScheduledTimeMarker = '⏰ Scheduled:';
const String _scheduleStartMarker = '⏰ Schedule Start:';
const String _scheduleEndMarker = '⏰ Schedule End:';
const String _scheduleBonusMarker = '⏰ Schedule Bonus:';
const int _defaultScheduleBonusPoints = 20;
const List<int> _scheduleBonusOptions = [5, 10, 20, 30, 50, 75, 100];

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
  final initialDescription = initialTask?.description ?? '';
  final initialSchedule = _parseSchedule(initialDescription);
  final nameController = TextEditingController(text: initialTask?.task ?? '');
  final descriptionController = TextEditingController(
    text: _stripSchedule(initialDescription),
  );
  final hiveService = HiveService.instance;
  final categories = hiveService.getCategories().toList();
  final delegates = hiveService.getDelegates().toList();

  DateTime dueDate = DateTime((initialTask?.dueDate ?? date).year, (initialTask?.dueDate ?? date).month, (initialTask?.dueDate ?? date).day);
  TimeOfDay? scheduleStart = initialSchedule.start;
  TimeOfDay? scheduleEnd = initialSchedule.end;
  bool scheduleEnabled = initialSchedule.enabled;
  int scheduleBonusPoints = initialSchedule.bonusPoints ?? _defaultScheduleBonusPoints;
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
  final draftInstructions = <InstructionRule>[];
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
                  onChanged: (_) {
                    setDialogState(() {});
                  },
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
                      if (repeatTask) {
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
                        ..._repeatFrequencyOptions.map((frequency) => RadioListTile<String>(value: frequency, groupValue: repeatFrequency, title: Text(frequency), dense: true, contentPadding: EdgeInsets.zero, visualDensity: const VisualDensity(horizontal: -4, vertical: -4), onChanged: (value) { if (value != null) setDialogState(() { repeatFrequency = value; selectedDelegate = null; }); })),
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('⏰ Schedule Time Bonus', style: TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(scheduleEnabled ? 'Bonus is awarded only between start and end time' : 'None • normal points only'),
                                value: scheduleEnabled,
                                onChanged: (value) => setDialogState(() {
                                  scheduleEnabled = value;
                                  if (value) {
                                    scheduleStart ??= const TimeOfDay(hour: 6, minute: 0);
                                    scheduleEnd ??= _addMinutes(scheduleStart!, 30);
                                  }
                                }),
                              ),
                              if (scheduleEnabled) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: Text('Start Time: ${scheduleStart?.format(context) ?? 'Optional'}')),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: scheduleStart ?? const TimeOfDay(hour: 6, minute: 0),
                                        );
                                        if (picked != null) {
                                          setDialogState(() {
                                            scheduleStart = picked;
                                            scheduleEnd ??= _addMinutes(picked, 30);
                                          });
                                        }
                                      },
                                      child: const Text('Select'),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(child: Text('End Time: ${scheduleEnd?.format(context) ?? 'Optional'}')),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: scheduleEnd ?? _addMinutes(scheduleStart ?? const TimeOfDay(hour: 6, minute: 0), 30),
                                        );
                                        if (picked != null) setDialogState(() => scheduleEnd = picked);
                                      },
                                      child: const Text('Select'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  value: scheduleBonusPoints,
                                  decoration: InputDecoration(labelText: 'Bonus Points', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                  items: _scheduleBonusOptions.map((points) => DropdownMenuItem<int>(value: points, child: Text('+$points points'))).toList(),
                                  onChanged: (value) {
                                    if (value != null) setDialogState(() => scheduleBonusPoints = value);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (hourSlot != null && !repeatTask)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
                    child: Text('Time Slot: ${_formatHour(hourSlot!)}'),
                  ),
                if (hourSlot != null && !repeatTask) const SizedBox(height: 12),
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
                                onChanged: (_) => setDialogState(() {}),
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
                                items: _projectPhaseStatusOptions.map((status) => DropdownMenuItem<String>(value: status, child: Text(toTitleCase(status)))).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      phase.status = value;
                                      if (value == 'Completed') {
                                        phase.completedAt ??= DateTime.now();
                                        phase.actualMinutes ??= phase.durationMinutes;
                                      }
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              _PhaseBooleanPicker(
                                label: 'Urgent *',
                                value: phase.urgent,
                                onChanged: (value) => setDialogState(() => phase.urgent = value),
                              ),
                              const SizedBox(height: 8),
                              _PhaseBooleanPicker(
                                label: 'Important *',
                                value: phase.important,
                                onChanged: (value) => setDialogState(() => phase.important = value),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: phase.durationMinutes,
                                decoration: InputDecoration(labelText: 'Estimated Time', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                items: taskDurationOptions.map((minutes) => DropdownMenuItem<int>(value: minutes, child: Text('$minutes min'))).toList(),
                                onChanged: (value) {
                                  if (value != null) setDialogState(() => phase.durationMinutes = value);
                                },
                              ),
                              if (phase.status == 'Completed') ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  value: phase.actualMinutes ?? phase.durationMinutes,
                                  decoration: InputDecoration(labelText: 'Actual Time Taken', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                  items: taskDurationOptions.map((minutes) => DropdownMenuItem<int>(value: minutes, child: Text('$minutes min'))).toList(),
                                  onChanged: (value) {
                                    if (value != null) setDialogState(() => phase.actualMinutes = value);
                                  },
                                ),
                                const SizedBox(height: 6),
                                Text('Completed: ${_formatPhaseCompletedAt(phase.completedAt)}'),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: index == 0 ? null : () => setDialogState(() {
                                      final item = projectPhases.removeAt(index);
                                      projectPhases.insert(index - 1, item);
                                    }),
                                    icon: const Icon(Icons.arrow_upward, size: 16),
                                    label: const Text('Up'),
                                  ),
                                  TextButton.icon(
                                    onPressed: index >= projectPhases.length - 1 ? null : () => setDialogState(() {
                                      final item = projectPhases.removeAt(index);
                                      projectPhases.insert(index + 1, item);
                                    }),
                                    icon: const Icon(Icons.arrow_downward, size: 16),
                                    label: const Text('Down'),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: projectPhases.length <= 1 ? null : () => setDialogState(() {
                                      final removed = projectPhases.removeAt(index);
                                      removed.dispose();
                                    }),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Delete'),
                                  ),
                                ],
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
                const SizedBox(height: 12),
                _TaskInstructionSection(
                  hiveService: hiveService,
                  taskName: nameController.text.trim().isEmpty ? (initialTask?.task ?? '') : nameController.text.trim(),
                  isRoutine: repeatTask,
                  phaseNames: repeatTask ? const <String>[] : projectPhases.map((phase) => phase.nameController.text.trim()).where((name) => name.isNotEmpty).toList(),
                  draftInstructions: isEditing ? null : draftInstructions,
                  onChanged: () => setDialogState(() {}),
                ),
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
                    items: _statusOptions.map((status) => DropdownMenuItem<String>(value: status, child: Text(toTitleCase(status)))).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: const Color(0xFFF8F4FF)),
                  items: [...categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(toTitleCase(c)))), const DropdownMenuItem<String>(value: '__add_category__', child: Text('➕ Add Category'))],
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
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task name is required')));
                  return;
                }
                if (repeatTask && scheduleEnabled && (scheduleStart == null || scheduleEnd == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select both start and end time for schedule bonus')),
                  );
                  return;
                }
                final mergedDescription = !repeatTask
                    ? _ProjectPhaseDraft.mergeIntoDescription(descriptionController.text.trim(), projectPhases)
                    : _mergeSchedule(
                        descriptionController.text.trim(),
                        enabled: scheduleEnabled,
                        start: scheduleStart,
                        end: scheduleEnd,
                        bonusPoints: scheduleBonusPoints,
                      );
                final inferredStatus = repeatTask
                    ? 'Not Updated'
                    : _ProjectPhaseDraft.inferTaskStatus(projectPhases, selectedStatus);

                final taskDueDate = repeatTask && scheduleEnabled && scheduleStart != null
                    ? DateTime(
                        dueDate.year,
                        dueDate.month,
                        dueDate.day,
                        scheduleStart!.hour,
                        scheduleStart!.minute,
                      )
                    : dueDate;

                for (final instruction in draftInstructions) {
                  await hiveService.saveInstruction(
                    instruction.copyWith(linkedTask: InstructionRule.encodeLinks([name])),
                  );
                }
                if (!context.mounted) return;
                Navigator.of(context).pop(Task(
                  task: name,
                  description: mergedDescription,
                  dueDate: taskDueDate,
                  priority: repeatTask ? 'Medium' : selectedPriority,
                  status: inferredStatus,
                  category: selectedCategory,
                  delegatedTo: repeatTask ? null : selectedDelegate,
                  done: !repeatTask && inferredStatus == 'Completed',
                  repeatTask: repeatTask,
                  repeatFrequency: repeatTask ? repeatFrequency : null,
                  urgent: selectedUrgent,
                  important: selectedImportant,
                  estimatedMinutes: repeatTask ? selectedRoutineMinutes : _ProjectPhaseDraft.totalMinutes(projectPhases),
                  hourSlot: repeatTask && scheduleEnabled ? scheduleStart?.hour : hourSlot,
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



class _TaskInstructionSection extends StatelessWidget {
  final HiveService hiveService;
  final String taskName;
  final bool isRoutine;
  final List<String> phaseNames;
  final List<InstructionRule>? draftInstructions;
  final VoidCallback onChanged;

  const _TaskInstructionSection({
    required this.hiveService,
    required this.taskName,
    required this.isRoutine,
    required this.phaseNames,
    this.draftInstructions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final linked = draftInstructions ?? _linkedInstructionsForTask(hiveService, taskName);
    final isDraftMode = draftInstructions != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('📋 Task Instructions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text(isDraftMode ? '${linked.length} pending' : '${linked.length} linked', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isRoutine ? 'Create private routine rules here. Update them from the occurrence popup.' : 'Create private rules for the whole task or a phase. Status updates happen during completion.',
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (linked.isEmpty)
            const Text('No instructions linked yet.', style: TextStyle(color: Colors.black54))
          else
            ...linked.asMap().entries.map((entry) {
              final index = entry.key;
              final instruction = entry.value;
              return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 13, backgroundColor: Color(instruction.colorValue).withOpacity(0.16), child: Icon(Icons.rule_rounded, color: Color(instruction.colorValue), size: 15)),
                  title: Text(toTitleCase(instruction.name), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(_instructionSummary(instruction)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        final updated = await _showAddInstructionForTaskDialog(
                          context,
                          hiveService,
                          taskName,
                          phaseNames,
                          initialInstruction: instruction,
                          saveImmediately: !isDraftMode,
                        );
                        if (updated != null && isDraftMode) draftInstructions![index] = updated;
                        onChanged();
                      } else if (action == 'delete') {
                        if (isDraftMode) {
                          draftInstructions!.removeAt(index);
                        } else {
                          await hiveService.deleteInstruction(instruction.id);
                        }
                        onChanged();
                      } else if (action == 'up' && isDraftMode && index > 0) {
                        final drafts = draftInstructions!;
                        final item = drafts.removeAt(index);
                        drafts.insert(index - 1, item);
                        onChanged();
                      } else if (action == 'down' && isDraftMode && index < linked.length - 1) {
                        final drafts = draftInstructions!;
                        final item = drafts.removeAt(index);
                        drafts.insert(index + 1, item);
                        onChanged();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (isDraftMode && index > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
                      if (isDraftMode && index < linked.length - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
            }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: !isDraftMode && taskName.trim().isEmpty ? null : () async {
                  final instruction = await _showAddInstructionForTaskDialog(
                    context,
                    hiveService,
                    taskName,
                    phaseNames,
                    saveImmediately: !isDraftMode,
                  );
                  if (instruction != null && isDraftMode) draftInstructions!.add(instruction);
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Instruction'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _instructionSummary(InstructionRule instruction) {
  final phase = instruction.linkedPhase.isEmpty ? '' : ' • ${instruction.linkedPhase}';
  if (instruction.isLevelBased) return '${instruction.levels.length} levels${instruction.unit.isEmpty ? '' : ' • ${instruction.unit}'}$phase';
  if (instruction.isOptionBased) return '${instruction.options.length} options$phase';
  return 'Simple • +${instruction.bonusPoints} pts • +${instruction.xpEarned} XP$phase';
}

List<InstructionRule> _linkedInstructionsForTask(HiveService hiveService, String taskName) {
  final normalizedName = taskName.trim();
  if (normalizedName.isEmpty) return const <InstructionRule>[];
  return hiveService.getInstructions().where((instruction) => instruction.isLinkedToTask(normalizedName)).toList();
}

Future<InstructionRule?> _showAddInstructionForTaskDialog(
  BuildContext context,
  HiveService hiveService,
  String taskName,
  List<String> phaseNames, {
  InstructionRule? initialInstruction,
  bool saveImmediately = true,
}) async {
  final nameController = TextEditingController(text: initialInstruction?.name ?? '');
  final descriptionController = TextEditingController(text: initialInstruction?.description ?? '');
  final bonusController = TextEditingController(text: '${initialInstruction?.bonusPoints ?? 20}');
  final xpController = TextEditingController(text: '${initialInstruction?.xpEarned ?? 5}');
  final unitController = TextEditingController(text: initialInstruction?.unit.isNotEmpty == true ? initialInstruction!.unit : 'km');
  var repeatType = initialInstruction?.repeatType ?? InstructionRule.repeatDaily;
  var instructionType = InstructionRule.typeMultipleOption;
  var levels = initialInstruction?.levels.isNotEmpty == true ? initialInstruction!.levels : const [
    InstructionLevel(id: 'level_1', name: 'Level 1', target: 2, unit: 'km', bonusPoints: 30, xpEarned: 5),
    InstructionLevel(id: 'level_2', name: 'Level 2', target: 3, unit: 'km', bonusPoints: 40, xpEarned: 8),
    InstructionLevel(id: 'level_3', name: 'Level 3', target: 5, unit: 'km', bonusPoints: 60, xpEarned: 12),
  ];
  var options = initialInstruction?.options.isNotEmpty == true ? initialInstruction!.options : const [
    InstructionOption(id: 'option_normal', name: 'Normal Juice', bonusPoints: 10, xpEarned: 2, emoji: '🥤'),
    InstructionOption(id: 'option_beetroot', name: 'Beetroot Juice', bonusPoints: 20, xpEarned: 5, emoji: '🥤'),
    InstructionOption(id: 'option_orange', name: 'Orange Juice', bonusPoints: 40, xpEarned: 8, emoji: '🍊'),
    InstructionOption(id: 'option_amla', name: 'Amla Juice', bonusPoints: 50, xpEarned: 10, emoji: '🥤'),
  ];
  var enabled = initialInstruction?.enabled ?? true;
  var streakTracking = initialInstruction?.streakTracking ?? true;
  var colorValue = initialInstruction?.colorValue ?? 0xFF43A047;
  var linkedPhase = initialInstruction?.linkedPhase ?? '';
  var instructionImagePaths = [...(initialInstruction?.imagePaths ?? const <String>[])];
  var instructionCoverImagePath = initialInstruction?.coverImagePath ?? '';
  final instruction = await showDialog<InstructionRule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(initialInstruction == null ? 'Add Task Instruction' : 'Edit Task Instruction'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Instruction Name')),
                TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Instruction Images (${instructionImagePaths.length})', style: const TextStyle(fontWeight: FontWeight.w900))),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await ImagePicker().pickMultiImage();
                        if (picked.isEmpty) return;
                        setDialogState(() {
                          instructionImagePaths = [...instructionImagePaths, ...picked.map((image) => image.path)];
                          if (instructionCoverImagePath.isEmpty && instructionImagePaths.isNotEmpty) instructionCoverImagePath = instructionImagePaths.first;
                        });
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(instructionImagePaths.isEmpty ? 'Add Images' : 'Add More Images'),
                    ),
                  ],
                ),
                if (instructionImagePaths.isEmpty)
                  const Align(alignment: Alignment.centerLeft, child: Text('No instruction images added yet.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)))
                else
                  ...instructionImagePaths.map((path) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(path == instructionCoverImagePath ? Icons.star_rounded : Icons.image_outlined, color: path == instructionCoverImagePath ? Colors.amber : null),
                        title: Text(path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(path == instructionCoverImagePath ? 'Cover image' : 'Instruction image'),
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined, size: 18), onPressed: () => _showOptionImagePathDialog(context, path)),
                            IconButton(tooltip: 'Change Cover', icon: const Icon(Icons.star_border_rounded, size: 18), onPressed: () => setDialogState(() => instructionCoverImagePath = path)),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => setDialogState(() {
                                instructionImagePaths = instructionImagePaths.where((item) => item != path).toList();
                                if (instructionCoverImagePath == path) instructionCoverImagePath = instructionImagePaths.isEmpty ? '' : instructionImagePaths.first;
                              }),
                            ),
                          ],
                        ),
                      )),
                if (phaseNames.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: linkedPhase.isEmpty ? '__whole_task__' : linkedPhase,
                    decoration: const InputDecoration(labelText: 'Attach To'),
                    items: [
                      const DropdownMenuItem(value: '__whole_task__', child: Text('Whole Task')),
                      ...phaseNames.map((phase) => DropdownMenuItem(value: phase, child: Text('Phase: $phase'))),
                    ],
                    onChanged: (value) => setDialogState(() => linkedPhase = value == '__whole_task__' ? '' : value ?? ''),
                  ),
                ],
                DropdownButtonFormField<String>(
                  value: instructionType,
                  decoration: const InputDecoration(labelText: 'Instruction Type'),
                  items: const [InstructionRule.typeMultipleOption]
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => instructionType = value ?? instructionType),
                ),
                DropdownButtonFormField<String>(
                  value: repeatType,
                  decoration: const InputDecoration(labelText: 'Repeat Type'),
                  items: const [InstructionRule.repeatDaily, InstructionRule.repeatWeekly, InstructionRule.repeatMonthly, InstructionRule.repeatYearly, InstructionRule.repeatOneTime]
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => repeatType = value ?? repeatType),
                ),
                if (false) ...[
                  TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit')),
                  const Align(alignment: Alignment.centerLeft, child: Text('Levels', style: TextStyle(fontWeight: FontWeight.w900))),
                  ...levels.asMap().entries.map((entry) {
                    final index = entry.key;
                    final level = entry.value;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: Text(toTitleCase(level.displayLabel)),
                      subtitle: Text('+${level.bonusPoints} points • ${level.xpEarned} XP'),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Edit level',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () async {
                              final edited = await _showInstructionLevelDialog(context, level);
                              if (edited != null) {
                                final updatedLevels = [...levels];
                                updatedLevels[index] = edited;
                                setDialogState(() => levels = updatedLevels);
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete level',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: levels.length <= 1 ? null : () => setDialogState(() => levels = [...levels]..removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final added = await _showInstructionLevelDialog(context, null, defaultUnit: unitController.text.trim());
                        if (added != null) setDialogState(() => levels = [...levels, added]);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Level'),
                    ),
                  ),
                ] else ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Options', style: TextStyle(fontWeight: FontWeight.w900))),
                  ...options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    return ListTile(
                      dense: true,
                      leading: Text(option.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(toTitleCase(option.name)),
                      subtitle: Text('+${option.bonusPoints} points • ${option.xpEarned} XP'),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Edit option',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () async {
                              final edited = await _showInstructionOptionDialog(context, option);
                              if (edited != null) {
                                final updatedOptions = [...options];
                                updatedOptions[index] = edited;
                                setDialogState(() => options = updatedOptions);
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete option',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: options.length <= 1 ? null : () => setDialogState(() => options = [...options]..removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final added = await _showInstructionOptionDialog(context, null);
                        if (added != null) setDialogState(() => options = [...options, added]);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Option'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final color in const [0xFF43A047, 0xFF1E88E5, 0xFFFF9800, 0xFF8E24AA, 0xFFE53935])
                      ChoiceChip(
                        selected: colorValue == color,
                        label: const Text(''),
                        avatar: CircleAvatar(backgroundColor: Color(color)),
                        onSelected: (_) => setDialogState(() => colorValue = color),
                      ),
                  ],
                ),
                SwitchListTile(value: enabled, onChanged: (value) => setDialogState(() => enabled = value), title: const Text('Enable Instruction')),
                SwitchListTile(value: streakTracking, onChanged: (value) => setDialogState(() => streakTracking = value), title: const Text('Streak Tracking')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              InstructionRule(
                id: initialInstruction?.id ?? 'instruction_${DateTime.now().microsecondsSinceEpoch}',
                name: nameController.text.trim().isEmpty ? 'Instruction' : nameController.text.trim(),
                description: descriptionController.text.trim(),
                linkedTask: InstructionRule.encodeLinks([taskName]),
                linkedPhase: linkedPhase.trim(),
                repeatType: repeatType,
                instructionType: InstructionRule.typeMultipleOption,
                unit: '',
                levels: const [],
                options: options,
                bonusPoints: int.tryParse(bonusController.text.trim()) ?? 20,
                xpEarned: int.tryParse(xpController.text.trim()) ?? 5,
                colorValue: colorValue,
                enabled: enabled,
                streakTracking: streakTracking,
                createdAt: initialInstruction?.createdAt ?? DateTime.now(),
                history: initialInstruction?.history ?? const [],
                imagePaths: instructionImagePaths,
                coverImagePath: instructionCoverImagePath,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  descriptionController.dispose();
  bonusController.dispose();
  xpController.dispose();
  unitController.dispose();
  if (instruction != null && saveImmediately) await hiveService.saveInstruction(instruction);
  return instruction;
}


Future<InstructionLevel?> _showInstructionLevelDialog(BuildContext context, InstructionLevel? initial, {String defaultUnit = 'km'}) async {
  final nameController = TextEditingController(text: initial?.name ?? 'Level');
  final targetController = TextEditingController(text: initial == null ? '' : (initial.target % 1 == 0 ? initial.target.toStringAsFixed(0) : initial.target.toString()));
  final unitController = TextEditingController(text: initial?.unit ?? defaultUnit);
  final pointsController = TextEditingController(text: '${initial?.bonusPoints ?? 20}');
  final xpController = TextEditingController(text: '${initial?.xpEarned ?? 5}');
  try {
    return await showDialog<InstructionLevel>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial == null ? 'Add Level' : 'Edit Level'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Level Name')),
              TextField(controller: targetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target')),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit')),
              TextField(controller: pointsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus Points')),
              TextField(controller: xpController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus XP')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              InstructionLevel(
                id: initial?.id ?? 'level_${DateTime.now().microsecondsSinceEpoch}',
                name: nameController.text.trim().isEmpty ? 'Level' : nameController.text.trim(),
                target: double.tryParse(targetController.text.trim()) ?? 0,
                unit: unitController.text.trim(),
                bonusPoints: int.tryParse(pointsController.text.trim()) ?? 0,
                xpEarned: int.tryParse(xpController.text.trim()) ?? 0,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    nameController.dispose();
    targetController.dispose();
    unitController.dispose();
    pointsController.dispose();
    xpController.dispose();
  }
}

Future<InstructionOption?> _showInstructionOptionDialog(BuildContext context, InstructionOption? initial) async {
  final emojiController = TextEditingController(text: initial?.emoji ?? '🥤');
  final nameController = TextEditingController(text: initial?.name ?? '');
  final descriptionController = TextEditingController(text: initial?.description ?? '');
  final pointsController = TextEditingController(text: '${initial?.bonusPoints ?? 10}');
  final xpController = TextEditingController(text: '${initial?.xpEarned ?? 2}');
  final linkController = TextEditingController();
  var imagePaths = [...(initial?.imagePaths ?? const <String>[])];
    var linkUrls = [...(initial?.effectiveLinks ?? const <String>[])];
  var coverImagePath = initial?.coverImagePath ?? '';
  try {
    return await showDialog<InstructionOption>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(initial == null ? 'Add Option' : 'Edit Option'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Option Name')),
                  TextField(controller: pointsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus Points')),
                  TextField(controller: xpController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'XP')),
                  TextField(controller: emojiController, decoration: const InputDecoration(labelText: 'Emoji')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text('Option Images (${imagePaths.length})', style: const TextStyle(fontWeight: FontWeight.w900))),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await ImagePicker().pickMultiImage();
                          if (picked.isEmpty) return;
                          setDialogState(() {
                            imagePaths = [...imagePaths, ...picked.map((image) => image.path)];
                            if (coverImagePath.isEmpty && imagePaths.isNotEmpty) coverImagePath = imagePaths.first;
                          });
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(imagePaths.isEmpty ? 'Choose From Gallery' : 'Add More Images'),
                      ),
                    ],
                  ),
                  if (imagePaths.isEmpty)
                    const Text('No images added yet.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))
                  else
                    ...imagePaths.map((path) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(path == coverImagePath ? Icons.star_rounded : Icons.image_outlined, color: path == coverImagePath ? Colors.amber : null),
                          title: Text(path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(path == coverImagePath ? 'Cover image' : 'Image'),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined, size: 18), onPressed: () => _showOptionImagePathDialog(context, path)),
                              IconButton(tooltip: 'Change Cover', icon: const Icon(Icons.star_border_rounded, size: 18), onPressed: () => setDialogState(() => coverImagePath = path)),
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => setDialogState(() {
                                  imagePaths = imagePaths.where((item) => item != path).toList();
                                  if (coverImagePath == path) coverImagePath = imagePaths.isEmpty ? '' : imagePaths.first;
                                }),
                              ),
                            ],
                          ),
                        )),
                  const SizedBox(height: 10),
                  const Text('Website / Video Links Optional', style: TextStyle(fontWeight: FontWeight.w900)),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: linkController, decoration: const InputDecoration(hintText: 'https://youtube.com/...'))),
                      IconButton(
                        tooltip: 'Add Link',
                        icon: const Icon(Icons.add_link),
                        onPressed: () => setDialogState(() {
                          final link = linkController.text.trim();
                          if (link.isEmpty || linkUrls.contains(link)) return;
                          linkUrls = [...linkUrls, link];
                          linkController.clear();
                        }),
                      ),
                    ],
                  ),
                  if (linkUrls.isEmpty)
                    const Text('No links added yet.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))
                  else
                    ...linkUrls.map((link) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.link),
                          title: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              TextButton.icon(onPressed: () => _copyOptionLink(context, link), icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Open Link')),
                              IconButton(
                                tooltip: 'Remove Link',
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => setDialogState(() => linkUrls = linkUrls.where((item) => item != link).toList()),
                              ),
                            ],
                          ),
                        )),
                  TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                InstructionOption(
                  id: initial?.id ?? 'option_${DateTime.now().microsecondsSinceEpoch}',
                  name: nameController.text.trim().isEmpty ? 'Option' : nameController.text.trim(),
                  bonusPoints: int.tryParse(pointsController.text.trim()) ?? 0,
                  xpEarned: int.tryParse(xpController.text.trim()) ?? 0,
                  emoji: emojiController.text.trim().isEmpty ? '•' : emojiController.text.trim(),
                  description: descriptionController.text.trim(),
                  imagePaths: imagePaths,
                  coverImagePath: coverImagePath,
                  linkUrl: linkUrls.isEmpty ? '' : linkUrls.first,
                  linkUrls: linkUrls,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  } finally {
    emojiController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    pointsController.dispose();
    xpController.dispose();
    linkController.dispose();
  }
}

void _showOptionImagePathDialog(BuildContext context, String path) {
  final title = _imageTitleFromPath(path);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => SelectableText('Unable to preview image:\n$path'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            SelectableText(path, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

String _imageTitleFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/').where((part) => part.trim().isNotEmpty).toList();
    final fileName = parts.isEmpty ? 'Option Image' : parts.last;
  final dotIndex = fileName.lastIndexOf('.');
  return dotIndex <= 0 ? fileName : fileName.substring(0, dotIndex);
}


Future<void> _copyOptionLink(BuildContext context, String rawLink) async {
  final link = rawLink.trim();
  if (link.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied: $link')));
}

class _ScheduleDraft {
  final bool enabled;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final int? bonusPoints;

  const _ScheduleDraft({
    required this.enabled,
    this.start,
    this.end,
    this.bonusPoints,
  });

  const _ScheduleDraft.none()
      : enabled = false,
        start = null,
        end = null,
        bonusPoints = null;
}

_ScheduleDraft _parseSchedule(String description) {
  TimeOfDay? start;
  TimeOfDay? end;
  int? bonus;
  TimeOfDay? legacy;

  for (final line in description.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith(_scheduleStartMarker)) {
      start = _parseTimeOfDay(trimmed.substring(_scheduleStartMarker.length).trim());
    } else if (trimmed.startsWith(_scheduleEndMarker)) {
      end = _parseTimeOfDay(trimmed.substring(_scheduleEndMarker.length).trim());
    } else if (trimmed.startsWith(_scheduleBonusMarker)) {
      bonus = int.tryParse(trimmed.substring(_scheduleBonusMarker.length).replaceAll('points', '').trim());
    } else if (trimmed.startsWith(_legacyScheduledTimeMarker)) {
      legacy = _parseTimeOfDay(trimmed.substring(_legacyScheduledTimeMarker.length).trim());
    }
  }

  if (start == null && end == null && legacy != null) {
    start = _addMinutes(legacy, -15);
    end = _addMinutes(legacy, 15);
  }

  final enabled = start != null && end != null;
  return enabled
      ? _ScheduleDraft(enabled: true, start: start, end: end, bonusPoints: bonus ?? _defaultScheduleBonusPoints)
      : const _ScheduleDraft.none();
}

TimeOfDay? _parseTimeOfDay(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _stripSchedule(String description) {
  return description
      .split('\n')
      .where((line) {
        final trimmed = line.trim();
        return !trimmed.startsWith(_legacyScheduledTimeMarker) &&
            !trimmed.startsWith(_scheduleStartMarker) &&
            !trimmed.startsWith(_scheduleEndMarker) &&
            !trimmed.startsWith(_scheduleBonusMarker);
      })
      .join('\n')
      .trim();
}

String _mergeSchedule(
  String description, {
  required bool enabled,
  required TimeOfDay? start,
  required TimeOfDay? end,
  required int bonusPoints,
}) {
  final cleaned = _stripSchedule(description);
  if (!enabled || start == null || end == null) return cleaned;
  final lines = <String>[
    if (cleaned.isNotEmpty) cleaned,
    '$_scheduleStartMarker ${_encodeTimeOfDay(start)}',
    '$_scheduleEndMarker ${_encodeTimeOfDay(end)}',
    '$_scheduleBonusMarker $bonusPoints',
  ];
  return lines.join('\n');
}

String _encodeTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
  final total = ((time.hour * 60) + time.minute + minutes) % (24 * 60);
  final normalized = total < 0 ? total + (24 * 60) : total;
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
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



class _PhaseBooleanPicker extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PhaseBooleanPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  value: true,
                  groupValue: value,
                  title: const Text('Yes'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (next) => onChanged(next ?? false),
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  value: false,
                  groupValue: value,
                  title: const Text('No'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (next) => onChanged(next ?? false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatPhaseCompletedAt(DateTime? completedAt) {
  if (completedAt == null) return 'Saved when you save this task';
  final hour = completedAt.hour;
  final minute = completedAt.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '${completedAt.month}/${completedAt.day}/${completedAt.year} • $displayHour:$minute $period';
}

class _ProjectPhaseDraft {
  String status;
  int durationMinutes;
  bool urgent;
  bool important;
  int? actualMinutes;
  DateTime? completedAt;
  final TextEditingController nameController;
  final TextEditingController descriptionController;

  _ProjectPhaseDraft({
    required this.status,
    required this.durationMinutes,
    required this.nameController,
    required this.descriptionController,
    this.urgent = false,
    this.important = false,
    this.actualMinutes,
    this.completedAt,
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
          urgent: _parseBool(parts.length > 4 ? parts[4] : null),
          important: _parseBool(parts.length > 5 ? parts[5] : null),
          actualMinutes: parts.length > 6 ? _parseOptionalDuration(parts[6]) : null,
          completedAt: parts.length > 7 ? DateTime.tryParse(parts[7].trim()) : null,
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
        .map((phase) {
          final completedAt = phase.status == 'Completed' ? (phase.completedAt ?? DateTime.now()) : null;
          return serializeTaskPhase(
            name: phase.nameController.text,
            description: phase.descriptionController.text,
            status: phase.status,
            minutes: phase.durationMinutes,
            urgent: phase.urgent,
            important: phase.important,
            actualMinutes: phase.status == 'Completed' ? (phase.actualMinutes ?? phase.durationMinutes) : null,
            completedAt: completedAt,
          );
        })
        .join('\n');
    if (serializedPhases.isEmpty) return cleanBase;
    return '$cleanBase\n\n$taskPhaseMarker\n$serializedPhases'.trim();
  }

  static String inferTaskStatus(List<_ProjectPhaseDraft> phases, String fallbackStatus) {
    final active = phases
        .where((phase) => phase.nameController.text.trim().isNotEmpty || phase.descriptionController.text.trim().isNotEmpty)
        .toList();
    if (active.isEmpty) return fallbackStatus;

    final statuses = active.map((phase) => phase.status.trim().toLowerCase()).toList();
    if (statuses.every((status) => status == 'completed')) return 'Completed';
    if (statuses.every((status) => status == 'cancelled')) return 'Cancelled';
    if (statuses.any((status) => status == 'completed' || status == 'in progress')) {
      return 'In Progress';
    }
    return fallbackStatus;
  }

  static int totalMinutes(List<_ProjectPhaseDraft> phases) {
    final activePhases = phases.where((phase) => phase.nameController.text.trim().isNotEmpty || phase.descriptionController.text.trim().isNotEmpty).toList();
    final source = activePhases.isEmpty ? phases : activePhases;
    return source.fold<int>(0, (sum, phase) => sum + normalizeTaskDuration(phase.durationMinutes));
  }

  static bool _parseBool(String? rawValue) {
    final normalized = (rawValue ?? '').trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }

  static int _parseDuration(String? rawValue) {
    final parsed = int.tryParse((rawValue ?? '').replaceAll('min', '').trim());
    return normalizeTaskDuration(parsed);
  }

  static int? _parseOptionalDuration(String? rawValue) {
    final parsed = int.tryParse((rawValue ?? '').replaceAll('min', '').trim());
    if (parsed == null) return null;
    return normalizeTaskDuration(parsed);
  }



}
