import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/text_formatters.dart';

import '../models/reward_money.dart';
import '../services/hive_service.dart';

class GoalDashboardView extends StatefulWidget {
  final HiveService hiveService;

  GoalDashboardView({super.key, required this.hiveService});

  @override
  State<GoalDashboardView> createState() => _GoalDashboardViewState();
}

class _GoalDashboardViewState extends State<GoalDashboardView> {
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text('Goal Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalForm(),
        icon: Icon(Icons.add),
        label: Text('Add Goal'),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final summary = widget.hiveService.getRewardMoneySummary();
          final goals = _filteredGoals(summary.goals);
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 96),
            children: [
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Personal tracking only. Recording spending does not transfer money or provide a payout.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              ExpansionTile(
                  title: Text('Reward budget summary'),
                  children: [_GoalSummaryPanel(summary: summary)]),
              SizedBox(height: 16),
              _filterChips(),
              SizedBox(height: 12),
              if (goals.isEmpty)
                _EmptyGoalsCard()
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
    const filters = [
      'All',
      RewardGoal.statusInProgress,
      RewardGoal.statusAchieved,
      RewardGoal.statusPaused,
      RewardGoal.statusCancelled
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final selected = _filter == filter;
        return ChoiceChip(
          selected: selected,
          label: Text(filter),
          onSelected: (_) => setState(() => _filter = filter),
          selectedColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.18),
          labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface),
        );
      }).toList(),
    );
  }

  List<RewardGoal> _filteredGoals(List<RewardGoal> goals) {
    if (_filter == 'All') return goals;
    return goals.where((goal) => goal.effectiveStatus == _filter).toList();
  }

  Future<void> _showFundGoalDialog(RewardGoal goal) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    bool saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, update) => AlertDialog(
                  title: Text('Add money to ${goal.name}'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        'Available: ${_formatRupees(widget.hiveService.getRewardMoneySummary().availableRupees)}'),
                    TextField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Amount (INR)', errorText: error)),
                    TextField(
                        controller: note,
                        decoration: InputDecoration(labelText: 'Note')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(dialog),
                        child: Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final value = int.tryParse(amount.text.trim());
                                if (value == null ||
                                    value <= 0 ||
                                    value >
                                        widget.hiveService
                                            .getRewardMoneySummary()
                                            .availableRupees) {
                                  update(() => error =
                                      'Enter a positive whole amount within your budget');
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  await widget.hiveService.fundRewardGoal(
                                      goal: goal,
                                      amountRupees: value,
                                      note: note.text.trim());
                                  if (dialog.mounted) Navigator.pop(dialog);
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Goal money updated')));
                                } catch (_) {
                                  if (dialog.mounted)
                                    update(() {
                                      saving = false;
                                      error = 'Could not save. Please retry.';
                                    });
                                }
                              },
                        child: Text(saving ? 'Saving...' : 'Add money'))
                  ],
                )));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    amount.dispose();
    note.dispose();
  }

  Future<void> _showGoalForm([RewardGoal? goal]) async {
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? error;
    final nameController = TextEditingController(text: goal?.name ?? '');
    final descriptionController =
        TextEditingController(text: goal?.description ?? '');
    final targetController = TextEditingController(
        text: goal == null ? '' : '${goal.targetAmountRupees}');
    final savedController = TextEditingController(
        text: goal == null ? '0' : '${goal.savedAmountRupees}');
    var category = goal?.category ?? 'Personal';
    final startDateController = TextEditingController(
        text: goal?.startDate == null
            ? _formatIsoDate(DateTime.now())
            : _formatIsoDate(goal!.startDate!));
    final deadlineController = TextEditingController(
        text: goal?.deadline == null ? '' : _formatIsoDate(goal!.deadline!));
    var priority = goal?.priority ?? 'Medium';
    var status = goal?.effectiveStatus ?? RewardGoal.statusInProgress;
    var images = [...(goal?.galleryImages ?? <RewardGoalImage>[])];
    var milestones = [...(goal?.milestones ?? <RewardGoalMilestone>[])];
    if (milestones.isEmpty) {
      milestones = [
        RewardGoalMilestone(id: 'ms_20', percent: 20, title: '20% milestone'),
        RewardGoalMilestone(id: 'ms_40', percent: 40, title: '40% milestone'),
        RewardGoalMilestone(id: 'ms_60', percent: 60, title: '60% milestone'),
        RewardGoalMilestone(id: 'ms_80', percent: 80, title: '80% milestone'),
        RewardGoalMilestone(id: 'ms_100', percent: 100, title: 'Goal achieved'),
      ];
    }
    await showDialog<RewardGoal>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(goal == null ? 'Add Goal' : 'Edit Goal'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    TextFormField(
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a goal name'
                                : null,
                        controller: nameController,
                        decoration: InputDecoration(labelText: 'Goal Name')),
                    TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration:
                            InputDecoration(labelText: 'Goal Description')),
                    TextFormField(
                        validator: (value) {
                          final number = int.tryParse(value ?? '');
                          return number == null || number < 1
                              ? 'Enter a whole amount of at least 1'
                              : null;
                        },
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: 'Target Amount (₹)'),
                        onChanged: (_) => setDialogState(() {})),
                    TextFormField(
                        validator: (value) {
                          final number = int.tryParse(value ?? '');
                          return number == null || number < 0
                              ? 'Enter a whole amount of at least 0'
                              : null;
                        },
                        controller: savedController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Current Saved Amount (₹)'),
                        onChanged: (_) => setDialogState(() {})),
                    Builder(builder: (_) {
                      final target =
                          int.tryParse(targetController.text.trim()) ?? 0;
                      final savedAmount =
                          int.tryParse(savedController.text.trim()) ?? 0;
                      final remaining = target <= 0
                          ? 0
                          : (target - savedAmount).clamp(0, target).toInt();
                      final progress = target <= 0
                          ? 0
                          : ((savedAmount / target).clamp(0, 1) * 100).round();
                      return Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            'Remaining: ${_formatRupees(remaining)} • Progress: $progress%',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      );
                    }),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(labelText: 'Goal Category'),
                      items: [
                        'Personal',
                        'Health',
                        'Career',
                        'Education',
                        'Finance',
                        'Travel',
                        'Lifestyle',
                        'Family',
                        'Other'
                      ]
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? category),
                    ),
                    TextFormField(
                        controller: startDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                            labelText: 'Start Date (YYYY-MM-DD)',
                            suffixIcon: Icon(Icons.calendar_today)),
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.tryParse(startDateController.text) ??
                                      DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null && context.mounted)
                            setDialogState(() => startDateController.text =
                                _formatIsoDate(picked));
                        }),
                    TextFormField(
                        controller: deadlineController,
                        readOnly: true,
                        decoration: InputDecoration(
                            labelText: 'Deadline (YYYY-MM-DD)',
                            suffixIcon: Icon(Icons.calendar_today)),
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.tryParse(deadlineController.text) ??
                                      DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null && context.mounted)
                            setDialogState(() => deadlineController.text =
                                _formatIsoDate(picked));
                        }),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: InputDecoration(labelText: 'Priority'),
                      items: ['Low', 'Medium', 'High', 'Critical']
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => priority = value ?? priority),
                    ),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(labelText: 'Status'),
                      items: [
                        RewardGoal.statusInProgress,
                        RewardGoal.statusAchieved,
                        RewardGoal.statusPaused,
                        RewardGoal.statusCancelled
                      ]
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
                    ),
                    SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('📷 Add Goal Images',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final path =
                                await _pickGoalImage(ImageSource.gallery);
                            if (path != null)
                              setDialogState(() => images = [
                                    ...images,
                                    RewardGoalImage(
                                        path: path, dateAdded: DateTime.now())
                                  ]);
                          },
                          icon: Icon(Icons.photo_library_outlined),
                          label: Text('Add from Gallery'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final path =
                                await _pickGoalImage(ImageSource.camera);
                            if (path != null)
                              setDialogState(() => images = [
                                    ...images,
                                    RewardGoalImage(
                                        path: path, dateAdded: DateTime.now())
                                  ]);
                          },
                          icon: Icon(Icons.photo_camera_outlined),
                          label: Text('Add from Camera'),
                        ),
                      ],
                    ),
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 132,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image = images[index];
                            return _GoalImageThumb(
                              image: image,
                              isCover: index == 0,
                              onMakeCover: index == 0
                                  ? null
                                  : () => setDialogState(() {
                                        final updated = [...images];
                                        final item = updated.removeAt(index);
                                        updated.insert(0, item);
                                        images = updated;
                                      }),
                              onDelete: () => setDialogState(() => images =
                                  images
                                      .where((item) => item.path != image.path)
                                      .toList()),
                              onMoveLeft: index == 0
                                  ? null
                                  : () => setDialogState(() {
                                        final updated = [...images];
                                        final item = updated.removeAt(index);
                                        updated.insert(index - 1, item);
                                        images = updated;
                                      }),
                              onMoveRight: index == images.length - 1
                                  ? null
                                  : () => setDialogState(() {
                                        final updated = [...images];
                                        final item = updated.removeAt(index);
                                        updated.insert(index + 1, item);
                                        images = updated;
                                      }),
                            );
                          },
                        ),
                      ),
                    SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Milestones',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    ...milestones.map((milestone) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              child: Text('${milestone.percent}%')),
                          title: Text(toTitleCase(milestone.title),
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(milestone.reward.isEmpty
                              ? 'Optional reward • ${milestone.bonusPoints} Points'
                              : '${milestone.reward} • ${milestone.bonusPoints} Points'),
                        )),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final start = DateTime.tryParse(startDateController.text);
                      final deadline =
                          DateTime.tryParse(deadlineController.text);
                      if (start != null &&
                          deadline != null &&
                          deadline.isBefore(start)) {
                        setDialogState(() => error =
                            'Deadline must be on or after the start date');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final target =
                          int.tryParse(targetController.text.trim()) ?? 0;
                      final savedAmount =
                          int.tryParse(savedController.text.trim()) ?? 0;
                      final result = RewardGoal(
                        id: goal?.id ??
                            'goal_${DateTime.now().microsecondsSinceEpoch}',
                        name: nameController.text.trim().isEmpty
                            ? 'Reward Goal'
                            : nameController.text.trim(),
                        description: descriptionController.text.trim(),
                        targetAmountRupees: target,
                        savedAmountRupees: savedAmount,
                        priority: priority,
                        deadline:
                            DateTime.tryParse(deadlineController.text.trim()),
                        imagePath: images.isEmpty ? '' : images.first.path,
                        images: images,
                        milestones: milestones,
                        startDate:
                            DateTime.tryParse(startDateController.text.trim()),
                        category: category,
                        status: target > 0 && savedAmount >= target
                            ? RewardGoal.statusAchieved
                            : status,
                        createdAt: goal?.createdAt ?? DateTime.now(),
                        history: goal?.history ?? [],
                      );
                      try {
                        await widget.hiveService.saveRewardGoal(result);
                        if (context.mounted) Navigator.pop(context, result);
                      } catch (_) {
                        if (context.mounted)
                          setDialogState(() {
                            saving = false;
                            error = 'Could not save. Please retry.';
                          });
                      }
                    },
              child: Text('Save Goal'),
            ),
          ],
        ),
      ),
    );
    // Keep dialog controllers alive until the route exit animation is fully done;
    // disposing immediately after showDialog can race with the closing rebuild.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final controller in [
      nameController,
      descriptionController,
      targetController,
      savedController,
      startDateController,
      deadlineController
    ]) {
      controller.dispose();
    }
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
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(toTitleCase(goal.name),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
            SizedBox(height: 8),
            Text(
                goal.description.isEmpty
                    ? 'No description yet.'
                    : goal.description,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(height: 14),
            if (goal.galleryImages.isNotEmpty) ...[
              Text('Image Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: goal.galleryImages.length,
                  separatorBuilder: (_, __) => SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final image = goal.galleryImages[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(File(image.path),
                          width: 190,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 190,
                              color: Theme.of(context).colorScheme.surface,
                              child: Icon(Icons.image_not_supported_outlined))),
                    );
                  },
                ),
              ),
              SizedBox(height: 14),
            ],
            Text('Financial Progress',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
                '${_formatRupees(goal.savedAmountRupees)} / ${_formatRupees(goal.targetAmountRupees)} • ${_formatRupees(goal.remainingAmountRupees)} remaining',
                style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            LinearProgressIndicator(value: goal.progress, minHeight: 12),
            SizedBox(height: 14),
            Text('Milestones', style: TextStyle(fontWeight: FontWeight.w600)),
            ...goal.milestones.map((milestone) => ListTile(
                leading: CircleAvatar(child: Text('${milestone.percent}%')),
                title: Text(toTitleCase(milestone.title)),
                subtitle: Text(
                    '${milestone.description}${milestone.reward.isEmpty ? '' : ' • Reward: ${milestone.reward}'}'))),
            SizedBox(height: 8),
            Text('Journey Timeline',
                style: TextStyle(fontWeight: FontWeight.w600)),
            ...goal.history.reversed.map((entry) => ListTile(
                leading: Icon(Icons.timeline),
                title: Text(toTitleCase(entry.title)),
                subtitle: Text(
                    '${_formatDate(entry.date)}${entry.note.isEmpty ? '' : ' • ${entry.note}'}'),
                trailing: entry.amountRupees == 0
                    ? null
                    : Text(_formatRupees(entry.amountRupees)))),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickGoalImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
          source: source, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
      return image?.path;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker: $error')));
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

  _GoalImageThumb(
      {required this.image,
      required this.isCover,
      this.onMakeCover,
      this.onDelete,
      this.onMoveLeft,
      this.onMoveRight});

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
                child: Image.file(File(image.path),
                    width: 120,
                    height: 82,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 82,
                        color: Theme.of(context).colorScheme.surface,
                        child: Icon(Icons.image_not_supported_outlined))),
              ),
              if (isCover)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('Cover',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600))),
                ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 0,
            runSpacing: 0,
            children: [
              _ThumbActionButton(
                  tooltip: 'Move left',
                  icon: Icons.chevron_left,
                  onPressed: onMoveLeft),
              _ThumbActionButton(
                  tooltip: 'Cover',
                  icon: Icons.star_border,
                  onPressed: onMakeCover),
              _ThumbActionButton(
                  tooltip: 'Move right',
                  icon: Icons.chevron_right,
                  onPressed: onMoveRight),
              _ThumbActionButton(
                  tooltip: 'Delete',
                  icon: Icons.delete_outline,
                  onPressed: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThumbActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  _ThumbActionButton(
      {required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: 28, height: 28),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 17),
      onPressed: onPressed,
    );
  }
}

class _GoalSummaryPanel extends StatelessWidget {
  final RewardMoneySummary summary;

  _GoalSummaryPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    final goals = summary.goals;
    final achieved = goals
        .where((goal) => goal.effectiveStatus == RewardGoal.statusAchieved)
        .length;
    final inProgress = goals
        .where((goal) => goal.effectiveStatus == RewardGoal.statusInProgress)
        .length;
    final totalTarget =
        goals.fold<int>(0, (sum, goal) => sum + goal.targetAmountRupees);
    final totalSaved =
        goals.fold<int>(0, (sum, goal) => sum + goal.savedAmountRupees);
    final stillNeeded =
        (totalTarget - totalSaved).clamp(0, totalTarget).toInt();
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎯 Goal Summary',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
          SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GoalStat(label: 'Total Goals', value: '${goals.length}'),
              _GoalStat(label: 'In Progress', value: '$inProgress'),
              _GoalStat(
                  label: 'Achieved',
                  value: '$achieved',
                  color: Colors.green.shade700),
              _GoalStat(
                  label: 'Total Target', value: _formatRupees(totalTarget)),
              _GoalStat(
                  label: 'Total Saved',
                  value: _formatRupees(totalSaved),
                  color: Theme.of(context).colorScheme.primary),
              _GoalStat(
                  label: 'Still Needed',
                  value: _formatRupees(stillNeeded),
                  color: Colors.deepOrange.shade700),
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

  _GoalStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color ?? Theme.of(context).colorScheme.onSurface)),
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

  _GoalCard(
      {required this.goal,
      required this.availableBalance,
      required this.onEdit,
      required this.onFund,
      required this.onView});

  @override
  Widget build(BuildContext context) {
    final achieved = goal.effectiveStatus == RewardGoal.statusAchieved;
    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 350),
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              achieved ? Colors.green.shade50 : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: achieved
                  ? Colors.green.shade300
                  : Theme.of(context).colorScheme.primary.withOpacity(0.14),
              width: achieved ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: achieved
                    ? Colors.green.withOpacity(0.22)
                    : Color(0x11000000),
                blurRadius: achieved ? 24 : 12,
                offset: Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: goal.coverImagePath.isEmpty
                      ? Container(
                          width: 72,
                          height: 72,
                          color: Theme.of(context).colorScheme.surface,
                          child: Icon(Icons.flag_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32))
                      : Image.file(File(goal.coverImagePath),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 72,
                              height: 72,
                              color: Theme.of(context).colorScheme.surface,
                              child: Icon(Icons.flag_outlined))),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(toTitleCase(goal.name),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface))),
                          _StatusPill(status: goal.effectiveStatus),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                          toTitleCaseMetadata(
                              [goal.category, '${goal.priority} Priority']),
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      if (goal.description.isNotEmpty)
                        Text(goal.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
                'Target: ${_formatRupees(goal.targetAmountRupees)} • Saved: ${_formatRupees(goal.savedAmountRupees)} • Still Needed: ${_formatRupees(goal.remainingAmountRupees)}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 10,
                  backgroundColor: Colors.black12,
                  color: achieved
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary),
            ),
            SizedBox(height: 6),
            Text(
                'Progress: ${(goal.progress * 100).round()}% • ${goal.deadline == null ? 'No deadline' : '${goal.deadline!.difference(DateTime.now()).inDays.clamp(0, 99999)} days remaining'} • ${goal.galleryImages.length} images • ${goal.milestones.length} milestones',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
            if (achieved) ...[
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(999)),
                child: Text('🎉 Goal Achieved • Badge Unlocked',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.green)),
              ),
            ],
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Edit'))),
                SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed:
                            availableBalance > 0 && !achieved ? onFund : null,
                        icon: Icon(Icons.add_card_outlined),
                        label: Text('Add Money'))),
              ],
            ),
            if (goal.history.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('Goal Journey Timeline',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
              SizedBox(height: 6),
              ...goal.history.reversed.take(3).map((entry) => Text(
                  '• ${_formatDate(entry.date)} — ${entry.title}${entry.note.isEmpty ? '' : ' (${entry.note})'}',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RewardGoal.statusAchieved => Colors.green,
      RewardGoal.statusPaused => Colors.orange,
      RewardGoal.statusCancelled => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(status,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _EmptyGoalsCard extends StatelessWidget {
  _EmptyGoalsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22)),
      child: Text(
          'No goals yet. Tap “Add Goal” to create your first offline reward goal.',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

String _formatIsoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${date.day} ${months[(date.month - 1).clamp(0, 11).toInt()]} ${date.year}';
}
