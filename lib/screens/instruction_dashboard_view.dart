import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/instruction.dart';
import '../services/hive_service.dart';

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
      final entry = widget.hiveService.instructionEntryForDate(instruction, today);
      switch (_filter) {
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(instruction.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(entry == null ? 'Pending for current period' : 'Already updated: ${entry.status}'),
            ),
            if (entry == null && instruction.enabled) ...[
              ListTile(leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: const Text('Followed'), onTap: () => Navigator.pop(context, 'followed')),
              ListTile(leading: const Icon(Icons.cancel_outlined, color: Colors.red), title: const Text('Missed'), onTap: () => Navigator.pop(context, 'missed')),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Instruction already updated for this period.', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
              ),
            ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('View Details'), onTap: () => Navigator.pop(context, 'details')),
            ListTile(leading: Icon(instruction.enabled ? Icons.pause_circle_outline : Icons.play_circle_outline), title: Text(instruction.enabled ? 'Disable' : 'Enable'), onTap: () => Navigator.pop(context, 'toggle')),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'), onTap: () => Navigator.pop(context, 'edit')),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
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
    }
  }

  Future<void> _showInstructionForm([InstructionRule? instruction]) async {
    final nameController = TextEditingController(text: instruction?.name ?? '');
    final descriptionController = TextEditingController(text: instruction?.description ?? '');
    final linkedTaskController = TextEditingController(text: instruction?.linkedTask ?? '');
    final linkedPhaseController = TextEditingController(text: instruction?.linkedPhase ?? '');
    final bonusController = TextEditingController(text: instruction == null ? '20' : '${instruction.bonusPoints}');
    final xpController = TextEditingController(text: instruction == null ? '5' : '${instruction.xpEarned}');
    var repeatType = instruction?.repeatType ?? InstructionRule.repeatDaily;
    var enabled = instruction?.enabled ?? true;
    var streakTracking = instruction?.streakTracking ?? true;
    var colorValue = instruction?.colorValue ?? 0xFF43A047;
    final saved = await showDialog<InstructionRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(instruction == null ? 'Add Instruction' : 'Edit Instruction'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Instruction Name')),
                  TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                  TextField(controller: linkedTaskController, decoration: const InputDecoration(labelText: 'Linked Task (Optional)')),
                  TextField(controller: linkedPhaseController, decoration: const InputDecoration(labelText: 'Linked Phase (Optional)')),
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
                  id: instruction?.id ?? 'instruction_${DateTime.now().microsecondsSinceEpoch}',
                  name: nameController.text.trim().isEmpty ? 'Instruction' : nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  linkedTask: linkedTaskController.text.trim(),
                  linkedPhase: linkedPhaseController.text.trim(),
                  repeatType: repeatType,
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
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    linkedTaskController.dispose();
    linkedPhaseController.dispose();
    bonusController.dispose();
    xpController.dispose();
    if (saved != null) await widget.hiveService.saveInstruction(saved);
  }

  void _showInstructionDetails(InstructionRule instruction) {
    final followed = instruction.history.where((entry) => entry.followed).length;
    final missed = instruction.history.where((entry) => entry.missed).length;
    final total = followed + missed;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(instruction.name),
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
                  ...instruction.history.reversed.take(10).map((entry) => Text('• ${_formatDate(entry.date)} — ${entry.status}${entry.followed ? ' (+${entry.bonusPoints} pts)' : ''}')),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _InstructionSummaryPanel extends StatelessWidget {
  final HiveService hiveService;
  final List<InstructionRule> instructions;
  final DateTime today;

  const _InstructionSummaryPanel({required this.hiveService, required this.instructions, required this.today});

  @override
  Widget build(BuildContext context) {
    final followedToday = instructions.where((i) => hiveService.instructionEntryForDate(i, today)?.followed ?? false).length;
    final missedToday = instructions.where((i) => hiveService.instructionEntryForDate(i, today)?.missed ?? false).length;
    final active = instructions.where((i) => i.enabled).length;
    final bonus = hiveService.instructionBonusForDate(today);
    final bestStreak = instructions.fold<int>(0, (best, i) {
      final streak = hiveService.instructionCurrentStreak(i, today);
      return streak > best ? streak : best;
    });
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary.withOpacity(0.14))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📘 Instruction Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InstructionStat(label: 'Total Instructions', value: '${instructions.length}'),
              _InstructionStat(label: 'Followed Today', value: '$followedToday', color: Colors.green),
              _InstructionStat(label: 'Missed Today', value: '$missedToday', color: Colors.red),
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
    final status = !instruction.enabled ? 'Disabled' : entry?.status ?? 'Pending';
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
                Text(instruction.name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('${instruction.repeatType} • +${instruction.bonusPoints} points • ${hiveService.instructionCurrentStreak(instruction, today)} streak', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                if (instruction.linkedTask.isNotEmpty) Text('Linked: ${instruction.linkedTask}${instruction.linkedPhase.isEmpty ? '' : ' • ${instruction.linkedPhase}'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12)),
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

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
