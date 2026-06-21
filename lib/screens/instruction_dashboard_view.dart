import 'dart:io';

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
  String _instructionProductivityPeriod = InstructionRule.repeatDaily;

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
              _InstructionSummaryPanel(
                hiveService: widget.hiveService,
                instructions: instructions,
                today: today,
                period: _instructionProductivityPeriod,
                onPeriodChanged: (period) => setState(() => _instructionProductivityPeriod = period),
                onOpenList: _showInstructionProductivityList,
              ),
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


  void _showInstructionProductivityList(String title, List<InstructionRule> instructions) {
    final today = DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ),
              Expanded(
                child: instructions.isEmpty
                    ? const Center(child: Text('No standalone instructions found for this filter.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        itemCount: instructions.length,
                        separatorBuilder: (_, __) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final instruction = instructions[index];
                          final entry = widget.hiveService.instructionEntryForDate(instruction, today);
                          final streak = widget.hiveService.instructionCurrentStreak(instruction, today);
                          final status = !instruction.enabled
                              ? 'Disabled'
                              : entry?.followed == true
                                  ? 'Followed Today'
                                  : entry?.missed == true
                                      ? 'Missed Today'
                                      : 'Pending Today';
                          final selected = entry?.selectionSummary.isNotEmpty == true ? entry!.selectionSummary : 'None';
                          final lastUpdated = instruction.history.isEmpty ? 'Never' : _formatDate(instruction.history.last.date);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(toTitleCase(instruction.name), style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('Selected: $selected'),
                                  Text('Bonus: +${entry?.bonusPoints ?? 0} Points'),
                                  Text('Streak: $streak Day${streak == 1 ? '' : 's'}'),
                                  Text('Last Updated: $lastUpdated'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInstructionActions(InstructionRule instruction) async {
    if (instruction.isTaskLinked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task-linked instructions are updated from the related task completion popup.')),
      );
      return;
    }
    await _showInstructionUpdateDialog(instruction);
  }

  Future<void> _showInstructionUpdateDialog(InstructionRule instruction) async {
    final today = DateTime.now();
    final existingEntry = widget.hiveService.instructionEntryForDate(instruction, today);
    var status = existingEntry?.missed == true ? InstructionHistoryEntry.statusMissed : InstructionHistoryEntry.statusFollowed;
    final selectedIds = <String>{};
    if (existingEntry != null) {
      selectedIds.addAll(existingEntry.selectedOptions.map((option) => option.id));
      if (existingEntry.optionId.isNotEmpty) selectedIds.add(existingEntry.optionId);
    }

    final saved = await showDialog<_InstructionUpdateResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedOptions = instruction.options.where((option) => selectedIds.contains(option.id)).toList();
          final bonus = status == InstructionHistoryEntry.statusFollowed ? selectedOptions.fold<int>(0, (sum, option) => sum + option.bonusPoints) : 0;
          final percentage = status == InstructionHistoryEntry.statusMissed
              ? 0.0
              : instruction.options.isEmpty
                  ? 100.0
                  : (selectedOptions.length / instruction.options.length) * 100;
          final emoji = _instructionEmojiStatus(status, selectedOptions.length, percentage);
          return AlertDialog(
            title: Text('Instruction Update\n${toTitleCase(instruction.name)}'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (instruction.description.trim().isNotEmpty) ...[
                      Text(instruction.description.trim(), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                      const SizedBox(height: 12),
                    ],
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    RadioListTile<String>(
                      value: InstructionHistoryEntry.statusFollowed,
                      groupValue: status,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Followed'),
                      onChanged: (value) => setDialogState(() => status = value ?? status),
                    ),
                    RadioListTile<String>(
                      value: InstructionHistoryEntry.statusMissed,
                      groupValue: status,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Missed'),
                      onChanged: (value) => setDialogState(() => status = value ?? status),
                    ),
                    if (instruction.options.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Options', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ...instruction.options.map((option) {
                        final checked = selectedIds.contains(option.id);
                        return CheckboxListTile(
                          value: checked,
                          enabled: status == InstructionHistoryEntry.statusFollowed,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${option.name} (+${option.bonusPoints} Points)'),
                          subtitle: option.description.trim().isEmpty ? null : Text(option.description.trim()),
                          secondary: Text(option.emoji, style: const TextStyle(fontSize: 22)),
                          onChanged: (value) => setDialogState(() {
                            status = InstructionHistoryEntry.statusFollowed;
                            if (value == true) {
                              selectedIds.add(option.id);
                            } else {
                              selectedIds.remove(option.id);
                            }
                          }),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Bonus Points: +$bonus', style: const TextStyle(fontWeight: FontWeight.w900)),
                          Text('Completion Percentage: ${percentage.round()}%', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                          Text('Emoji Status: $emoji', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  _InstructionUpdateResult(
                    status: status,
                    selectedOptions: status == InstructionHistoryEntry.statusFollowed ? selectedOptions : const <InstructionOption>[],
                    bonusPoints: bonus,
                    percentage: percentage,
                    emojiStatus: emoji,
                  ),
                ),
                child: const Text('Save Update'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == null) return;
    await widget.hiveService.updateInstructionStatus(
      instruction,
      today,
      saved.status,
      options: saved.selectedOptions,
    );
    if (!mounted) return;
    await _showInstructionUpdateResultDialog(instruction, saved);
  }

  Future<void> _showInstructionUpdateResultDialog(InstructionRule instruction, _InstructionUpdateResult result) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(toTitleCase(instruction.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${result.status}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Selected Options:', style: TextStyle(fontWeight: FontWeight.w900)),
            if (result.selectedOptions.isEmpty)
              const Text('• None')
            else
              ...result.selectedOptions.map((option) => Text('• ${option.name}')),
            const SizedBox(height: 10),
            Text('Bonus Points Earned: +${result.bonusPoints}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('Completion Percentage: ${result.percentage.round()}%'),
            Text('Emoji Status: ${result.emojiStatus}'),
          ],
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }

  String _instructionEmojiStatus(String status, int selectedCount, double percentage) {
    if (status == InstructionHistoryEntry.statusMissed) return '😞 Missed';
    if (percentage >= 100) return '🤩 Perfect';
    if (percentage >= 75) return '😄 Excellent';
    if (percentage >= 50) return '😊 Good';
    if (selectedCount > 0) return '🙂 Followed';
    return '😐 Neutral';
  }

  Future<void> _showInstructionForm([InstructionRule? instruction]) async {
    final nameController = TextEditingController(text: instruction?.name ?? '');
    final descriptionController = TextEditingController(text: instruction?.description ?? '');
    final bonusController = TextEditingController(text: instruction == null ? '20' : '${instruction.bonusPoints}');
    final xpController = TextEditingController(text: instruction == null ? '5' : '${instruction.pointsEarned}');
    final unitController = TextEditingController(text: instruction?.unit ?? 'km');
    var instructionType = InstructionRule.typeMultipleOption;
    var levels = [...(instruction?.levels ?? const <InstructionLevel>[])];
    var options = [...(instruction?.options ?? const <InstructionOption>[])];
    if (options.isEmpty) {
      options = const [
        InstructionOption(id: 'option_normal', name: 'Normal Juice', bonusPoints: 10, pointsEarned: 2, emoji: '🥤'),
        InstructionOption(id: 'option_beetroot', name: 'Beetroot Juice', bonusPoints: 20, pointsEarned: 5, emoji: '🥤'),
        InstructionOption(id: 'option_orange', name: 'Orange Juice', bonusPoints: 40, pointsEarned: 8, emoji: '🍊'),
        InstructionOption(id: 'option_amla', name: 'Amla Juice', bonusPoints: 50, pointsEarned: 10, emoji: '🟢'),
      ];
    }
    if (levels.isEmpty) {
      levels = const [
        InstructionLevel(id: 'level_1', name: 'Level 1', target: 2, unit: 'km', bonusPoints: 30, pointsEarned: 5),
        InstructionLevel(id: 'level_2', name: 'Level 2', target: 3, unit: 'km', bonusPoints: 40, pointsEarned: 8),
        InstructionLevel(id: 'level_3', name: 'Level 3', target: 5, unit: 'km', bonusPoints: 60, pointsEarned: 12),
      ];
    }
    var instructionImagePaths = [...(instruction?.imagePaths ?? const <String>[])];
    var instructionCoverImagePath = instruction?.coverImagePath ?? '';
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instruction Images (${instructionImagePaths.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
                      const Text('No instruction images added yet.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))
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
                                IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined, size: 18), onPressed: () => _showImagePathDialog(path)),
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
                    const SizedBox(height: 12),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.checklist_rounded),
                      title: Text('Multiple Option Instruction'),
                      subtitle: Text('How It Works: users can select one or many checkbox options; points and Points are added from all selected options.'),
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
                                Text('+${level.bonusPoints} points • ${level.pointsEarned} Points', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
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
                                            '+${option.bonusPoints} points • ${option.pointsEarned} Points${option.description.isEmpty ? '' : ' • ${option.description}'}',
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
                    pointsEarned: int.tryParse(xpController.text.trim()) ?? 5,
                    colorValue: colorValue,
                    enabled: enabled,
                    streakTracking: streakTracking,
                    createdAt: instruction?.createdAt ?? DateTime.now(),
                    history: instruction?.history ?? const [],
                    imagePaths: instructionImagePaths,
                    coverImagePath: instructionCoverImagePath,
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
    final xpController = TextEditingController(text: existing == null ? '2' : '${existing.pointsEarned}');
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
                  TextField(controller: xpController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points')),
                  TextField(controller: emojiController, decoration: const InputDecoration(labelText: 'Emoji')),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Option Images (${imagePaths.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
                  pointsEarned: int.tryParse(xpController.text.trim()) ?? 0,
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


  Future<void> _openOptionLink(String rawLink) async {
    final link = rawLink.trim();
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied: $link')));
  }


  Future<InstructionLevel?> _showInstructionLevelDialog({InstructionLevel? existing, required String defaultUnit, required int index}) async {
    final nameController = TextEditingController(text: existing?.name ?? 'Level ${index + 1}');
    final targetController = TextEditingController(text: existing == null ? '' : (existing.target % 1 == 0 ? existing.target.toStringAsFixed(0) : existing.target.toStringAsFixed(1)));
    final unitController = TextEditingController(text: existing?.unit ?? (defaultUnit.isEmpty ? 'km' : defaultUnit));
    final bonusController = TextEditingController(text: existing == null ? '30' : '${existing.bonusPoints}');
    final xpController = TextEditingController(text: existing == null ? '5' : '${existing.pointsEarned}');
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
              TextField(controller: xpController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points')),
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
                pointsEarned: int.tryParse(xpController.text.trim()) ?? 0,
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


class _InstructionUpdateResult {
  final String status;
  final List<InstructionOption> selectedOptions;
  final int bonusPoints;
  final double percentage;
  final String emojiStatus;

  const _InstructionUpdateResult({
    required this.status,
    required this.selectedOptions,
    required this.bonusPoints,
    required this.percentage,
    required this.emojiStatus,
  });
}

class _InstructionSummaryPanel extends StatelessWidget {
  final HiveService hiveService;
  final List<InstructionRule> instructions;
  final DateTime today;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final void Function(String title, List<InstructionRule> instructions) onOpenList;

  const _InstructionSummaryPanel({required this.hiveService, required this.instructions, required this.today, required this.period, required this.onPeriodChanged, required this.onOpenList});

  @override
  Widget build(BuildContext context) {
    final standalone = instructions.where((i) => i.isStandalone).toList();
    final metrics = _metricsForPeriod(standalone);
    final periodLabel = _periodLabel(period);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary.withOpacity(0.14))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📘 Instruction Productivity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [InstructionRule.repeatDaily, InstructionRule.repeatWeekly, InstructionRule.repeatMonthly, InstructionRule.repeatYearly].map((item) {
              final selected = item == period;
              return ChoiceChip(
                selected: selected,
                label: Text(item),
                onSelected: (_) => onPeriodChanged(item),
                selectedColor: AppColors.primary.withOpacity(0.18),
                labelStyle: TextStyle(fontWeight: FontWeight.w900, color: selected ? AppColors.primary : AppColors.textPrimary),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = _InstructionProductivityPie(
                followed: metrics.followed,
                missed: metrics.missed,
                pending: metrics.pending,
              );
              final cards = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InstructionStat(label: '$period Instructions', value: '${metrics.total}', onTap: () => onOpenList('$period Standalone Instructions', standalone)),
                  _InstructionStat(label: 'Followed $periodLabel', value: '${metrics.followed}', color: Colors.green, onTap: () => onOpenList('Followed $periodLabel Instructions', metrics.followedInstructions)),
                  _InstructionStat(label: 'Missed $periodLabel', value: '${metrics.missed}', color: Colors.red, onTap: () => onOpenList('Missed $periodLabel Instructions', metrics.missedInstructions)),
                  _InstructionStat(label: 'Pending $periodLabel', value: '${metrics.pending}', onTap: () => onOpenList('Pending $periodLabel Instructions', metrics.pendingInstructions)),
                  _InstructionStat(label: 'Bonus Points $periodLabel', value: '+${metrics.bonusPoints}', color: AppColors.primary, onTap: () => onOpenList('Bonus Points $periodLabel', metrics.bonusInstructions)),
                  if (period != InstructionRule.repeatDaily)
                    _InstructionStat(label: '$period Completion', value: '${metrics.completionRate}%', color: Colors.green, onTap: () => onOpenList('$period Standalone Instructions', standalone)),
                ],
              );
              if (constraints.maxWidth < 620) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: chart), const SizedBox(height: 12), cards]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [chart, const SizedBox(width: 16), Expanded(child: cards)]);
            },
          ),
        ],
      ),
    );
  }

  _InstructionPeriodMetrics _metricsForPeriod(List<InstructionRule> standalone) {
    final range = _periodRange(today, period);
    var total = 0;
    var followed = 0;
    var missed = 0;
    var pending = 0;
    var bonusPoints = 0;
    final followedSet = <InstructionRule>{};
    final missedSet = <InstructionRule>{};
    final pendingSet = <InstructionRule>{};
    final bonusSet = <InstructionRule>{};

    for (final instruction in standalone.where((instruction) => instruction.enabled)) {
      final dates = _occurrenceDatesForInstruction(instruction, range.$1, range.$2);
      for (final date in dates) {
        total++;
        final entry = hiveService.instructionEntryForDate(instruction, date);
        if (entry?.followed == true) {
          followed++;
          bonusPoints += entry!.bonusPoints;
          followedSet.add(instruction);
          if (entry.bonusPoints > 0) bonusSet.add(instruction);
        } else if (entry?.missed == true) {
          missed++;
          missedSet.add(instruction);
        } else {
          pending++;
          pendingSet.add(instruction);
        }
      }
    }

    return _InstructionPeriodMetrics(
      total: total,
      followed: followed,
      missed: missed,
      pending: pending,
      bonusPoints: bonusPoints,
      completionRate: total == 0 ? 0 : ((followed / total) * 100).round(),
      followedInstructions: followedSet.toList(),
      missedInstructions: missedSet.toList(),
      pendingInstructions: pendingSet.toList(),
      bonusInstructions: bonusSet.toList(),
    );
  }

  (DateTime, DateTime) _periodRange(DateTime date, String period) {
    final day = DateTime(date.year, date.month, date.day);
    return switch (period) {
      InstructionRule.repeatWeekly => (day.subtract(Duration(days: day.weekday - 1)), day.subtract(Duration(days: day.weekday - 1)).add(const Duration(days: 6))),
      InstructionRule.repeatMonthly => (DateTime(day.year, day.month), DateTime(day.year, day.month + 1, 0)),
      InstructionRule.repeatYearly => (DateTime(day.year), DateTime(day.year, 12, 31)),
      _ => (day, day),
    };
  }

  List<DateTime> _occurrenceDatesForInstruction(InstructionRule instruction, DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var cursor = DateTime(start.year, start.month, start.day);
    while (!cursor.isAfter(end)) {
      if (_instructionOccursOn(instruction, cursor)) dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  bool _instructionOccursOn(InstructionRule instruction, DateTime date) {
    return switch (instruction.repeatType) {
      InstructionRule.repeatDaily => true,
      InstructionRule.repeatWeekly => date.weekday == DateTime.monday,
      InstructionRule.repeatMonthly => date.day == 1,
      InstructionRule.repeatYearly => date.month == 1 && date.day == 1,
      InstructionRule.repeatOneTime => _isSameDate(instruction.createdAt, date),
      _ => true,
    };
  }

  String _periodLabel(String period) {
    return switch (period) {
      InstructionRule.repeatDaily => 'Today',
      InstructionRule.repeatWeekly => 'This Week',
      InstructionRule.repeatMonthly => 'This Month',
      InstructionRule.repeatYearly => 'This Year',
      _ => period,
    };
  }

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

}


class _InstructionPeriodMetrics {
  final int total;
  final int followed;
  final int missed;
  final int pending;
  final int bonusPoints;
  final int completionRate;
  final List<InstructionRule> followedInstructions;
  final List<InstructionRule> missedInstructions;
  final List<InstructionRule> pendingInstructions;
  final List<InstructionRule> bonusInstructions;

  const _InstructionPeriodMetrics({
    required this.total,
    required this.followed,
    required this.missed,
    required this.pending,
    required this.bonusPoints,
    required this.completionRate,
    required this.followedInstructions,
    required this.missedInstructions,
    required this.pendingInstructions,
    required this.bonusInstructions,
  });
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


class _InstructionProductivityPie extends StatelessWidget {
  final int followed;
  final int missed;
  final int pending;

  const _InstructionProductivityPie({required this.followed, required this.missed, required this.pending});

  @override
  Widget build(BuildContext context) {
    final total = followed + missed + pending;
    final percent = total == 0 ? 0 : ((followed / total) * 100).round();
    return SizedBox(
      width: 164,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(132),
                  painter: _InstructionProductivityPiePainter(followed: followed, missed: missed, pending: pending),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.textPrimary)),
                    const Text('Followed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: const [
              _PieLegendDot(color: Colors.green, label: 'Followed'),
              _PieLegendDot(color: Colors.red, label: 'Missed'),
              _PieLegendDot(color: Colors.grey, label: 'Pending'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructionProductivityPiePainter extends CustomPainter {
  final int followed;
  final int missed;
  final int pending;

  const _InstructionProductivityPiePainter({required this.followed, required this.missed, required this.pending});

  @override
  void paint(Canvas canvas, Size size) {
    final total = followed + missed + pending;
    final rect = Offset.zero & size;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    if (total == 0) {
      canvas.drawArc(rect.deflate(12), -1.5708, 6.2832, false, strokePaint..color = Colors.grey.withOpacity(0.24));
      return;
    }
    var start = -1.5708;
    for (final segment in [
      (count: followed, color: Colors.green),
      (count: missed, color: Colors.red),
      (count: pending, color: Colors.grey),
    ]) {
      if (segment.count <= 0) continue;
      final sweep = (segment.count / total) * 6.2832;
      canvas.drawArc(rect.deflate(12), start, sweep, false, strokePaint..color = segment.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _InstructionProductivityPiePainter oldDelegate) {
    return oldDelegate.followed != followed || oldDelegate.missed != missed || oldDelegate.pending != pending;
  }
}

class _PieLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _PieLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54)),
      ],
    );
  }
}

class _InstructionStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  const _InstructionStat({required this.label, required this.value, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color ?? AppColors.textPrimary)),
        ]),
      ),
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

String _linkedTaskSummary(InstructionRule instruction) {
  final tasks = instruction.linkedTasks;
  if (tasks.length <= 2) return tasks.join(', ');
  return '${tasks.take(2).join(', ')} +${tasks.length - 2} more';
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
