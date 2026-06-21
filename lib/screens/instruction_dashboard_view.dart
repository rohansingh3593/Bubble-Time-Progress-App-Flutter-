import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/colors.dart';
import '../models/instruction.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../utils/task_time_utils.dart';
import '../utils/text_formatters.dart';

class InstructionDashboardView extends StatefulWidget {
  final HiveService hiveService;

  const InstructionDashboardView({super.key, required this.hiveService});

  @override
  State<InstructionDashboardView> createState() => _InstructionDashboardViewState();
}

class _InstructionDashboardViewState extends State<InstructionDashboardView> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Instruction Dashboard', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInstructionForm(),
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('Add Instruction'),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final instructions = widget.hiveService.getInstructions();
          final filtered = _filteredInstructions(instructions, today);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
            children: [
              _InstructionSummaryPanel(hiveService: widget.hiveService, instructions: instructions, today: today),
              const SizedBox(height: 16),
              _filterChips(),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const _EmptyInstructionCard()
              else
                ...filtered.map((instruction) => _InstructionCard(
                      hiveService: widget.hiveService,
                      instruction: instruction,
                      today: today,
                      onTap: () => _showInstructionActions(instruction),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChips() {
    const filters = ['All', 'Active', 'Followed', 'Missed', 'Pending', 'Disabled'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final selected = _filter == filter;
        return ChoiceChip(
          selected: selected,
          label: Text(filter),
          onSelected: (_) => setState(() => _filter = filter),
          selectedColor: AppColors.primary.withOpacity(0.18),
          labelStyle: TextStyle(fontWeight: FontWeight.w900, color: selected ? AppColors.primary : AppColors.textPrimary),
        );
      }).toList(),
    );
  }

  List<InstructionRule> _filteredInstructions(List<InstructionRule> instructions, DateTime today) {
    return instructions.where((instruction) {
      if (instruction.isTaskLinked) return false;
      final entry = widget.hiveService.instructionEntryForDate(instruction, today);
      switch (_filter) {
        case 'Standalone':
          return instruction.isStandalone;
        case 'Task-Linked':
          return instruction.isTaskLinked;
        case 'Active':
          return instruction.enabled;
        case 'Followed':
          return entry?.followed ?? false;
        case 'Missed':
          return entry?.missed ?? false;
        case 'Pending':
          return instruction.enabled && entry == null;
        case 'Disabled':
          return !instruction.enabled;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _showInstructionActions(InstructionRule instruction) async {
    final today = DateTime.now();
    final entry = widget.hiveService.instructionEntryForDate(instruction, today);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(toTitleCase(instruction.name), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(entry == null ? 'Pending for current period' : 'Already updated: ${entry.status}'),
                ),
                if (instruction.isTaskLinked)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'This instruction is linked to a task. Update it from the task occurrence screen.',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                    ),
                  )
                else if (entry == null && instruction.enabled) ...[
                  if (instruction.isOptionBased) ...[
                    ListTile(leading: const Icon(Icons.checklist_rounded, color: Colors.green), title: const Text('Complete with checkbox options'), subtitle: const Text('Select one or many options'), onTap: () => Navigator.pop(context, 'options')),
                    ListTile(leading: const Icon(Icons.cancel_outlined, color: Colors.red), title: const Text('Missed'), onTap: () => Navigator.pop(context, 'missed')),
                  ] else if (instruction.isLevelBased) ...[
                    ListTile(leading: const Icon(Icons.cancel_outlined, color: Colors.red), title: const Text('Missed'), onTap: () => Navigator.pop(context, 'missed')),
                    ...instruction.levels.map((level) => ListTile(
                          leading: const Icon(Icons.emoji_events_outlined, color: Colors.green),
                          title: Text('${level.displayLabel} (+${level.bonusPoints})'),
                          subtitle: Text('${level.xpEarned} XP'),
                          onTap: () => Navigator.pop(context, 'level:${level.id}'),
                        )),
                  ] else ...[
                    ListTile(leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: const Text('Followed'), onTap: () => Navigator.pop(context, 'followed')),
                    ListTile(leading: const Icon(Icons.cancel_outlined, color: Colors.red), title: const Text('Missed'), onTap: () => Navigator.pop(context, 'missed')),
                  ],
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Instruction already updated for this period.', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                  ),
                ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('View Details'), onTap: () => Navigator.pop(context, 'details')),
                ListTile(leading: Icon(instruction.enabled ? Icons.pause_circle_outline : Icons.play_circle_outline), title: Text(instruction.enabled ? 'Disable' : 'Enable'), onTap: () => Navigator.pop(context, 'toggle')),
                ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'), onTap: () => Navigator.pop(context, 'edit')),
                ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Delete from dashboard'), onTap: () => Navigator.pop(context, 'delete')),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'options' && instruction.options.isNotEmpty) {
      final selected = await _showInstructionOptionsCompletionDialog(instruction);
      if (selected == null) return;
      await widget.hiveService.updateInstructionStatus(
        instruction,
        today,
        selected.isEmpty ? InstructionHistoryEntry.statusMissed : InstructionHistoryEntry.statusFollowed,
        options: selected,
      );
      return;
    }
    if (action.startsWith('level:') && instruction.levels.isNotEmpty) {
      final levelId = action.substring('level:'.length);
      final level = instruction.levels.firstWhere((item) => item.id == levelId, orElse: () => instruction.levels.first);
      await widget.hiveService.updateInstructionStatus(instruction, today, InstructionHistoryEntry.statusFollowed, level: level);
      return;
    }
    switch (action) {
      case 'followed':
        await widget.hiveService.updateInstructionStatus(instruction, today, InstructionHistoryEntry.statusFollowed);
        break;
      case 'missed':
        await widget.hiveService.updateInstructionStatus(instruction, today, InstructionHistoryEntry.statusMissed);
        break;
      case 'toggle':
        await widget.hiveService.setInstructionEnabled(instruction, !instruction.enabled);
        break;
      case 'details':
        _showInstructionDetails(instruction);
        break;
      case 'edit':
        _showInstructionForm(instruction);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Instruction?'),
            content: const Text('This removes the instruction from the dashboard and future tracking only. Past points, XP, money, timeline history, and completed history remain saved.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete from dashboard only')),
            ],
          ),
        );
        if (confirm == true) await widget.hiveService.deleteInstruction(instruction.id);
        break;
    }
  }

  Future<void> _showInstructionForm([InstructionRule? instruction]) async {
    final nameController = TextEditingController(text: instruction?.name ?? '');
    final descriptionController = TextEditingController(text: instruction?.description ?? '');
    final bonusController = TextEditingController(text: instruction == null ? '20' : '${instruction.bonusPoints}');
    final xpController = TextEditingController(text: instruction == null ? '5' : '${instruction.xpEarned}');
    final unitController = TextEditingController(text: instruction?.unit ?? 'km');
    var instructionType = InstructionRule.typeMultipleOption;
    var levels = [...(instruction?.levels ?? const <InstructionLevel>[])];
    var options = [...(instruction?.options ?? const <InstructionOption>[])];
    if (options.isEmpty) {
      options = const [
        InstructionOption(id: 'option_normal', name: 'Normal Juice', bonusPoints: 10, xpEarned: 2, emoji: '🥤'),
        InstructionOption(id: 'option_beetroot', name: 'Beetroot Juice', bonusPoints: 20, xpEarned: 5, emoji: '🥤'),
        InstructionOption(id: 'option_orange', name: 'Orange Juice', bonusPoints: 40, xpEarned: 8, emoji: '🍊'),
        InstructionOption(id: 'option_amla', name: 'Amla Juice', bonusPoints: 50, xpEarned: 10, emoji: '🟢'),
      ];
    }
    if (levels.isEmpty) {
      levels = const [
        InstructionLevel(id: 'level_1', name: 'Level 1', target: 2, unit: 'km', bonusPoints: 30, xpEarned: 5),
        InstructionLevel(id: 'level_2', name: 'Level 2', target: 3, unit: 'km', bonusPoints: 40, xpEarned: 8),
        InstructionLevel(id: 'level_3', name: 'Level 3', target: 5, unit: 'km', bonusPoints: 60, xpEarned: 12),
      ];
    }
    var linkedTasks = [...(instruction?.linkedTasks ?? const <String>[])];
    final initialPhases = instruction?.linkedPhases ?? const <String>[];
    var linkedPhase = initialPhases.isEmpty ? '' : initialPhases.first;
    var repeatType = instruction?.repeatType ?? InstructionRule.repeatDaily;
    var enabled = instruction?.enabled ?? true;
    var streakTracking = instruction?.streakTracking ?? true;
    var colorValue = instruction?.colorValue ?? 0xFF43A047;
    final saved = await showDialog<InstructionRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availablePhases = _phaseOptionsForSelection(linkedTasks);
          if (availablePhases.isEmpty || (linkedPhase.isNotEmpty && !availablePhases.contains(linkedPhase))) linkedPhase = '';
          final taskSummary = linkedTasks.isEmpty
              ? 'No linked task selected'
              : linkedTasks.length == 1
                  ? linkedTasks.first
                  : '${linkedTasks.length} tasks selected';
          return AlertDialog(
            title: Text(instruction == null ? 'Add Instruction' : 'Edit Instruction'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Instruction Name')),
                    TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 12),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.checklist_rounded),
                      title: Text('Multiple Option Instruction'),
                      subtitle: Text('How It Works: users can select one or many checkbox options; points and XP are added from all selected options.'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Linked Task (Optional)', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54)),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final selected = await _showTaskSelectorDialog(linkedTasks);
                        if (selected == null) return;
                        setDialogState(() {
                          linkedTasks = selected;
                          if (_phaseOptionsForSelection(linkedTasks).isEmpty) linkedPhase = '';
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.22)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(taskSummary, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  const Text('Tap to select from routine and non-routine tasks', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                ],
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    if (linkedTasks.length > 1) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: linkedTasks
                            .map((task) => Chip(
                                  label: Text(task),
                                  onDeleted: () => setDialogState(() {
                                    linkedTasks = linkedTasks.where((item) => item != task).toList();
                                    if (_phaseOptionsForSelection(linkedTasks).isEmpty) linkedPhase = '';
                                  }),
                                ))
                            .toList(),
                      ),
                    ],
                    if (availablePhases.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: linkedPhase.isEmpty ? 'All Phases' : linkedPhase,
                        decoration: const InputDecoration(labelText: 'Linked Phase (Optional)'),
                        items: ['All Phases', ...availablePhases]
                            .map((phase) => DropdownMenuItem(value: phase, child: Text(phase)))
                            .toList(),
                        onChanged: (value) => setDialogState(() => linkedPhase = value == 'All Phases' ? '' : value ?? ''),
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
                    if (false) ...[
                      TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit')),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(child: Text('Levels', style: TextStyle(fontWeight: FontWeight.w900))),
                          TextButton.icon(
                            onPressed: () async {
                              final level = await _showInstructionLevelDialog(defaultUnit: unitController.text.trim(), index: levels.length);
                              if (level != null) setDialogState(() => levels = [...levels, level]);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Level'),
                          ),
                        ],
                      ),
                      ...levels.asMap().entries.map((entry) {
                        final index = entry.key;
                        final level = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(level.displayLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text('+${level.bonusPoints} points • ${level.xpEarned} XP', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 2,
                                    children: [
                                      IconButton(tooltip: 'Move up', icon: const Icon(Icons.arrow_upward, size: 18), onPressed: index == 0 ? null : () => setDialogState(() { final updated = [...levels]; final item = updated.removeAt(index); updated.insert(index - 1, item); levels = updated; })),
                                      IconButton(tooltip: 'Move down', icon: const Icon(Icons.arrow_downward, size: 18), onPressed: index == levels.length - 1 ? null : () => setDialogState(() { final updated = [...levels]; final item = updated.removeAt(index); updated.insert(index + 1, item); levels = updated; })),
                                      IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () async { final updatedLevel = await _showInstructionLevelDialog(existing: level, defaultUnit: unitController.text.trim(), index: index); if (updatedLevel != null) setDialogState(() { final updated = [...levels]; updated[index] = updatedLevel; levels = updated; }); }),
                                      IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => setDialogState(() => levels = levels.where((item) => item.id != level.id).toList())),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      Row(
                        children: [
                          const Expanded(child: Text('Options', style: TextStyle(fontWeight: FontWeight.w900))),
                          TextButton.icon(
                            onPressed: () async {
                              final option = await _showInstructionOptionDialog(index: options.length);
                              if (option != null) setDialogState(() => options = [...options, option]);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Option'),
                          ),
                        ],
                      ),
                      ...options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: 34, child: Text(option.emoji, style: const TextStyle(fontSize: 22))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(option.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 4),
                                          Text(
                                            '+${option.bonusPoints} points • ${option.xpEarned} XP${option.description.isEmpty ? '' : ' • ${option.description}'}',
                                            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 2,
                                    children: [
                                      IconButton(tooltip: 'Move up', icon: const Icon(Icons.arrow_upward, size: 18), onPressed: index == 0 ? null : () => setDialogState(() { final updated = [...options]; final item = updated.removeAt(index); updated.insert(index - 1, item); options = updated; })),
                                      IconButton(tooltip: 'Move down', icon: const Icon(Icons.arrow_downward, size: 18), onPressed: index == options.length - 1 ? null : () => setDialogState(() { final updated = [...options]; final item = updated.removeAt(index); updated.insert(index + 1, item); options = updated; })),
                                      IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () async { final updatedOption = await _showInstructionOptionDialog(existing: option, index: index); if (updatedOption != null) setDialogState(() { final updated = [...options]; updated[index] = updatedOption; options = updated; }); }),
                                      IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => setDialogState(() => options = options.where((item) => item.id != option.id).toList())),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
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
                    id: instruction?.id ?? 'instruction_${DateTime.now().microsecondsSinceEpoch}',
                    name: nameController.text.trim().isEmpty ? 'Instruction' : nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    linkedTask: InstructionRule.encodeLinks(linkedTasks),
                    linkedPhase: linkedPhase,
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
                    createdAt: instruction?.createdAt ?? DateTime.now(),
                    history: instruction?.history ?? const [],
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    // Do not dispose these local dialog controllers here: Flutter can still rebuild
    // the closing dialog route for its exit animation after showDialog completes.
    // Disposing immediately caused "TextEditingController was used after being
    // disposed" crashes while the Add/Edit Instruction dialog was closing.
    if (saved != null) await widget.hiveService.saveInstruction(saved);
  }



  Future<InstructionOption?> _showInstructionOptionDialog({InstructionOption? existing, required int index}) async {
    final nameController = TextEditingController(text: existing?.name ?? 'Option ${index + 1}');
    final bonusController = TextEditingController(text: existing == null ? '10' : '${existing.bonusPoints}');
    final xpController = TextEditingController(text: existing == null ? '2' : '${existing.xpEarned}');
    final emojiController = TextEditingController(text: existing?.emoji ?? '🥤');
    final linkController = TextEditingController();
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    var imagePaths = [...(existing?.imagePaths ?? const <String>[])];
    var linkUrls = [...(existing?.effectiveLinks ?? const <String>[])];
    var coverImagePath = existing?.coverImagePath ?? '';
    return showDialog<InstructionOption>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Option' : 'Edit Option'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Option Name')),
                  TextField(controller: bonusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus Points')),
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
                              IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined, size: 18), onPressed: () => _showImagePathDialog(path)),
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
                              TextButton.icon(onPressed: () => _openOptionLink(link), icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Open Link')),
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
                  id: existing?.id ?? 'option_${DateTime.now().microsecondsSinceEpoch}',
                  name: nameController.text.trim().isEmpty ? 'Option ${index + 1}' : nameController.text.trim(),
                  bonusPoints: int.tryParse(bonusController.text.trim()) ?? 0,
                  xpEarned: int.tryParse(xpController.text.trim()) ?? 0,
                  emoji: emojiController.text.trim().isEmpty ? '🥤' : emojiController.text.trim(),
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
  }

  void _showImagePathDialog(String path) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Option Image'),
        content: SelectableText(path),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _openOptionLink(String rawLink) async {
    final link = rawLink.trim();
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied: $link')));
  }


  Future<List<InstructionOption>?> _showInstructionOptionsCompletionDialog(InstructionRule instruction) async {
    final selectedIds = <String>{};
    return showDialog<List<InstructionOption>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(toTitleCase(instruction.name)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: instruction.options.map((option) {
                  final checked = selectedIds.contains(option.id);
                  return CheckboxListTile(
                    value: checked,
                    title: Text('${option.name} +${option.bonusPoints} ${option.emoji}'),
                    subtitle: Text('${option.xpEarned} XP${option.description.isEmpty ? '' : ' • ${option.description}'}'),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selectedIds.add(option.id);
                      } else {
                        selectedIds.remove(option.id);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, const <InstructionOption>[]), child: const Text('Missed')),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                instruction.options.where((option) => selectedIds.contains(option.id)).toList(),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }


  Future<InstructionLevel?> _showInstructionLevelDialog({InstructionLevel? existing, required String defaultUnit, required int index}) async {
    final nameController = TextEditingController(text: existing?.name ?? 'Level ${index + 1}');
    final targetController = TextEditingController(text: existing == null ? '' : (existing.target % 1 == 0 ? existing.target.toStringAsFixed(0) : existing.target.toStringAsFixed(1)));
    final unitController = TextEditingController(text: existing?.unit ?? (defaultUnit.isEmpty ? 'km' : defaultUnit));
    final bonusController = TextEditingController(text: existing == null ? '30' : '${existing.bonusPoints}');
    final xpController = TextEditingController(text: existing == null ? '5' : '${existing.xpEarned}');
    return showDialog<InstructionLevel>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Level' : 'Edit Level'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Level Name')),
              TextField(controller: targetController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target')),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit')),
              TextField(controller: bonusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus Points')),
              TextField(controller: xpController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'XP')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              InstructionLevel(
                id: existing?.id ?? 'level_${DateTime.now().microsecondsSinceEpoch}',
                name: nameController.text.trim().isEmpty ? 'Level ${index + 1}' : nameController.text.trim(),
                target: double.tryParse(targetController.text.trim()) ?? 0,
                unit: unitController.text.trim(),
                bonusPoints: int.tryParse(bonusController.text.trim()) ?? 0,
                xpEarned: int.tryParse(xpController.text.trim()) ?? 0,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  List<_InstructionTaskOption> _taskOptions() {
    final deduped = <String, _InstructionTaskOption>{};
    for (final tasks in widget.hiveService.getAllTasksByDate().values) {
      for (final task in tasks) {
        final title = task.task.trim();
        if (title.isEmpty) continue;
        final normalized = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        final routine = task.repeatTask && (task.repeatFrequency?.trim().isNotEmpty ?? false);
        final existing = deduped[normalized];
        if (existing == null || (!existing.isRoutine && routine)) {
          deduped[normalized] = _InstructionTaskOption(task: task, isRoutine: routine);
        }
      }
    }
    final options = deduped.values.toList()
      ..sort((a, b) {
        if (a.isRoutine != b.isRoutine) return a.isRoutine ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return options;
  }

  List<String> _phaseOptionsForSelection(List<String> selectedTasks) {
    if (selectedTasks.length != 1) return const <String>[];
    final selected = selectedTasks.first.trim().toLowerCase();
    _InstructionTaskOption? option;
    for (final taskOption in _taskOptions()) {
      if (taskOption.title.trim().toLowerCase() == selected) {
        option = taskOption;
        break;
      }
    }
    if (option == null || option.isRoutine) return const <String>[];
    return parseTaskPhases(option.task.description).map((phase) => phase.name).where((name) => name.trim().isNotEmpty).toList();
  }

  Future<List<String>?> _showTaskSelectorDialog(List<String> initialSelection) async {
    final searchController = TextEditingController();
    final selected = initialSelection.toSet();
    final options = _taskOptions();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = options.where((option) {
            if (query.isEmpty) return true;
            return option.title.toLowerCase().contains(query) || option.subtitle.toLowerCase().contains(query);
          }).toList();
          final routineTasks = filtered.where((option) => option.isRoutine).toList();
          final nonRoutineTasks = filtered.where((option) => !option.isRoutine).toList();
          return AlertDialog(
            title: const Text('Select Task'),
            content: SizedBox(
              width: 520,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search Task...'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        if (routineTasks.isNotEmpty) _taskSelectorSection('📅 Routine Tasks', routineTasks, selected, setDialogState),
                        if (nonRoutineTasks.isNotEmpty) _taskSelectorSection('📁 Non-Routine Tasks', nonRoutineTasks, selected, setDialogState),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No matching tasks found.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, <String>[]), child: const Text('Clear')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final orderedSelected = options.where((option) => selected.contains(option.title)).map((option) => option.title).toList();
                  for (final taskName in selected) {
                    if (!orderedSelected.contains(taskName)) orderedSelected.add(taskName);
                  }
                  Navigator.pop(context, orderedSelected);
                },
                child: const Text('Use Selected'),
              ),
            ],
          );
        },
      ),
    );
    // The selector dialog may rebuild briefly during route teardown, so avoid
    // disposing the controller synchronously while its TextField can still detach.
    return result;
  }

  Widget _taskSelectorSection(String title, List<_InstructionTaskOption> options, Set<String> selected, StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ),
        ...options.map((option) {
          final checked = selected.contains(option.title);
          return CheckboxListTile(
            value: checked,
            dense: true,
            contentPadding: EdgeInsets.zero,
            secondary: CircleAvatar(
              radius: 14,
              backgroundColor: option.isRoutine ? Colors.green.withOpacity(0.14) : Colors.blue.withOpacity(0.14),
              child: Icon(option.isRoutine ? Icons.repeat_rounded : Icons.folder_copy_outlined, color: option.isRoutine ? Colors.green : Colors.blue, size: 16),
            ),
            title: Text(option.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(option.subtitle),
            onChanged: (value) => setDialogState(() {
              if (value == true) {
                selected.add(option.title);
              } else {
                selected.remove(option.title);
              }
            }),
          );
        }),
      ],
    );
  }

  void _showInstructionDetails(InstructionRule instruction) {
    final followed = instruction.history.where((entry) => entry.followed).length;
    final missed = instruction.history.where((entry) => entry.missed).length;
    final total = followed + missed;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(toTitleCase(instruction.name)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(instruction.description.isEmpty ? 'No description.' : instruction.description),
                const SizedBox(height: 12),
                _detailLine('Current streak', '${widget.hiveService.instructionCurrentStreak(instruction, DateTime.now())}'),
                _detailLine('Best streak', '${widget.hiveService.instructionBestStreak(instruction)}'),
                _detailLine('Followed count', '$followed'),
                _detailLine('Missed count', '$missed'),
                _detailLine('Completion', total == 0 ? '0%' : '${((followed / total) * 100).round()}%'),
                _detailLine('Bonus earned', '+${instruction.history.fold<int>(0, (sum, entry) => sum + entry.bonusPoints)} pts'),
                const SizedBox(height: 12),
                const Text('Timeline history', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (instruction.history.isEmpty)
                  const Text('No updates yet.')
                else
                  ...instruction.history.reversed.take(10).map((entry) => Text('• ${_formatDate(entry.date)} — ${entry.hasLevel || entry.hasOption ? entry.selectionSummary : entry.status}${entry.followed ? ' (+${entry.bonusPoints} pts)' : ''}')),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}


class _InstructionTaskOption {
  final Task task;
  final bool isRoutine;

  const _InstructionTaskOption({required this.task, required this.isRoutine});

  String get title => task.task.trim();

  String get subtitle {
    if (isRoutine) {
      final frequency = (task.repeatFrequency?.trim().isEmpty ?? true) ? 'Routine' : task.repeatFrequency!.trim();
      return 'Routine • $frequency';
    }
    final category = task.category.trim().isEmpty ? 'Project' : task.category.trim();
    return 'Non-Routine • $category';
  }
}

class _InstructionSummaryPanel extends StatelessWidget {
  final HiveService hiveService;
  final List<InstructionRule> instructions;
  final DateTime today;

  const _InstructionSummaryPanel({required this.hiveService, required this.instructions, required this.today});

  @override
  Widget build(BuildContext context) {
    final standalone = instructions.where((i) => i.isStandalone).toList();
    final followedToday = standalone.where((i) => hiveService.instructionEntryForDate(i, today)?.followed ?? false).length;
    final missedToday = standalone.where((i) => hiveService.instructionEntryForDate(i, today)?.missed ?? false).length;
    final active = standalone.where((i) => i.enabled).length;
    final pendingToday = standalone.where((i) => i.enabled && hiveService.instructionEntryForDate(i, today) == null).length;
    final bonus = hiveService.instructionBonusForDate(today, standaloneOnly: true);
    final bestStreak = standalone.fold<int>(0, (best, i) {
      final streak = hiveService.instructionCurrentStreak(i, today);
      return streak > best ? streak : best;
    });
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary.withOpacity(0.14))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📘 Standalone Instruction Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InstructionStat(label: 'Standalone Instructions', value: '${standalone.length}'),
              _InstructionStat(label: 'Followed Today', value: '$followedToday', color: Colors.green),
              _InstructionStat(label: 'Missed Today', value: '$missedToday', color: Colors.red),
              _InstructionStat(label: 'Pending Today', value: '$pendingToday'),
              _InstructionStat(label: 'Active Instructions', value: '$active'),
              _InstructionStat(label: 'Instruction Streak', value: '$bestStreak'),
              _InstructionStat(label: 'Bonus Points Earned', value: '+$bonus'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final HiveService hiveService;
  final InstructionRule instruction;
  final DateTime today;
  final VoidCallback onTap;

  const _InstructionCard({required this.hiveService, required this.instruction, required this.today, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final entry = hiveService.instructionEntryForDate(instruction, today);
    final color = Color(instruction.colorValue);
    final statusColor = entry?.followed == true ? Colors.green : entry?.missed == true ? Colors.red : Colors.grey;
    final status = !instruction.enabled ? 'Disabled' : (entry?.levelName.isNotEmpty == true ? entry!.levelName : (entry?.status ?? 'Pending'));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withOpacity(0.18))),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.14), child: Icon(Icons.rule_folder_outlined, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(toTitleCase(instruction.name), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text((entry?.hasLevel == true || entry?.hasOption == true) ? 'Today: ${entry!.selectionSummary} • +${entry.bonusPoints} points • ${hiveService.instructionCurrentStreak(instruction, today)} streak' : '${instruction.isStandalone ? 'Standalone' : 'Task-linked'} • ${instruction.repeatType} • ${instruction.options.length} options • ${hiveService.instructionCurrentStreak(instruction, today)} streak', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                if (instruction.linkedTasks.isNotEmpty) Text('Linked: ${_linkedTaskSummary(instruction)}${instruction.linkedPhase.isEmpty ? '' : ' • ${instruction.linkedPhase}'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(toTitleCase(status), style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InstructionStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color ?? AppColors.textPrimary)),
      ]),
    );
  }
}

class _EmptyInstructionCard extends StatelessWidget {
  const _EmptyInstructionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(22)),
      child: const Text('No instructions yet. Tap “Add Instruction” to create your first productivity rule.', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
    );
  }
}

Widget _detailLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]),
  );
}

String _linkedTaskSummary(InstructionRule instruction) {
  final tasks = instruction.linkedTasks;
  if (tasks.length <= 2) return tasks.join(', ');
  return '${tasks.take(2).join(', ')} +${tasks.length - 2} more';
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
