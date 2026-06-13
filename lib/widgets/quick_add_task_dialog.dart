import 'package:flutter/material.dart';
import '../models/instruction.dart';
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
                    if (isEditing) setDialogState(() {});
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
                                items: _projectPhaseStatusOptions.map((status) => DropdownMenuItem<String>(value: status, child: Text(status))).toList(),
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
                if (isEditing) ...[
                  const SizedBox(height: 12),
                  _TaskInstructionSection(
                    hiveService: hiveService,
                    taskName: nameController.text.trim().isEmpty ? (initialTask?.task ?? '') : nameController.text.trim(),
                    isRoutine: repeatTask,
                    phaseNames: repeatTask ? const <String>[] : projectPhases.map((phase) => phase.nameController.text.trim()).where((name) => name.isNotEmpty).toList(),
                    onChanged: () => setDialogState(() {}),
                  ),
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
  final VoidCallback onChanged;

  const _TaskInstructionSection({
    required this.hiveService,
    required this.taskName,
    required this.isRoutine,
    required this.phaseNames,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final linked = _linkedInstructionsForTask(hiveService, taskName);
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
              const Expanded(child: Text('Instructions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text('${linked.length} linked', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isRoutine ? 'Configure routine rules here. Update them from the occurrence popup.' : 'Attach rules to the whole task or a phase. Status updates happen during completion.',
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (linked.isEmpty)
            const Text('No instructions linked yet.', style: TextStyle(color: Colors.black54))
          else
            ...linked.map((instruction) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 13, backgroundColor: Color(instruction.colorValue).withOpacity(0.16), child: Icon(Icons.rule_rounded, color: Color(instruction.colorValue), size: 15)),
                  title: Text(instruction.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Bonus: +${instruction.bonusPoints}${instruction.linkedPhase.isEmpty ? '' : ' • ${instruction.linkedPhase}'}'),
                )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: taskName.trim().isEmpty ? null : () async {
                  await _showAddInstructionForTaskDialog(context, hiveService, taskName, phaseNames);
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Instruction'),
              ),
              OutlinedButton.icon(
                onPressed: taskName.trim().isEmpty ? null : () async {
                  await _showLinkInstructionDialog(context, hiveService, taskName, phaseNames);
                  onChanged();
                },
                icon: const Icon(Icons.link_rounded),
                label: const Text('Link Existing Instruction'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<InstructionRule> _linkedInstructionsForTask(HiveService hiveService, String taskName) {
  final normalizedName = taskName.trim();
  if (normalizedName.isEmpty) return const <InstructionRule>[];
  return hiveService.getInstructions().where((instruction) => instruction.isLinkedToTask(normalizedName)).toList();
}

Future<void> _showAddInstructionForTaskDialog(BuildContext context, HiveService hiveService, String taskName, List<String> phaseNames) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final bonusController = TextEditingController(text: '20');
  final xpController = TextEditingController(text: '5');
  var repeatType = InstructionRule.repeatDaily;
  var enabled = true;
  var streakTracking = true;
  var colorValue = 0xFF43A047;
  var linkedPhase = '';
  final instruction = await showDialog<InstructionRule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Instruction'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Instruction Name')),
                TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
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
                  value: repeatType,
                  decoration: const InputDecoration(labelText: 'Repeat Type'),
                  items: const [InstructionRule.repeatDaily, InstructionRule.repeatWeekly, InstructionRule.repeatMonthly, InstructionRule.repeatYearly, InstructionRule.repeatOneTime]
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => repeatType = value ?? repeatType),
                ),
                TextField(controller: bonusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus Points')),
                TextField(controller: xpController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'XP')),
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
                id: 'instruction_${DateTime.now().microsecondsSinceEpoch}',
                name: nameController.text.trim().isEmpty ? 'Instruction' : nameController.text.trim(),
                description: descriptionController.text.trim(),
                linkedTask: InstructionRule.encodeLinks([taskName]),
                linkedPhase: linkedPhase.trim(),
                repeatType: repeatType,
                bonusPoints: int.tryParse(bonusController.text.trim()) ?? 20,
                xpEarned: int.tryParse(xpController.text.trim()) ?? 5,
                colorValue: colorValue,
                enabled: enabled,
                streakTracking: streakTracking,
                createdAt: DateTime.now(),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (instruction != null) await hiveService.saveInstruction(instruction);
}

Future<void> _showLinkInstructionDialog(BuildContext context, HiveService hiveService, String taskName, List<String> phaseNames) async {
  final searchController = TextEditingController();
  var selectedIds = <String>{};
  var linkedPhase = '';
  final selected = await showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final query = searchController.text.trim().toLowerCase();
        final instructions = hiveService.getInstructions().where((instruction) {
          if (instruction.isLinkedToTask(taskName)) return false;
          if (query.isEmpty) return true;
          return instruction.name.toLowerCase().contains(query) || instruction.description.toLowerCase().contains(query);
        }).toList();
        return AlertDialog(
          title: const Text('Link Existing Instruction'),
          content: SizedBox(
            width: 460,
            height: 460,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search instructions...'),
                  onChanged: (_) => setDialogState(() {}),
                ),
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
                const SizedBox(height: 10),
                Expanded(
                  child: instructions.isEmpty
                      ? const Center(child: Text('No matching instructions found.'))
                      : ListView(
                          children: instructions.map((instruction) {
                            final checked = selectedIds.contains(instruction.id);
                            return CheckboxListTile(
                              value: checked,
                              title: Text(instruction.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text('+${instruction.bonusPoints} bonus points'),
                              onChanged: (value) => setDialogState(() {
                                selectedIds = {...selectedIds};
                                if (value == true) {
                                  selectedIds.add(instruction.id);
                                } else {
                                  selectedIds.remove(instruction.id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(context, selectedIds), child: const Text('Link Selected')),
          ],
        );
      },
    ),
  );
  if (selected == null || selected.isEmpty) return;
  for (final instruction in hiveService.getInstructions()) {
    if (!selected.contains(instruction.id)) continue;
    final linkedTasks = [...instruction.linkedTasks, taskName];
    await hiveService.saveInstruction(
      instruction.copyWith(
        linkedTask: InstructionRule.encodeLinks(linkedTasks),
        linkedPhase: linkedPhase.trim().isEmpty ? instruction.linkedPhase : linkedPhase.trim(),
      ),
    );
  }
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

  static int _parseDuration(String? rawValue) {
    final parsed = int.tryParse((rawValue ?? '').replaceAll('min', '').trim());
    return normalizeTaskDuration(parsed);
  }

}
