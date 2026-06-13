import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/colors.dart';
import '../models/reward_money.dart';
import '../services/hive_service.dart';
import '../utils/path_image.dart';

class GoalDashboardView extends StatefulWidget {
  final HiveService hiveService;

  const GoalDashboardView({super.key, required this.hiveService});

  @override
  State<GoalDashboardView> createState() => _GoalDashboardViewState();
}

class _GoalDashboardViewState extends State<GoalDashboardView> {
  String _filter = 'All';
  Timer? _reminderTimer;
  int _reminderIndex = 0;
  DateTime? _snoozedUntil;

  @override
  void initState() {
    super.initState();
    _reminderTimer = Timer.periodic(const Duration(minutes: 30), (_) => _showGoalReminder());
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Goal Dashboard', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final summary = widget.hiveService.getRewardMoneySummary();
          final goals = _filteredGoals(summary.goals);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
            children: [
              _GoalSummaryPanel(summary: summary),
              const SizedBox(height: 16),
              _filterChips(),
              const SizedBox(height: 12),
              if (goals.isEmpty)
                const _EmptyGoalsCard()
              else
                ...goals.map((goal) => _GoalCard(
                      goal: goal,
                      availableBalance: summary.availableRupees,
                      onEdit: () => _showGoalForm(goal),
                      onFund: () => _showFundGoalDialog(goal),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChips() {
    const filters = ['All', RewardGoal.statusInProgress, RewardGoal.statusAchieved, RewardGoal.statusPaused, RewardGoal.statusCancelled];
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

  List<RewardGoal> _filteredGoals(List<RewardGoal> goals) {
    if (_filter == 'All') return goals;
    return goals.where((goal) => goal.effectiveStatus == _filter).toList();
  }

  void _showGoalReminder() {
    if (!mounted) return;
    final snoozedUntil = _snoozedUntil;
    if (snoozedUntil != null && DateTime.now().isBefore(snoozedUntil)) return;
    final activeGoals = widget.hiveService
        .getRewardGoals()
        .where((goal) => goal.effectiveStatus != RewardGoal.statusAchieved && goal.effectiveStatus != RewardGoal.statusCancelled)
        .toList();
    if (activeGoals.isEmpty) return;
    final goal = activeGoals[_reminderIndex % activeGoals.length];
    _reminderIndex++;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🎯 ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved: ${_formatRupees(goal.savedAmountRupees)} / ${_formatRupees(goal.targetAmountRupees)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('Still Needed: ${_formatRupees(goal.remainingAmountRupees)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: goal.progress, minHeight: 10),
            const SizedBox(height: 12),
            const Text('Complete one more task to move closer.', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _snoozedUntil = DateTime.now().add(const Duration(hours: 1));
              Navigator.pop(context);
            },
            child: const Text('Snooze'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss')),
        ],
      ),
    );
  }

  Future<void> _showFundGoalDialog(RewardGoal goal) async {
    final summary = widget.hiveService.getRewardMoneySummary();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Money to ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Balance: ${_formatRupees(summary.availableRupees)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('Still Needed: ${_formatRupees(goal.remainingAmountRupees)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Money')),
        ],
      ),
    );
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();
    if (saved != true) return;
    try {
      await widget.hiveService.fundRewardGoal(goal: goal, amountRupees: amount, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal money updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showGoalForm([RewardGoal? goal]) async {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final descriptionController = TextEditingController(text: goal?.description ?? '');
    final targetController = TextEditingController(text: goal == null ? '' : '${goal.targetAmountRupees}');
    final savedController = TextEditingController(text: goal == null ? '0' : '${goal.savedAmountRupees}');
    final categoryController = TextEditingController(text: goal?.category ?? 'Personal');
    final deadlineController = TextEditingController(text: goal?.deadline == null ? '' : _formatIsoDate(goal!.deadline!));
    var priority = goal?.priority ?? 'Medium';
    var status = goal?.effectiveStatus ?? RewardGoal.statusInProgress;
    var imagePath = goal?.imagePath ?? '';
    final saved = await showDialog<RewardGoal>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(goal == null ? 'Add Goal' : 'Edit Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Goal Name')),
                TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Goal Description')),
                TextField(controller: targetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount (₹)')),
                TextField(controller: savedController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current Saved Amount (₹)')),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Goal Category')),
                TextField(controller: deadlineController, decoration: const InputDecoration(labelText: 'Deadline (YYYY-MM-DD)')),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const ['Low', 'Medium', 'High'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => setDialogState(() => priority = value ?? priority),
                ),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [RewardGoal.statusInProgress, RewardGoal.statusAchieved, RewardGoal.statusPaused, RewardGoal.statusCancelled]
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = await _pickGoalImage(ImageSource.gallery);
                        if (path != null) setDialogState(() => imagePath = path);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from Gallery'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = await _pickGoalImage(ImageSource.camera);
                        if (path != null) setDialogState(() => imagePath = path);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take Photo'),
                    ),
                    if (imagePath.isNotEmpty)
                      TextButton.icon(onPressed: () => setDialogState(() => imagePath = ''), icon: const Icon(Icons.delete_outline), label: const Text('Remove Image')),
                  ],
                ),
                if (imagePath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(width: 360, height: 120, child: imageFromPath(imagePath, width: 360, height: 120, fit: BoxFit.cover, fallback: const Center(child: Text('Image preview unavailable')))),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final target = int.tryParse(targetController.text.trim()) ?? 0;
                final savedAmount = int.tryParse(savedController.text.trim()) ?? 0;
                Navigator.pop(
                  context,
                  RewardGoal(
                    id: goal?.id ?? 'goal_${DateTime.now().microsecondsSinceEpoch}',
                    name: nameController.text.trim().isEmpty ? 'Reward Goal' : nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    targetAmountRupees: target,
                    savedAmountRupees: savedAmount,
                    priority: priority,
                    deadline: DateTime.tryParse(deadlineController.text.trim()),
                    imagePath: imagePath,
                    category: categoryController.text.trim().isEmpty ? 'Personal' : categoryController.text.trim(),
                    status: target > 0 && savedAmount >= target ? RewardGoal.statusAchieved : status,
                    createdAt: goal?.createdAt ?? DateTime.now(),
                    history: goal?.history ?? const [],
                  ),
                );
              },
              child: const Text('Save Goal'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    targetController.dispose();
    savedController.dispose();
    categoryController.dispose();
    deadlineController.dispose();
    if (saved != null) await widget.hiveService.saveRewardGoal(saved);
  }

  Future<String?> _pickGoalImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
      return image?.path;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open image picker: $error')));
      return null;
    }
  }
}

class _GoalSummaryPanel extends StatelessWidget {
  final RewardMoneySummary summary;

  const _GoalSummaryPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    final goals = summary.goals;
    final achieved = goals.where((goal) => goal.effectiveStatus == RewardGoal.statusAchieved).length;
    final inProgress = goals.where((goal) => goal.effectiveStatus == RewardGoal.statusInProgress).length;
    final totalTarget = goals.fold<int>(0, (sum, goal) => sum + goal.targetAmountRupees);
    final totalSaved = goals.fold<int>(0, (sum, goal) => sum + goal.savedAmountRupees);
    final stillNeeded = (totalTarget - totalSaved).clamp(0, totalTarget).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.14)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Goal Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GoalStat(label: 'Total Goals', value: '${goals.length}'),
              _GoalStat(label: 'In Progress', value: '$inProgress'),
              _GoalStat(label: 'Achieved', value: '$achieved', color: Colors.green.shade700),
              _GoalStat(label: 'Total Target', value: _formatRupees(totalTarget)),
              _GoalStat(label: 'Total Saved', value: _formatRupees(totalSaved), color: AppColors.primary),
              _GoalStat(label: 'Still Needed', value: _formatRupees(stillNeeded), color: Colors.deepOrange.shade700),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _GoalStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final RewardGoal goal;
  final int availableBalance;
  final VoidCallback onEdit;
  final VoidCallback onFund;

  const _GoalCard({required this.goal, required this.availableBalance, required this.onEdit, required this.onFund});

  @override
  Widget build(BuildContext context) {
    final achieved = goal.effectiveStatus == RewardGoal.statusAchieved;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: achieved ? Colors.green.shade50 : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: achieved ? Colors.green.shade300 : AppColors.primary.withOpacity(0.14), width: achieved ? 2 : 1),
        boxShadow: [BoxShadow(color: achieved ? Colors.green.withOpacity(0.22) : const Color(0x11000000), blurRadius: achieved ? 24 : 12, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: goal.imagePath.isEmpty
                    ? Container(width: 72, height: 72, color: AppColors.surface, child: const Icon(Icons.flag_outlined, color: AppColors.primary, size: 32))
                    : imageFromPath(goal.imagePath, width: 72, height: 72, fit: BoxFit.cover, fallback: Container(width: 72, height: 72, color: AppColors.surface, child: const Icon(Icons.flag_outlined))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(goal.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
                        _StatusPill(status: goal.effectiveStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${goal.category} • ${goal.priority} priority', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                    if (goal.description.isNotEmpty) Text(goal.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Target: ${_formatRupees(goal.targetAmountRupees)} • Saved: ${_formatRupees(goal.savedAmountRupees)} • Still Needed: ${_formatRupees(goal.remainingAmountRupees)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: goal.progress, minHeight: 10, backgroundColor: Colors.black12, color: achieved ? Colors.green : AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text('Progress: ${(goal.progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          if (achieved) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(999)),
              child: const Text('🎉 Goal Achieved • Badge Unlocked', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Edit'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(onPressed: availableBalance > 0 && !achieved ? onFund : null, icon: const Icon(Icons.add_card_outlined), label: const Text('Add Money'))),
            ],
          ),
          if (goal.history.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Goal History', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            ...goal.history.reversed.take(3).map((entry) => Text('• ${_formatDate(entry.date)} — ${entry.title}${entry.note.isEmpty ? '' : ' (${entry.note})'}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54))),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RewardGoal.statusAchieved => Colors.green,
      RewardGoal.statusPaused => Colors.orange,
      RewardGoal.statusCancelled => Colors.red,
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _EmptyGoalsCard extends StatelessWidget {
  const _EmptyGoalsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(22)),
      child: const Text('No goals yet. Tap “Add Goal” to create your first offline reward goal.', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
    );
  }
}

String _formatRupees(int value) => '₹${_formatInt(value)}';

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _formatIsoDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[(date.month - 1).clamp(0, 11).toInt()]} ${date.year}';
}
