import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';
import '../models/instruction.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../services/log_reward_policy.dart';
import '../widgets/task_completion.dart';

class LogEarnView extends StatefulWidget {
  final HiveService hiveService;
  const LogEarnView({super.key, required this.hiveService});

  @override
  State<LogEarnView> createState() => _LogEarnViewState();
}

class _LogEarnViewState extends State<LogEarnView> {
  static const _filters = <String>[
    'All',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'Non-Routine',
    'Completed',
    'Pending',
  ];

  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'All';
  final Set<String> _selectedIds = {};
  final ScrollController _filterScrollController = ScrollController();
  bool _busy = false;

  DateTime get _day =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  bool get _isFuture => _day.isAfter(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  @override
  void dispose() {
    _filterScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.hiveService.getBoxListenable(),
      builder: (context, _) {
        final style = DashboardThemeStyle.of(
            widget.hiveService.getDashboardTheme(),
            palette: widget.hiveService.getDashboardPalette());
        final eligibleTasks =
            widget.hiveService.getMasterTaskOccurrencesForDate(_day);
        final tasks = eligibleTasks.where(_matchesFilter).toList();
        final completed = eligibleTasks.where(_isCompleted).length;
        final progress =
            eligibleTasks.isEmpty ? 0.0 : completed / eligibleTasks.length;
        final lifetime = widget.hiveService.getLifetimeProductivityStats();
        final reward = widget.hiveService.getRewardMoneySummary();
        final snapshot =
            widget.hiveService.calculateProductivitySnapshotForDate(_day);
        final milestone = LogRewardPolicy.nextMilestone(lifetime.currentStreak);
        final milestoneProgress =
            (lifetime.currentStreak / milestone.qualifyingDays)
                .clamp(0.0, 1.0)
                .toDouble();
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
                        _dateSelector(style),
                        const SizedBox(height: 22),
                        Row(children: [
                          Expanded(
                              child: Text('All Tasks',
                                  style: TextStyle(
                                      color: style.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900))),
                          TextButton.icon(
                              onPressed: _isFuture || _busy
                                  ? null
                                  : () => _selectAll(tasks),
                              icon: const Icon(Icons.done_all_rounded),
                              label: const Text('Select All')),
                        ]),
                        if (_selectedIds.isNotEmpty)
                          Wrap(spacing: 8, children: [
                            FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _completeSelected(tasks),
                                child: Text(
                                    'Complete selected (${_selectedIds.length})')),
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(_selectedIds.clear),
                                child: const Text('Clear selection')),
                          ]),
                        _filterBar(style),
                        const SizedBox(height: 8),
                        if (tasks.isEmpty)
                          _empty(style)
                        else
                          ..._taskList(style, tasks),
                        const SizedBox(height: 16),
                        ExpansionTile(
                            title: const Text('Rewards and streak'),
                            children: [
                              LayoutBuilder(builder: (context, constraints) {
                                final width = constraints.maxWidth < 620
                                    ? (constraints.maxWidth - 12) / 2
                                    : (constraints.maxWidth - 24) / 3;
                                return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _metric(
                                          style,
                                          width,
                                          Icons.monetization_on_rounded,
                                          'Reward budget (INR)',
                                          '${reward.availableRupees}',
                                          style.accent),
                                      _metric(
                                          style,
                                          width,
                                          Icons.local_fire_department_rounded,
                                          'Current Streak',
                                          '${lifetime.currentStreak} ${lifetime.currentStreak == 1 ? 'Day' : 'Days'}',
                                          style.secondary),
                                      _metric(
                                          style,
                                          width,
                                          Icons.trending_up_rounded,
                                          "Today's Progress",
                                          '${(progress * 100).round()}%',
                                          style.primary),
                                    ]);
                              }),
                              const SizedBox(height: 16),
                              _rewardBanner(style, milestone,
                                  lifetime.currentStreak, milestoneProgress),
                              const SizedBox(height: 18),
                            ]),
                        _bottomSummary(
                          style,
                          snapshot.totalPoints,
                          completed,
                          eligibleTasks.length,
                        ),
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

  Widget _filterBar(DashboardThemeStyle style) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Log and Earn filters',
      hint: 'Scroll horizontally to see all filters',
      child: Scrollbar(
        controller: _filterScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _filterScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: _filters.map((filter) {
              final selected = filter == _selectedFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: selected,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() {
                            _selectedFilter = filter;
                            _selectedIds.clear();
                          }),
                  selectedColor: style.primary.withOpacity(.18),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(Task task) {
    final frequency = (task.repeatFrequency ?? 'Daily').trim().toLowerCase();
    switch (_selectedFilter) {
      case 'Daily':
      case 'Weekly':
      case 'Monthly':
      case 'Yearly':
        return task.repeatTask && frequency == _selectedFilter.toLowerCase();
      case 'Non-Routine':
        return !task.repeatTask;
      case 'Completed':
        return _isCompleted(task);
      case 'Pending':
        return !_isCompleted(task) && task.routineEnabled;
      default:
        return task.routineEnabled || !task.repeatTask;
    }
  }

  List<Widget> _taskList(DashboardThemeStyle style, List<Task> tasks) {
    if (_selectedFilter != 'All') {
      return tasks.map((task) => _taskCard(style, task)).toList();
    }
    const types = <String>[
      'Daily',
      'Weekly',
      'Monthly',
      'Yearly',
      'Non-Routine',
    ];
    final widgets = <Widget>[];
    for (final type in types) {
      final group = tasks.where((task) => _taskType(task) == type).toList();
      if (group.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
          child: Text(
            '$type Tasks',
            style: TextStyle(
              color: style.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
      widgets.addAll(group.map((task) => _taskCard(style, task)));
    }
    return widgets;
  }

  String _taskType(Task task) {
    if (!task.repeatTask) return 'Non-Routine';
    switch (task.repeatFrequency?.trim().toLowerCase()) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return 'Daily';
    }
  }

  Widget _header(DashboardThemeStyle style) => Row(children: [
        IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded)),
        Expanded(
            child: Text('Log & Earn',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: style.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900))),
        const SizedBox(width: 48),
      ]);

  Widget _metric(DashboardThemeStyle style, double width, IconData icon,
          String label, String value, Color color) =>
      Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 100),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: style.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: style.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
              tween: Tween(
                  begin: 0,
                  end: double.tryParse(
                          value.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                      0),
              duration: const Duration(milliseconds: 550),
              builder: (_, number, __) => Text(
                  value.contains('%')
                      ? '${number.round()}%'
                      : value.contains('Day')
                          ? '${number.round()} ${number.round() == 1 ? 'Day' : 'Days'}'
                          : '${number.round()}',
                  style: TextStyle(
                      color: style.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w900)))
        ]),
      );

  Widget _rewardBanner(DashboardThemeStyle style, LogRewardMilestone milestone,
          int days, double progress) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: style.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: style.accent.withOpacity(.25))),
        child: Row(children: [
          CircleAvatar(
              backgroundColor: style.accent.withOpacity(.18),
              foregroundColor: style.accent,
              child: const Icon(Icons.card_giftcard_rounded)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    'Log for ${(milestone.qualifyingDays - days).clamp(0, milestone.qualifyingDays)} more ${milestone.qualifyingDays - days == 1 ? 'day' : 'days'} to earn ${milestone.coins} coins.',
                    style: TextStyle(
                        color: style.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 650),
                    builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(99),
                        color: style.accent)),
                const SizedBox(height: 8),
                Text('$days / ${milestone.qualifyingDays} qualifying days',
                    style: TextStyle(color: style.textMuted))
              ]))
        ]),
      );

  Widget _dateSelector(DashboardThemeStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: () => setState(
              () {
                if (!_busy) {
                  _selectedDate = _day.subtract(const Duration(days: 1));
                  _selectedIds.clear();
                }
              },
            ),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              onTap: _busy ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, color: style.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _dateLabel(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: style.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: () => setState(
              () {
                if (!_busy) {
                  _selectedDate = _day.add(const Duration(days: 1));
                  _selectedIds.clear();
                }
              },
            ),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          if (!_sameDay(_day, DateTime.now()))
            TextButton(
              onPressed: () => setState(() => _selectedDate = DateTime.now()),
              child: const Text('Today'),
            ),
        ],
      ),
    );
  }

  Widget _taskCard(DashboardThemeStyle style, Task task) {
    final selecting = _selectedIds.isNotEmpty;
    final complete = _isCompleted(task);
    final enabled = !_busy &&
        !_isFuture &&
        (!task.repeatTask || task.routineEnabled) &&
        task.status != 'Cancelled';
    return Card(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Checkbox(
                  value: selecting ? _selectedIds.contains(task.id) : complete,
                  semanticLabel:
                      '${selecting ? 'Select' : 'Complete'} ${task.task}',
                  onChanged: !enabled || (selecting && !_selectable(task))
                      ? null
                      : (value) {
                          if (selecting) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(task.id);
                              } else {
                                _selectedIds.remove(task.id);
                              }
                            });
                          } else {
                            _complete(task, _linkedInstructions(task));
                          }
                        }),
              Expanded(
                  child: InkWell(
                      onTap: () =>
                          _showDetails(task, _linkedInstructions(task)),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.task,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        decoration: complete
                                            ? TextDecoration.lineThrough
                                            : null)),
                                Text(
                                    '${_occurrenceLabel(task)}${_scheduleLabel(task) == null ? '' : ' ? ${_scheduleLabel(task)}'}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ])))),
              IconButton(
                  tooltip: 'Task details',
                  onPressed: () =>
                      _showDetails(task, _linkedInstructions(task)),
                  icon: const Icon(Icons.more_horiz)),
            ])));
  }

  Widget _meta(DashboardThemeStyle style, IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: style.textMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: style.textMuted, fontSize: 12))
      ]);
  Widget _empty(DashboardThemeStyle style) => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
          child: Text('No tasks scheduled for this date.',
              style: TextStyle(color: style.textMuted))));
  Widget _bottomSummary(
          DashboardThemeStyle style, int points, int completed, int total) =>
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: style.surface, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Expanded(
                child:
                    _summaryValue(style, "Day's Total Earned", '🪙 +$points')),
            Container(
                width: 1, height: 42, color: style.textMuted.withOpacity(.2)),
            Expanded(
                child: _summaryValue(
                    style, 'Tasks Completed', '$completed / $total'))
          ]));
  Widget _summaryValue(DashboardThemeStyle style, String label, String value) =>
      Column(children: [
        Text(label, style: TextStyle(color: style.textMuted)),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
                color: style.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900))
      ]);

  Future<void> _complete(Task task, List<InstructionRule> instructions) async {
    if (_busy) return;
    setState(() => _busy = true);
    await changeTaskCompletion(
        context, widget.hiveService, task, _day, !_isCompleted(task));
    if (mounted) setState(() => _busy = false);
  }

  bool _selectable(Task task) =>
      !_isCompleted(task) &&
      (!task.repeatTask || task.routineEnabled) &&
      task.status != 'Cancelled' &&
      !widget.hiveService.isDailyJournalTask(task);

  void _selectAll(List<Task> tasks) => setState(() {
        _selectedIds.clear();
        _selectedIds.addAll(tasks.where(_selectable).map((t) => t.id));
      });

  Future<void> _completeSelected(List<Task> tasks) async {
    if (_busy || _isFuture) return;
    final selected = tasks
        .where((t) => _selectedIds.contains(t.id) && _selectable(t))
        .toList();
    final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text('Complete ${selected.length} tasks?'),
              content: const Text(
                  'This updates completion and rewards for the selected date. Tasks with instructions will be reviewed individually. Cancelling a review stops the batch; earlier completions are kept.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Complete selected'))
              ],
            ));
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    var completed = 0;
    for (final task in selected) {
      if (!mounted) break;
      if (!await changeTaskCompletion(
          context, widget.hiveService, task, _day, true)) break;
      _selectedIds.remove(task.id);
      completed++;
    }
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$completed of ${selected.length} selected tasks completed')));
    }
  }

  List<InstructionRule> _linkedInstructions(Task task) => widget.hiveService
      .getTaskLinkedInstructions()
      .where((i) => i.enabled && i.isLinkedToTask(task.task))
      .toList();
  void _showDetails(Task task, List<InstructionRule> instructions) {
    final snapshot =
        widget.hiveService.calculateProductivitySnapshotForDate(_day);
    final taskEvents = snapshot.pointEvents.where(
      (event) => event.title
          .trim()
          .toLowerCase()
          .startsWith(task.task.trim().toLowerCase()),
    );
    final taskPoints = taskEvents.fold<int>(
      0,
      (total, event) => total + event.basePoints,
    );
    final timingBonus = taskEvents.fold<int>(
      0,
      (total, event) => total + event.timingBonusPoints,
    );
    final streakBonus = taskEvents.fold<int>(
      0,
      (total, event) => total + event.streakBonusPoints,
    );
    var followed = 0;
    var instructionOptions = 0;
    var instructionBonus = 0;
    for (final instruction in instructions) {
      final entry =
          widget.hiveService.instructionEntryForDate(instruction, _day);
      instructionOptions += instruction.options.length;
      if (entry != null && entry.followed) {
        followed += entry.selectedOptionCount;
        instructionBonus += entry.bonusPoints;
      }
    }
    final total = taskPoints + timingBonus + streakBonus + instructionBonus;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(task.task),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isCompleted(task) ? '✓ Completed' : task.status),
              const SizedBox(height: 12),
              Text('Category: ${task.category}'),
              Text('Priority: ${task.priority}'),
              Text('Scheduled: ${_scheduleLabel(task) ?? 'Not scheduled'}'),
              Text('Duration: ${task.estimatedMinutes} minutes'),
              Text(
                'Frequency: ${task.repeatTask ? task.repeatFrequency ?? 'Daily' : 'Non-Routine'}',
              ),
              Text('Instructions: ${instructions.length}'),
              if (_isCompleted(task)) ...[
                const SizedBox(height: 12),
                Text('Completed at: ${_completionTime(task)}'),
                Text('Instructions followed: $followed / $instructionOptions'),
                Text('Task points: +$taskPoints'),
                Text('Instruction bonus: +$instructionBonus'),
                Text('Timing bonus: +$timingBonus'),
                Text('Streak bonus: +$streakBonus'),
                Text(
                  'Total reward: +$total',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
              if (task.description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(task.description),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _day,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (picked != null && mounted)
      setState(() {
        _selectedDate = picked;
        _selectedIds.clear();
      });
  }

  bool _isCompleted(Task task) =>
      task.done || task.status.toLowerCase() == 'completed';
  int _taskEarned(Task task) {
    final events = widget.hiveService
        .calculateProductivitySnapshotForDate(_day)
        .pointEvents;
    final normalized = task.task.trim().toLowerCase();
    return events
        .where(
            (event) => event.title.trim().toLowerCase().startsWith(normalized))
        .fold<int>(0, (total, event) => total + event.totalPoints);
  }

  String? _scheduleLabel(Task task) {
    if (task.hourSlot == null) return null;
    final startMinutes = task.hourSlot! * 60;
    final endMinutes = startMinutes + task.estimatedMinutes;
    return '${_minutesTime(startMinutes)} - ${_minutesTime(endMinutes)}';
  }

  String _occurrenceLabel(Task task) {
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
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
      'Dec',
    ];
    switch (_taskType(task)) {
      case 'Weekly':
        return weekdays[_day.weekday - 1];
      case 'Monthly':
        return 'Day ${_day.day}';
      case 'Yearly':
        return '${_day.day} ${months[_day.month - 1]}';
      case 'Non-Routine':
        final due = DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
        );
        return due.isBefore(_day) && !_isCompleted(task)
            ? 'Overdue'
            : 'Due this day';
      default:
        return 'Daily';
    }
  }

  String _completionTime(Task task) {
    final hour = task.dueDate.hour;
    final minute = task.dueDate.minute;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }

  String _minutesTime(int totalMinutes) {
    final normalized = totalMinutes % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _dateLabel() {
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
    return '${_sameDay(_day, DateTime.now()) ? 'Today, ' : ''}${_day.day} ${months[_day.month - 1]} ${_day.year}';
  }

  String _hour(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:00 ${hour < 12 ? 'AM' : 'PM'}';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'health':
        return Icons.favorite_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'study':
        return Icons.menu_book_rounded;
      case 'finance':
        return Icons.savings_rounded;
      case 'journal':
        return Icons.auto_stories_rounded;
      default:
        return Icons.checklist_rounded;
    }
  }
}
