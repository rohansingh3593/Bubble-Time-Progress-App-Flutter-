import 'package:flutter/material.dart';
import '../constants/dashboard_themes.dart';
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

Map<String, int> _themeTaskColorOptions(DashboardThemeStyle style) {
  final color1 = style.primary;
  final color2 = style.secondary;
  final color3 = style.accent;
  final success = Color.lerp(style.primary, style.accent, 0.35) ?? style.primary;
  final warning = Color.lerp(style.secondary, style.accent, 0.42) ?? style.secondary;
  final danger = Color.lerp(style.accent, style.primary, 0.62) ?? style.accent;
  return {
    'Theme Color 1': color1.value,
    'Theme Color 2': color2.value,
    'Theme Color 3': color3.value,
    'Theme Accent': style.heroGradient.isNotEmpty ? style.heroGradient.last.value : style.accent.value,
    'Theme Success': success.value,
    'Theme Warning': warning.value,
    'Theme Danger': danger.value,
  };
}

Color _readableOn(Color color, DashboardThemeStyle style) => color.computeLuminance() < 0.45 ? style.surface : style.textPrimary;

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
  final themeStyle = DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
  final fieldFill = themeStyle.elevatedSurface;
  final panelFill = themeStyle.surface;
  final borderColor = themeStyle.primary.withOpacity(0.20);
  final taskColorOptions = _themeTaskColorOptions(themeStyle);
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
  int selectedColorValue = initialTask?.colorValue ?? taskColorOptions.values.first;
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
                  decoration: InputDecoration(labelText: 'Task Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: fieldFill),
                  autofocus: !isEditing,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: fieldFill),
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
                    decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
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
                          children: taskColorOptions.entries.map((entry) {
                            final selected = selectedColorValue == entry.value;
                            final color = Color(entry.value);
                            return ChoiceChip(
                              selected: selected,
                              label: Text(entry.key, style: TextStyle(color: selected ? _readableOn(color, themeStyle) : themeStyle.textPrimary, fontWeight: FontWeight.w700)),
                              avatar: CircleAvatar(backgroundColor: color, radius: 8),
                              selectedColor: color,
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
                          decoration: BoxDecoration(color: panelFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
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
                _TaskInstructionSection(
                  hiveService: hiveService,
                  taskName: nameController.text.trim().isEmpty ? (initialTask?.task ?? '') : nameController.text.trim(),
                  isRoutine: repeatTask,
                  phaseNames: repeatTask ? const <String>[] : projectPhases.map((phase) => phase.nameController.text.trim()).where((name) => name.isNotEmpty).toList(),
                  onChanged: () => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                if (hourSlot != null && !repeatTask)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                    child: Text('Time Slot: ${_formatHour(hourSlot!)}'),
                  ),
                if (hourSlot != null && !repeatTask) const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
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
                  decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
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
                  decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
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
                    decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                    child: const Text('Non-repeating tasks use phase-based progress. Estimated time is hidden; use phases below.'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!repeatTask) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
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
                            decoration: BoxDecoration(color: panelFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
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
                if (!repeatTask) ...[
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration: InputDecoration(labelText: 'Priority', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: fieldFill),
                    items: _priorityOptions.map((priority) => DropdownMenuItem<String>(value: priority, child: Text(priority))).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedPriority = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: fieldFill),
                    items: _statusOptions.map((status) => DropdownMenuItem<String>(value: status, child: Text(status))).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: fieldFill),
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
                    decoration: InputDecoration(labelText: 'Delegate (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: fieldFill),
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
                    decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.all(Radius.circular(14)), border: Border.fromBorderSide(BorderSide(color: borderColor))),
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
                          style: ElevatedButton.styleFrom(backgroundColor: themeStyle.accent),
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
                child: const Text('Delete Task', style: TextStyle(color: themeStyle.accent)),
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

                await _relinkTaskInstructionsIfRenamed(
                  hiveService: hiveService,
                  oldName: initialTask?.task ?? '',
                  newName: name,
                );
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
    final style = DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
    final linked = _linkedInstructionsForTask(hiveService, taskName);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.primary.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('📋 Task Instructions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: style.textPrimary))),
              Text('${linked.length} linked', style: TextStyle(fontWeight: FontWeight.w700, color: style.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isRoutine ? 'Configure routine rules here. Update them from the occurrence popup.' : 'Attach rules to the whole task or a phase. Status updates happen during completion.',
            style: TextStyle(fontSize: 12, color: style.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (linked.isEmpty)
            Text('No instructions added yet.', style: TextStyle(color: style.textMuted))
          else
            ...linked.asMap().entries.map((entry) {
              final index = entry.key;
              final instruction = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 13, backgroundColor: Color(instruction.colorValue).withOpacity(0.16), child: Text('${index + 1}', style: TextStyle(color: Color(instruction.colorValue), fontWeight: FontWeight.w900, fontSize: 12))),
                title: Text(instruction.name, style: TextStyle(fontWeight: FontWeight.w800, color: style.textPrimary)),
                subtitle: Text('Bonus: +${instruction.bonusPoints} pts • +${instruction.xpEarned} XP${instruction.linkedPhase.isEmpty ? '' : ' • ${instruction.linkedPhase}'}', style: TextStyle(color: style.textMuted)),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () async {
                        await _showAddInstructionForTaskDialog(context, hiveService, taskName, phaseNames, existing: instruction);
                        onChanged();
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () async {
                        await hiveService.deleteInstruction(instruction.id);
                        onChanged();
                      },
                    ),
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
                onPressed: taskName.trim().isEmpty ? null : () async {
                  await _showAddInstructionForTaskDialog(context, hiveService, taskName, phaseNames);
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('+ Add Instruction'),
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

Future<void> _relinkTaskInstructionsIfRenamed({
  required HiveService hiveService,
  required String oldName,
  required String newName,
}) async {
  final from = oldName.trim();
  final to = newName.trim();
  if (from.isEmpty || to.isEmpty || from.toLowerCase() == to.toLowerCase()) return;

  for (final instruction in hiveService.getInstructions().where((instruction) => instruction.isLinkedToTask(from))) {
    final updatedLinks = instruction.linkedTasks.map((linkedTask) {
      return linkedTask.trim().toLowerCase() == from.toLowerCase() ? to : linkedTask;
    }).toList();
    await hiveService.saveInstruction(instruction.copyWith(linkedTask: InstructionRule.encodeLinks(updatedLinks)));
  }
}

Future<void> _showAddInstructionForTaskDialog(BuildContext context, HiveService hiveService, String taskName, List<String> phaseNames, {InstructionRule? existing}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final descriptionController = TextEditingController(text: existing?.description ?? '');
  final bonusController = TextEditingController(text: existing == null ? '20' : '${existing.bonusPoints}');
  final xpController = TextEditingController(text: existing == null ? '5' : '${existing.xpEarned}');
  var repeatType = existing?.repeatType ?? InstructionRule.repeatDaily;
  var enabled = existing?.enabled ?? true;
  var streakTracking = existing?.streakTracking ?? true;
  final style = DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
  final instructionColors = _themeTaskColorOptions(style);
  var colorValue = existing?.colorValue ?? instructionColors.values.first;
  var linkedPhase = existing?.linkedPhase ?? '';
  var requiredInstruction = true;
  final instruction = await showDialog<InstructionRule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Add Task-Linked Instruction' : 'Edit Task-Linked Instruction'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Instruction Name *')),
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
                TextField(controller: bonusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus Points')),
                TextField(controller: xpController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'XP')),
                SwitchListTile(
                  value: requiredInstruction,
                  onChanged: (value) => setDialogState(() => requiredInstruction = value),
                  title: const Text('Required / Optional'),
                  subtitle: Text(requiredInstruction ? 'Required' : 'Optional'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in instructionColors.entries)
                      ChoiceChip(
                        selected: colorValue == entry.value,
                        label: Text(entry.key, style: TextStyle(color: colorValue == entry.value ? _readableOn(Color(entry.value), style) : style.textPrimary, fontWeight: FontWeight.w700)),
                        avatar: CircleAvatar(backgroundColor: Color(entry.value)),
                        selectedColor: Color(entry.value),
                        onSelected: (_) => setDialogState(() => colorValue = entry.value),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Task-linked instructions are managed only from this task and unlock after the task is completed.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: style.textMuted)),
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
                id: existing?.id ?? 'instruction_${DateTime.now().microsecondsSinceEpoch}',
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
                createdAt: existing?.createdAt ?? DateTime.now(),
                history: existing?.history ?? const [],
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
        color: style.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.primary.withOpacity(0.20)),
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
