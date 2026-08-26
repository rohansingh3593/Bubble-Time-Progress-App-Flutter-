import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';
import '../models/instruction.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../services/log_reward_policy.dart';

class LogEarnView extends StatefulWidget {
  final HiveService hiveService;
  const LogEarnView({super.key, required this.hiveService});

  @override
  State<LogEarnView> createState() => _LogEarnViewState();
}

class _LogEarnViewState extends State<LogEarnView> {
  DateTime _selectedDate = DateTime.now();

  DateTime get _day => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  bool get _isFuture => _day.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.hiveService.getBoxListenable(),
      builder: (context, _) {
        final style = DashboardThemeStyle.of(widget.hiveService.getDashboardTheme(), palette: widget.hiveService.getDashboardPalette());
        final tasks = widget.hiveService.getTasksForDate(_day);
        final completed = tasks.where(_isCompleted).length;
        final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
        final lifetime = widget.hiveService.getLifetimeProductivityStats();
        final reward = widget.hiveService.getRewardMoneySummary();
        final snapshot = widget.hiveService.calculateProductivitySnapshotForDate(_day);
        final milestone = LogRewardPolicy.nextMilestone(lifetime.currentStreak);
        final milestoneProgress = (lifetime.currentStreak / milestone.qualifyingDays).clamp(0.0, 1.0);
        return Scaffold(
          backgroundColor: style.background,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      sliver: SliverList.list(children: [
                        _header(style),
                        const SizedBox(height: 20),
                        LayoutBuilder(builder: (context, constraints) {
                          final width = constraints.maxWidth < 620 ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 24) / 3;
                          return Wrap(spacing: 12, runSpacing: 12, children: [
                            _metric(style, width, Icons.monetization_on_rounded, 'Total Coins', '${reward.availableRupees}', style.accent),
                            _metric(style, width, Icons.local_fire_department_rounded, 'Current Streak', '${lifetime.currentStreak} ${lifetime.currentStreak == 1 ? 'Day' : 'Days'}', style.secondary),
                            _metric(style, width, Icons.trending_up_rounded, "Today's Progress", '${(progress * 100).round()}%', style.primary),
                          ]);
                        }),
                        const SizedBox(height: 16),
                        _rewardBanner(style, milestone, lifetime.currentStreak, milestoneProgress),
                        const SizedBox(height: 18),
                        _dateSelector(style),
                        const SizedBox(height: 22),
                        Row(children: [
                          Expanded(child: Text('All Tasks', style: TextStyle(color: style.textPrimary, fontSize: 22, fontWeight: FontWeight.w900))),
                          TextButton.icon(onPressed: _isFuture ? null : () => _selectAll(tasks), icon: const Icon(Icons.done_all_rounded), label: const Text('Select All')),
                        ]),
                        const SizedBox(height: 8),
                        if (tasks.isEmpty) _empty(style) else ...tasks.map((task) => _taskCard(style, task)),
                        const SizedBox(height: 16),
                        _bottomSummary(style, snapshot.totalPoints, completed, tasks.length),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(DashboardThemeStyle style) => Row(children: [
    IconButton(tooltip: 'Back', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
    Expanded(child: Text('Log & Earn', textAlign: TextAlign.center, style: TextStyle(color: style.textPrimary, fontSize: 26, fontWeight: FontWeight.w900))),
    IconButton(tooltip: 'Notifications', onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
  ]);

  Widget _metric(DashboardThemeStyle style, double width, IconData icon, String label, String value, Color color) => Container(
    width: width, constraints: const BoxConstraints(minWidth: 145, minHeight: 128), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 12), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)), const SizedBox(height: 6), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0), duration: const Duration(milliseconds: 550), builder: (_, number, __) => Text(value.contains('%') ? '${number.round()}%' : value.contains('Day') ? '${number.round()} ${number.round() == 1 ? 'Day' : 'Days'}' : '${number.round()}', style: TextStyle(color: style.textPrimary, fontSize: 25, fontWeight: FontWeight.w900)))]),
  );

  Widget _rewardBanner(DashboardThemeStyle style, LogRewardMilestone milestone, int days, double progress) => Container(
    padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: style.accent.withOpacity(.25))),
    child: Row(children: [CircleAvatar(backgroundColor: style.accent.withOpacity(.18), foregroundColor: style.accent, child: const Icon(Icons.card_giftcard_rounded)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Log for ${(milestone.qualifyingDays - days).clamp(0, milestone.qualifyingDays)} more ${milestone.qualifyingDays - days == 1 ? 'day' : 'days'} to earn ${milestone.coins} coins.', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)), const SizedBox(height: 12), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 650), builder: (_, value, __) => LinearProgressIndicator(value: value, minHeight: 8, borderRadius: BorderRadius.circular(99), color: style.accent)), const SizedBox(height: 8), Text('$days / ${milestone.qualifyingDays} qualifying days', style: TextStyle(color: style.textMuted))]))]),
  );

  Widget _dateSelector(DashboardThemeStyle style) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(16)), child: Row(children: [IconButton(tooltip: 'Previous day', onPressed: () => setState(() => _selectedDate = _day.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left_rounded)), Expanded(child: InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_month_rounded, color: style.primary), const SizedBox(width: 8), Flexible(child: Text(_dateLabel(), overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)))]))), IconButton(tooltip: 'Next day', onPressed: () => setState(() => _selectedDate = _day.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right_rounded)), if (!_sameDay(_day, DateTime.now())) TextButton(onPressed: () => setState(() => _selectedDate = DateTime.now()), child: const Text('Today'))]));

  Widget _taskCard(DashboardThemeStyle style, Task task) {
    final complete = _isCompleted(task); final disabled = !task.routineEnabled || task.status.toLowerCase().contains('cancel'); final missed = task.status.toLowerCase().contains('miss') || task.status.toLowerCase().contains('overdue');
    final stateColor = complete
        ? (style.success ?? style.primary)
        : missed
            ? (style.danger ?? style.secondary)
            : disabled
                ? style.textMuted
                : (style.warning ?? style.accent);
    final instructions = _linkedInstructions(task);
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Material(color: complete ? stateColor.withOpacity(.10) : (style.cardTint ?? style.surface), borderRadius: BorderRadius.circular(16), child: InkWell(onTap: () => _showDetails(task, instructions), borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      CircleAvatar(backgroundColor: stateColor.withOpacity(.14), foregroundColor: stateColor, child: Icon(_categoryIcon(task.category))), const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.task, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 5), Wrap(spacing: 12, runSpacing: 4, children: [if (task.hourSlot != null) _meta(style, Icons.schedule_rounded, _hour(task.hourSlot!)), if (task.estimatedMinutes > 0) _meta(style, Icons.timelapse_rounded, '${task.estimatedMinutes} min'), _meta(style, Icons.repeat_rounded, task.repeatTask ? (task.repeatFrequency ?? 'Daily') : 'One time'), if (instructions.isNotEmpty) _meta(style, Icons.rule_rounded, '${instructions.length} instruction${instructions.length == 1 ? '' : 's'}')])])),
      const SizedBox(width: 8), if (complete) Text('+${_taskEarned(task)}', style: TextStyle(color: style.accent, fontWeight: FontWeight.w900)), Checkbox(value: complete, onChanged: disabled || _isFuture || widget.hiveService.isDailyJournalTask(task) ? null : (_) => _complete(task, instructions), activeColor: style.success ?? style.primary),
    ])))));
  }

  Widget _meta(DashboardThemeStyle style, IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: style.textMuted), const SizedBox(width: 4), Text(text, style: TextStyle(color: style.textMuted, fontSize: 12))]);
  Widget _empty(DashboardThemeStyle style) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No tasks scheduled for this date.', style: TextStyle(color: style.textMuted))));
  Widget _bottomSummary(DashboardThemeStyle style, int points, int completed, int total) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(18)), child: Row(children: [Expanded(child: _summaryValue(style, "Day's Total Earned", '🪙 +$points')), Container(width: 1, height: 42, color: style.textMuted.withOpacity(.2)), Expanded(child: _summaryValue(style, 'Tasks Completed', '$completed / $total'))]));
  Widget _summaryValue(DashboardThemeStyle style, String label, String value) => Column(children: [Text(label, style: TextStyle(color: style.textMuted)), const SizedBox(height: 5), Text(value, style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900))]);

  Future<void> _complete(Task task, List<InstructionRule> instructions) async {
    if (_isCompleted(task)) { await widget.hiveService.updateTaskByReference(task, task.copyWith(done: false, status: 'In Progress')); return; }
    if (instructions.isNotEmpty && !await _reviewInstructions(task, instructions)) return;
    await widget.hiveService.updateTaskByReference(task, task.copyWith(done: true, status: 'Completed', dueDate: DateTime.now()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ Completed  •  +${_taskEarned(task)} coins'), duration: const Duration(seconds: 2)));
  }

  Future<bool> _reviewInstructions(Task task, List<InstructionRule> rules) async {
    final selected = <String, Set<InstructionOption>>{};
    return await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: Text(task.task), content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const Text('Select everything followed:', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 10), ...rules.expand((rule) => [Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w700)), if (rule.options.isEmpty) CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Instruction followed'), value: selected[rule.id]?.isNotEmpty ?? false, onChanged: (v) => setDialogState(() => selected[rule.id] = v == true ? {const InstructionOption(id: '__followed__', name: 'Followed', bonusPoints: 0, pointsEarned: 0)} : {})) else ...rule.options.map((option) => CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(option.displayLabel), subtitle: Text('+${option.bonusPoints + option.pointsEarned}'), value: selected[rule.id]?.contains(option) ?? false, onChanged: (v) => setDialogState(() { final values = selected.putIfAbsent(rule.id, () => {}); v == true ? values.add(option) : values.remove(option); })))] )]))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () async { for (final rule in rules) { final values = selected[rule.id] ?? {}; await widget.hiveService.updateInstructionStatus(rule, _day, values.isEmpty ? InstructionHistoryEntry.statusMissed : InstructionHistoryEntry.statusFollowed, options: values.where((o) => o.id != '__followed__').toList()); } if (context.mounted) Navigator.pop(context, true); }, child: const Text('Save & Finish'))])))) ?? false;
  }

  Future<void> _selectAll(List<Task> tasks) async { for (final task in tasks.where((t) => !_isCompleted(t) && t.routineEnabled && !widget.hiveService.isDailyJournalTask(t))) { await _complete(task, _linkedInstructions(task)); } }
  List<InstructionRule> _linkedInstructions(Task task) => widget.hiveService.getTaskLinkedInstructions().where((i) => i.enabled && i.isLinkedToTask(task.task)).toList();
  void _showDetails(Task task, List<InstructionRule> instructions) { final snapshot = widget.hiveService.calculateProductivitySnapshotForDate(_day); showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(task.task), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_isCompleted(task) ? '✓ Completed' : task.status), const SizedBox(height: 12), Text('Category: ${task.category}'), Text('Scheduled: ${task.hourSlot == null ? 'Not scheduled' : _hour(task.hourSlot!)}'), Text('Duration: ${task.estimatedMinutes} minutes'), Text('Frequency: ${task.repeatTask ? task.repeatFrequency ?? 'Daily' : 'One time'}'), Text('Instructions: ${instructions.length}'), if (_isCompleted(task)) ...[Text('Completed at: ${_hour(task.dueDate.hour)}'), Text('Total day earned: +${snapshot.totalPoints}')], if (task.description.trim().isNotEmpty) ...[const SizedBox(height: 10), Text(task.description)]])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])); }
  Future<void> _pickDate() async { final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 3650))); if (picked != null) setState(() => _selectedDate = picked); }
  bool _isCompleted(Task task) => task.done || task.status.toLowerCase() == 'completed';
  int _taskEarned(Task task) {
    final events = widget.hiveService.calculateProductivitySnapshotForDate(_day).pointEvents;
    final normalized = task.task.trim().toLowerCase();
    return events
        .where((event) => event.title.trim().toLowerCase().startsWith(normalized))
        .fold<int>(0, (total, event) => total + event.totalPoints);
  }
  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _dateLabel() { const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; return '${_sameDay(_day, DateTime.now()) ? 'Today, ' : ''}${_day.day} ${months[_day.month - 1]} ${_day.year}'; }
  String _hour(int hour) { final h = hour % 12 == 0 ? 12 : hour % 12; return '$h:00 ${hour < 12 ? 'AM' : 'PM'}'; }
  IconData _categoryIcon(String category) { switch (category.toLowerCase()) { case 'health': return Icons.favorite_rounded; case 'work': return Icons.work_rounded; case 'study': return Icons.menu_book_rounded; case 'finance': return Icons.savings_rounded; case 'journal': return Icons.auto_stories_rounded; default: return Icons.checklist_rounded; } }
}
