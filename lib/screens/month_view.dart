import 'package:flutter/material.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/productivity_period_summary.dart';
import '../widgets/period_progress_bubble_map.dart';
import '../widgets/period_task_agenda.dart';
import '../services/hive_service.dart';
import '../constants/dashboard_themes.dart';
import '../models/task_model.dart';
import '../models/productivity_snapshot.dart';
import 'journal_view.dart';
import 'day_view.dart';
import '../utils/text_formatters.dart';

class MonthView extends StatefulWidget {
  final HiveService hiveService;
  final DateTime? initialDate;
  final ValueChanged<DateTime>? onDateChanged;
  final ValueChanged<DateTime>? onOpenDate;
  final bool showPeriodControls;

  const MonthView(
      {super.key,
      required this.hiveService,
      this.initialDate,
      this.onDateChanged,
      this.onOpenDate,
      this.showPeriodControls = true});

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _currentMonth;
  final ScrollController _monthSelectorController = ScrollController();
  bool _showMonthlyTasks = true;

  @override
  void didUpdateWidget(covariant MonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != null &&
        widget.initialDate != oldWidget.initialDate) {
      _currentMonth = widget.initialDate!;
      _centerSelectedMonthAfterLayout();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialDate ?? DateTime.now();
    _centerSelectedMonthAfterLayout();
  }

  @override
  void dispose() {
    _monthSelectorController.dispose();
    super.dispose();
  }

  void _centerSelectedMonthAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_monthSelectorController.hasClients) return;
      final target = ((_currentMonth.month - 1) * 92.0) -
          (MediaQuery.of(context).size.width / 2) +
          70;
      _monthSelectorController.animateTo(
        target.clamp(0.0, _monthSelectorController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _selectMonth(int month) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, month);
    });
    widget.onDateChanged?.call(_currentMonth);
    _centerSelectedMonthAfterLayout();
  }

  void _changeSelectorYear(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year + delta, _currentMonth.month);
    });
    widget.onDateChanged?.call(_currentMonth);
    _centerSelectedMonthAfterLayout();
  }

  void _openJournalForTask(Task task) {
    Navigator.of(context).push(
      JournalView.route(
          hiveService: widget.hiveService, initialDate: task.dueDate),
    );
  }

  void _openAgendaDate(DateTime date) {
    if (widget.onOpenDate != null) {
      widget.onOpenDate!(date);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          DayView(hiveService: widget.hiveService, initialDate: date),
    ));
  }

  Future<void> _editTask(Task task) async {
    if (isRoutineTask(task) ||
        hasTaskLinkedInstructions(widget.hiveService, task)) {
      final action = await showRoutineOccurrenceDialog(
          context: context, task: task, hiveService: widget.hiveService);
      if (action == null || action == RoutineOccurrenceAction.close) return;

      switch (action) {
        case RoutineOccurrenceAction.openJournal:
          _openJournalForTask(task);
          return;
        case RoutineOccurrenceAction.disableRoutine:
          await widget.hiveService
              .setRecurringTaskEnabledByReference(task, false);
          return;
        case RoutineOccurrenceAction.editDetails:
          await showTaskFormDialog(
            context,
            date: task.dueDate,
            initialTask: task,
            title: isRoutineTask(task)
                ? 'Edit Routine Details'
                : 'View Task Details',
            actionLabel: isRoutineTask(task) ? 'Save Routine' : 'Save Task',
            onSave: (edited) =>
                widget.hiveService.saveTaskChanges(task, edited),
          );
          return;
        case RoutineOccurrenceAction.missOccurrence:
          await widget.hiveService.updateTaskByReference(
              task, task.copyWith(done: false, status: 'Missed'));
          return;
        case RoutineOccurrenceAction.completeOccurrence:
          await widget.hiveService.updateTaskByReference(
              task, task.copyWith(done: true, status: 'Completed'));
          return;
        case RoutineOccurrenceAction.close:
          return;
      }
    }

    await showTaskFormDialog(
      context,
      date: task.dueDate,
      initialTask: task,
      title: 'Update Task',
      actionLabel: 'Save Task',
      onSave: (updated) => widget.hiveService.saveTaskChanges(task, updated),
      onRestore: () => widget.hiveService.addTask(task.dueDate, task),
      onDelete: () => widget.hiveService.deleteTaskByReference(task),
    );
  }

  List<DateTime> _daysInCurrentMonth() {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    return List.generate(
        daysInMonth,
        (index) =>
            DateTime(_currentMonth.year, _currentMonth.month, index + 1));
  }

  bool _isCompletedTask(Task task) {
    return task.done || task.status.trim().toLowerCase() == 'completed';
  }

  PeriodProductivityStats _monthlyProductivityStats() {
    final days = _daysInCurrentMonth();
    final snapshots = days
        .map((date) =>
            widget.hiveService.calculateProductivitySnapshotForDate(date))
        .toList();
    final monthTasks = days
        .expand((date) => widget.hiveService.getTasksForDate(date))
        .toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedTasks = monthTasks.where(_isCompletedTask).length;
    final pendingTasks = monthTasks
        .where((task) => !_isCompletedTask(task) && task.status != 'Cancelled')
        .length;
    final overdueTasks = monthTasks.where((task) {
      final due =
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return due.isBefore(today) &&
          !_isCompletedTask(task) &&
          task.status != 'Cancelled';
    }).length;

    return PeriodProductivityStats(
      title: '📅 Monthly Productivity',
      periodLabel:
          '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
      snapshots: snapshots,
      maximumPoints: days.length * ProductivitySnapshot.maximumPoints.round(),
      totalDays: days.length,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      overdueTasks: overdueTasks,
      intervals: _monthlyWeekIntervals(days, snapshots),
    );
  }

  List<ProductivityIntervalSummary> _monthlyWeekIntervals(
      List<DateTime> days, List<ProductivitySnapshot> snapshots) {
    final intervals = <ProductivityIntervalSummary>[];
    for (var start = 0; start < days.length; start += 7) {
      final end = (start + 7).clamp(0, days.length).toInt();
      final weekSnapshots = snapshots.sublist(start, end);
      final points = weekSnapshots.fold<int>(
          0, (sum, snapshot) => sum + snapshot.totalPoints);
      final maxPoints =
          weekSnapshots.length * ProductivitySnapshot.maximumPoints;
      intervals.add(ProductivityIntervalSummary(
        label: 'Week ${intervals.length + 1}',
        points: points,
        score: maxPoints == 0
            ? 0
            : (points / maxPoints * 100).clamp(0.0, 100.0).toDouble(),
      ));
    }
    return intervals;
  }

  int _getDaysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  List<Task> _getMonthlyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    return allTasksByDate.values.expand((tasks) => tasks).where((task) {
      final dueDate =
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return task.repeatTask &&
          task.repeatFrequency == 'Monthly' &&
          !dueDate.isBefore(monthStart) &&
          !dueDate.isAfter(monthEnd);
    }).toList();
  }

  Widget _monthlyTasksPanel(List<Task> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showMonthlyTasks = !_showMonthlyTasks),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Monthly routines",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                      _showMonthlyTasks
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ),
          if (_showMonthlyTasks)
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text('No monthly routines for this period.'),
              )
            else
              ...tasks.map((task) => ListTile(
                    dense: true,
                    onTap: () => _editTask(task),
                    title: Text(toTitleCase(task.task)),
                    subtitle: Text('${task.priority} • ${task.status}'),
                  )),
        ],
      ),
    );
  }

  Widget _monthBubbleSelector() {
    const monthLabels = [
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 7))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous year',
                  onPressed: () => _changeSelectorYear(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${_currentMonth.year}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: colorScheme.onSurface)),
                IconButton(
                  tooltip: 'Next year',
                  onPressed: () => _changeSelectorYear(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            controller: _monthSelectorController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(12, (index) {
                final month = index + 1;
                final selected = month == _currentMonth.month;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _PeriodSelectorPill(
                    label: monthLabels[index],
                    selected: selected,
                    onTap: () => _selectMonth(month),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  DashboardThemeStyle _selectedDashboardTheme() {
    return DashboardThemeStyle.of(
      widget.hiveService.getDashboardTheme(),
      palette: widget.hiveService.getDashboardPalette(),
    );
  }

  Widget _monthDayProgressMap(DashboardThemeStyle theme, DateTime now) {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;
    final isPastMonth = monthStart.isBefore(currentMonthStart);
    final isFutureMonth = monthStart.isAfter(currentMonthStart);
    final passedDays = isPastMonth
        ? daysInMonth
        : isFutureMonth
            ? 0
            : (now.day - 1).clamp(0, daysInMonth).toInt();
    final remainingDays = isPastMonth
        ? 0
        : isFutureMonth
            ? daysInMonth
            : (daysInMonth - passedDays - 1).clamp(0, daysInMonth).toInt();
    final displayDays = ((daysInMonth + 6) ~/ 7) * 7;
    return PeriodProgressBubbleMap(
      theme: theme,
      title: 'Month Day Progress',
      subtitle: '$passedDays days passed • $remainingDays days left',
      totalItems: daysInMonth,
      displayItemCount: displayDays,
      minBubbleSize: 30,
      maxBubbleSize: 38,
      passedItems: passedDays,
      currentIndex: isCurrentMonth ? now.day - 1 : null,
      itemsPerRow: 7,
      tooltipBuilder: (index) =>
          '${index + 1}/${_currentMonth.month}/${_currentMonth.year}',
      bubbleLabelBuilder: (index) => '${index + 1}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showPeriodControls
            ? '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}'
            : 'Month'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final monthlyTasks = _getMonthlyRepeatingTasks();
          final monthlyStats = _monthlyProductivityStats();
          final selectedDashboardTheme = _selectedDashboardTheme();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isCurrentMonth)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await showQuickAddTaskDialog(
                        context,
                        DateTime(now.year, now.month, now.day),
                        widget.hiveService,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add task'),
                  ),
                ),
              const SizedBox(height: 12),
              if (widget.showPeriodControls) ...[
                _monthBubbleSelector(),
                const SizedBox(height: 16),
              ],
              PeriodTaskAgenda(
                hiveService: widget.hiveService,
                dates: List.generate(
                  _getDaysInMonth(_currentMonth),
                  (index) => DateTime(
                      _currentMonth.year, _currentMonth.month, index + 1),
                ),
                onOpenDate: _openAgendaDate,
              ),
              const SizedBox(height: 12),
              _monthlyTasksPanel(monthlyTasks),
              const SizedBox(height: 16),
              _monthDayProgressMap(selectedDashboardTheme, now),
              const SizedBox(height: 16),
              ExpansionTile(title: const Text('Month summary'), children: [
                ProductivityPeriodSummaryCard(stats: monthlyStats)
              ]),
            ],
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}

class _PeriodSelectorPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodSelectorPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      scale: selected ? 1.08 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? colorScheme.primary : colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: selected ? 1.8 : 1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 7))
                    ]
                  : [
                      BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 7),
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: colorScheme.onPrimary,
                          shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
