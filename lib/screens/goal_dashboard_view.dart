import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/colors.dart';
import '../models/reward_money.dart';
import '../services/hive_service.dart';

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
                      onView: () => _showGoalDetails(goal),
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
    var category = goal?.category ?? 'Personal';
    final startDateController = TextEditingController(text: goal?.startDate == null ? _formatIsoDate(DateTime.now()) : _formatIsoDate(goal!.startDate!));
    final deadlineController = TextEditingController(text: goal?.deadline == null ? '' : _formatIsoDate(goal!.deadline!));
    var priority = goal?.priority ?? 'Medium';
    var status = goal?.effectiveStatus ?? RewardGoal.statusInProgress;
    var images = [...(goal?.galleryImages ?? const <RewardGoalImage>[])];
    var milestones = [...(goal?.milestones ?? const <RewardGoalMilestone>[])];
    if (milestones.isEmpty) {
      milestones = const [
        RewardGoalMilestone(id: 'ms_20', percent: 20, title: '20% milestone'),
        RewardGoalMilestone(id: 'ms_40', percent: 40, title: '40% milestone'),
        RewardGoalMilestone(id: 'ms_60', percent: 60, title: '60% milestone'),
        RewardGoalMilestone(id: 'ms_80', percent: 80, title: '80% milestone'),
        RewardGoalMilestone(id: 'ms_100', percent: 100, title: 'Goal achieved'),
      ];
    }
    final saved = await showDialog<RewardGoal>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(goal == null ? 'Add Goal' : 'Edit Goal'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Goal Name')),
                TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Goal Description')),
                TextField(controller: targetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount (₹)'), onChanged: (_) => setDialogState(() {})),
                TextField(controller: savedController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current Saved Amount (₹)'), onChanged: (_) => setDialogState(() {})),
                Builder(builder: (_) {
                  final target = int.tryParse(targetController.text.trim()) ?? 0;
                  final savedAmount = int.tryParse(savedController.text.trim()) ?? 0;
                  final remaining = (target - savedAmount).clamp(0, target).toInt();
                  final progress = target <= 0 ? 0 : ((savedAmount / target).clamp(0, 1) * 100).round();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Remaining: ${_formatRupees(remaining)} • Progress: $progress%', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black54)),
                  );
                }),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Goal Category'),
                  items: const ['Personal', 'Health', 'Career', 'Education', 'Finance', 'Travel', 'Lifestyle', 'Family', 'Other'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => setDialogState(() => category = value ?? category),
                ),
                TextField(controller: startDateController, decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD)')),
                TextField(controller: deadlineController, decoration: const InputDecoration(labelText: 'Deadline (YYYY-MM-DD)')),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const ['Low', 'Medium', 'High', 'Critical'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
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
                const Align(alignment: Alignment.centerLeft, child: Text('📷 Add Goal Images', style: TextStyle(fontWeight: FontWeight.w900))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = await _pickGoalImage(ImageSource.gallery);
                        if (path != null) setDialogState(() => images = [...images, RewardGoalImage(path: path, dateAdded: DateTime.now())]);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Add from Gallery'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = await _pickGoalImage(ImageSource.camera);
                        if (path != null) setDialogState(() => images = [...images, RewardGoalImage(path: path, dateAdded: DateTime.now())]);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Add from Camera'),
                    ),
                  ],
                ),
                if (images.isNotEmpty)
                  SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return _GoalImageThumb(
                          image: image,
                          isCover: index == 0,
                          onMakeCover: index == 0 ? null : () => setDialogState(() { final updated = [...images]; final item = updated.removeAt(index); updated.insert(0, item); images = updated; }),
                          onDelete: () => setDialogState(() => images = images.where((item) => item.path != image.path).toList()),
                          onMoveLeft: index == 0 ? null : () => setDialogState(() { final updated = [...images]; final item = updated.removeAt(index); updated.insert(index - 1, item); images = updated; }),
                          onMoveRight: index == images.length - 1 ? null : () => setDialogState(() { final updated = [...images]; final item = updated.removeAt(index); updated.insert(index + 1, item); images = updated; }),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('Milestones', style: TextStyle(fontWeight: FontWeight.w900))),
                ...milestones.map((milestone) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${milestone.percent}%')),
                      title: Text(milestone.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(milestone.reward.isEmpty ? 'Optional reward • ${milestone.bonusXp} XP' : '${milestone.reward} • ${milestone.bonusXp} XP'),
                    )),
                ],
              ),
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
                    imagePath: images.isEmpty ? '' : images.first.path,
                    images: images,
                    milestones: milestones,
                    startDate: DateTime.tryParse(startDateController.text.trim()),
                    category: category,
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
    startDateController.dispose();
    deadlineController.dispose();
    if (saved != null) await widget.hiveService.saveRewardGoal(saved);
  }


  void _showGoalDetails(RewardGoal goal) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(goal.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(goal.description.isEmpty ? 'No description yet.' : goal.description, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 14),
            if (goal.galleryImages.isNotEmpty) ...[
              const Text('Image Gallery', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: goal.galleryImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final image = goal.galleryImages[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(File(image.path), width: 190, height: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 190, color: AppColors.surface, child: const Icon(Icons.image_not_supported_outlined))),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text('Financial Progress', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('${_formatRupees(goal.savedAmountRupees)} / ${_formatRupees(goal.targetAmountRupees)} • ${_formatRupees(goal.remainingAmountRupees)} remaining', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: goal.progress, minHeight: 12),
            const SizedBox(height: 14),
            const Text('Milestones', style: TextStyle(fontWeight: FontWeight.w900)),
            ...goal.milestones.map((milestone) => ListTile(leading: CircleAvatar(child: Text('${milestone.percent}%')), title: Text(milestone.title), subtitle: Text('${milestone.description}${milestone.reward.isEmpty ? '' : ' • Reward: ${milestone.reward}'}'))),
            const SizedBox(height: 8),
            const Text('Journey Timeline', style: TextStyle(fontWeight: FontWeight.w900)),
            ...goal.history.reversed.map((entry) => ListTile(leading: const Icon(Icons.timeline), title: Text(entry.title), subtitle: Text('${_formatDate(entry.date)}${entry.note.isEmpty ? '' : ' • ${entry.note}'}'), trailing: entry.amountRupees == 0 ? null : Text(_formatRupees(entry.amountRupees)))),
          ],
        ),
      ),
    );
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


class _GoalImageThumb extends StatelessWidget {
  final RewardGoalImage image;
  final bool isCover;
  final VoidCallback? onMakeCover;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  const _GoalImageThumb({required this.image, required this.isCover, this.onMakeCover, this.onDelete, this.onMoveLeft, this.onMoveRight});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(image.path), width: 120, height: 82, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 120, height: 82, color: AppColors.surface, child: const Icon(Icons.image_not_supported_outlined))),
              ),
              if (isCover)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)), child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(tooltip: 'Move left', visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_left, size: 18), onPressed: onMoveLeft),
              IconButton(tooltip: 'Cover', visualDensity: VisualDensity.compact, icon: const Icon(Icons.star_border, size: 18), onPressed: onMakeCover),
              IconButton(tooltip: 'Move right', visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_right, size: 18), onPressed: onMoveRight),
              IconButton(tooltip: 'Delete', visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete),
            ],
          ),
        ],
      ),
    );
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
  final VoidCallback onView;

  const _GoalCard({required this.goal, required this.availableBalance, required this.onEdit, required this.onFund, required this.onView});

  @override
  Widget build(BuildContext context) {
    final achieved = goal.effectiveStatus == RewardGoal.statusAchieved;
    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
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
                child: goal.coverImagePath.isEmpty
                    ? Container(width: 72, height: 72, color: AppColors.surface, child: const Icon(Icons.flag_outlined, color: AppColors.primary, size: 32))
                    : Image.file(File(goal.coverImagePath), width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: AppColors.surface, child: const Icon(Icons.flag_outlined))),
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
          Text('Progress: ${(goal.progress * 100).round()}% • ${goal.deadline == null ? 'No deadline' : '${goal.deadline!.difference(DateTime.now()).inDays.clamp(0, 99999)} days remaining'} • ${goal.galleryImages.length} images • ${goal.milestones.length} milestones', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
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
            const Text('Goal Journey Timeline', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            ...goal.history.reversed.take(3).map((entry) => Text('• ${_formatDate(entry.date)} — ${entry.title}${entry.note.isEmpty ? '' : ' (${entry.note})'}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54))),
          ],
        ],
      ),
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
