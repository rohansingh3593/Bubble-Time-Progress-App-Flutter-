import 'package:flutter/material.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/productivity_period_summary.dart';
import '../services/hive_service.dart';
import '../constants/dashboard_themes.dart';
import '../models/task_model.dart';
import '../models/productivity_snapshot.dart';
import 'journal_view.dart';
import 'day_view.dart';
import '../utils/text_formatters.dart';

class YearView extends StatefulWidget {
  final HiveService hiveService;
  final DateTime? initialDate;
  final ValueChanged<DateTime>? onDateChanged;
  final ValueChanged<DateTime>? onOpenDate;
  final bool showPeriodControls;

  const YearView(
      {super.key,
      required this.hiveService,
      this.initialDate,
      this.onDateChanged,
      this.onOpenDate,
      this.showPeriodControls = true});

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  late DateTime _currentYear;
  final ScrollController _yearSelectorController = ScrollController();
  bool _showYearlyTasks = true;
  int? _highlightedProgressMonth;
  final Set<int> _expandedAgendaMonths = {};

  @override
  void didUpdateWidget(covariant YearView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != null &&
        widget.initialDate != oldWidget.initialDate) {
      _currentYear = widget.initialDate!;
      _centerSelectedYearAfterLayout();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentYear = widget.initialDate ?? DateTime.now();
    _centerSelectedYearAfterLayout();
  }

  @override
  void dispose() {
    _yearSelectorController.dispose();
    super.dispose();
  }

  List<int> _selectorYears() {
    final selectedYear = _currentYear.year;
    return List.generate(9, (index) => selectedYear - 4 + index);
  }

  void _centerSelectedYearAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_yearSelectorController.hasClients) return;
      final selectedIndex = _selectorYears().indexOf(_currentYear.year);
      final target =
          (selectedIndex * 96.0) - (MediaQuery.of(context).size.width / 2) + 72;
      _yearSelectorController.animateTo(
        target.clamp(0.0, _yearSelectorController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _yearAgendaMonthTile(int month, String monthLabel) {
    final expanded = _expandedAgendaMonths.contains(month);
    return ExpansionTile(
      title: Text(monthLabel),
      onExpansionChanged: (value) => setState(() {
        if (value) {
          _expandedAgendaMonths.add(month);
        } else {
          _expandedAgendaMonths.remove(month);
        }
      }),
      children: expanded
          ? [
              for (var dayNumber = 1;
                  dayNumber <= DateTime(_currentYear.year, month + 1, 0).day;
                  dayNumber++)
                _yearAgendaDayTile(
                  DateTime(_currentYear.year, month, dayNumber),
                  monthLabel,
                ),
            ]
          : const [],
    );
  }

  Widget _yearAgendaDayTile(DateTime date, String monthLabel) {
    final tasks = widget.hiveService
        .getMasterTaskOccurrencesForDate(date)
        .where((task) => DateUtils.isSameDay(task.dueDate, date))
        .toList();
    final taskSummary = tasks.isEmpty
        ? 'No tasks planned'
        : tasks.take(2).map((task) => toTitleCase(task.task)).join(' • ') +
            (tasks.length > 2 ? ' • +${tasks.length - 2} more' : '');

    return ListTile(
      dense: true,
      title: Text('${date.day} $monthLabel'),
      subtitle: Text(taskSummary, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: tasks.isEmpty
          ? null
          : CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onSecondaryContainer,
              child:
                  Text('${tasks.length}', style: const TextStyle(fontSize: 12)),
            ),
      onTap: () {
        if (widget.onOpenDate != null) {
          widget.onOpenDate!(date);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DayView(
              hiveService: widget.hiveService,
              initialDate: date,
            ),
          ),
        );
      },
    );
  }

  void _selectYear(int year) {
    setState(() {
      _currentYear = DateTime(year);
    });
    widget.onDateChanged?.call(_currentYear);
    _centerSelectedYearAfterLayout();
  }

  void _openJournalForTask(Task task) {
    Navigator.of(context).push(
      JournalView.route(
          hiveService: widget.hiveService, initialDate: task.dueDate),
    );
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

  bool _isCompletedTask(Task task) {
    return task.done || task.status.trim().toLowerCase() == 'completed';
  }

  List<DateTime> _daysInCurrentYear() {
    final daysInYear = DateTime(_currentYear.year + 1, 1, 1)
        .difference(DateTime(_currentYear.year, 1, 1))
        .inDays;
    return List.generate(
        daysInYear, (index) => DateTime(_currentYear.year, 1, index + 1));
  }

  PeriodProductivityStats _yearlyProductivityStats() {
    final days = _daysInCurrentYear();
    final snapshots = days
        .map((date) =>
            widget.hiveService.calculateProductivitySnapshotForDate(date))
        .toList();
    final yearTasks = days
        .expand((date) => widget.hiveService.getTasksForDate(date))
        .toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedTasks = yearTasks.where(_isCompletedTask).length;
    final pendingTasks = yearTasks
        .where((task) => !_isCompletedTask(task) && task.status != 'Cancelled')
        .length;
    final overdueTasks = yearTasks.where((task) {
      final due =
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return due.isBefore(today) &&
          !_isCompletedTask(task) &&
          task.status != 'Cancelled';
    }).length;

    return PeriodProductivityStats(
      title: '📆 Year Productivity',
      periodLabel: '${_currentYear.year}',
      snapshots: snapshots,
      maximumPoints: days.length * ProductivitySnapshot.maximumPoints.round(),
      totalDays: days.length,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      overdueTasks: overdueTasks,
      intervals: _yearlyMonthIntervals(snapshots),
    );
  }

  List<ProductivityIntervalSummary> _yearlyMonthIntervals(
      List<ProductivitySnapshot> snapshots) {
    const labels = [
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
    return List.generate(12, (monthIndex) {
      final month = monthIndex + 1;
      final monthSnapshots =
          snapshots.where((snapshot) => snapshot.date.month == month).toList();
      final points = monthSnapshots.fold<int>(
          0, (sum, snapshot) => sum + snapshot.totalPoints);
      final maxPoints =
          monthSnapshots.length * ProductivitySnapshot.maximumPoints;
      return ProductivityIntervalSummary(
        label: labels[monthIndex],
        points: points,
        score: maxPoints == 0
            ? 0
            : (points / maxPoints * 100).clamp(0.0, 100.0).toDouble(),
      );
    });
  }

  List<Task> _getYearlyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final yearStart = DateTime(_currentYear.year, 1, 1);
    final yearEnd = DateTime(_currentYear.year, 12, 31);

    return allTasksByDate.values.expand((tasks) => tasks).where((task) {
      final dueDate =
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return task.repeatTask &&
          task.repeatFrequency == 'Yearly' &&
          !dueDate.isBefore(yearStart) &&
          !dueDate.isAfter(yearEnd);
    }).toList();
  }

  Widget _yearlyTasksPanel(List<Task> tasks) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showYearlyTasks = !_showYearlyTasks),
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
                      "Yearly routines",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                      _showYearlyTasks
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ),
          if (_showYearlyTasks)
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text('No yearly routines for this period.'),
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

  Widget _yearBubbleSelector() {
    final years = _selectorYears();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
      child: SingleChildScrollView(
        controller: _yearSelectorController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: years.map((year) {
            final selected = year == _currentYear.year;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _PeriodSelectorPill(
                label: '$year',
                selected: selected,
                onTap: () => _selectYear(year),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  DashboardThemeStyle _selectedDashboardTheme() {
    return DashboardThemeStyle.of(
      widget.hiveService.getDashboardTheme(),
      palette: widget.hiveService.getDashboardPalette(),
    );
  }

  Widget _yearDayProgressMap(DashboardThemeStyle selectedDashboardTheme) {
    final theme = selectedDashboardTheme;
    final yearStart = DateTime(_currentYear.year, 1, 1);
    final totalDays =
        DateTime(_currentYear.year + 1, 1, 1).difference(yearStart).inDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentYear = _currentYear.year == today.year;
    final todayDayOfYear =
        isCurrentYear ? today.difference(yearStart).inDays + 1 : -1;
    final selectedYearIsPast = _currentYear.year < today.year;
    final selectedYearIsFuture = _currentYear.year > today.year;
    final currentMonth = isCurrentYear ? today.month : null;
    final passedDays = selectedYearIsPast
        ? totalDays
        : selectedYearIsFuture
            ? 0
            : (todayDayOfYear - 1).clamp(0, totalDays).toInt();
    final remainingDays = selectedYearIsPast
        ? 0
        : selectedYearIsFuture
            ? totalDays
            : (totalDays - todayDayOfYear).clamp(0, totalDays).toInt();
    final progress =
        totalDays == 0 ? 0.0 : (passedDays / totalDays).clamp(0.0, 1.0);
    final progressLabel = '${(progress * 100).round()}%';
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

    int monthStartDay(int month) =>
        DateTime(_currentYear.year, month, 1).difference(yearStart).inDays + 1;
    int monthEndDay(int month) =>
        DateTime(_currentYear.year, month + 1, 1).difference(yearStart).inDays;

    bool isHighlightedMonthDay(int dayOfYear) {
      final highlighted = _highlightedProgressMonth;
      if (highlighted == null) return false;
      return dayOfYear >= monthStartDay(highlighted) &&
          dayOfYear <= monthEndDay(highlighted);
    }

    void showCurrentMonthSummary() {
      final month = currentMonth;
      if (month == null) return;
      final daysInMonth = DateTime(today.year, month + 1, 0).day;
      final monthPassed = (today.day - 1).clamp(0, daysInMonth).toInt();
      final monthRemaining =
          (daysInMonth - today.day).clamp(0, daysInMonth).toInt();
      final monthProgress =
          daysInMonth == 0 ? 0 : ((monthPassed / daysInMonth) * 100).round();
      setState(() => _highlightedProgressMonth = month);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$monthPassed Days Passed • $monthRemaining Days Remaining • $monthProgress% Complete')),
      );
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted || _highlightedProgressMonth != month) return;
        setState(() => _highlightedProgressMonth = null);
      });
    }

    Color dayColor(int dayOfYear) {
      if (isCurrentYear && dayOfYear == todayDayOfYear) return theme.accent;
      if (selectedYearIsPast || (isCurrentYear && dayOfYear < todayDayOfYear))
        return theme.primary;
      return theme.textMuted.withOpacity(0.25);
    }

    Color labelColor(int dayOfYear) {
      if (isCurrentYear && dayOfYear == todayDayOfYear) return theme.surface;
      if (selectedYearIsPast || (isCurrentYear && dayOfYear < todayDayOfYear))
        return theme.surface;
      return theme.textMuted;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 600
            ? 20
            : constraints.maxWidth < 1024
                ? 24
                : 28;
        final spacing = constraints.maxWidth < 600 ? 3.0 : 4.0;
        final availableWidth = constraints.maxWidth - 28;
        final bubbleSize =
            ((availableWidth - (spacing * (columns - 1))) / columns)
                .clamp(13.0, 20.0)
                .toDouble();
        const fontSize = 14.0;
        final compactMonthLabels = constraints.maxWidth < 520;
        const shortMonthLabels = [
          'J',
          'F',
          'M',
          'A',
          'M',
          'J',
          'J',
          'A',
          'S',
          'O',
          'N',
          'D'
        ];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.primary.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                  color: theme.primary.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Year Day Progress',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('$passedDays Days Passed • $remainingDays Days Left',
                  style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(progressLabel,
                  style: TextStyle(
                      color: theme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: theme.primary,
                  backgroundColor: theme.textMuted.withOpacity(0.18),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(monthLabels.length, (index) {
                  final month = index + 1;
                  final isRunningMonth = currentMonth == month;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: isRunningMonth ? showCurrentMonthSummary : null,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              begin: 0.96, end: isRunningMonth ? 1.04 : 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            decoration: BoxDecoration(
                              color: isRunningMonth
                                  ? theme.primary.withOpacity(0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: isRunningMonth
                                  ? [
                                      BoxShadow(
                                          color:
                                              theme.primary.withOpacity(0.24),
                                          blurRadius: 14,
                                          spreadRadius: 1)
                                    ]
                                  : null,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                compactMonthLabels
                                    ? shortMonthLabels[index]
                                    : monthLabels[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isRunningMonth
                                      ? theme.primary
                                      : theme.textMuted,
                                  fontSize: isRunningMonth ? 11 : 10,
                                  fontWeight: isRunningMonth
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(totalDays, (index) {
                  final dayOfYear = index + 1;
                  final date = yearStart.add(Duration(days: index));
                  final isToday = isCurrentYear && dayOfYear == todayDayOfYear;
                  final highlightedMonthDay = isHighlightedMonthDay(dayOfYear);
                  return Tooltip(
                    message:
                        '${date.day}/${date.month}/${date.year} • Day $dayOfYear',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: bubbleSize,
                      height: bubbleSize,
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(isToday ? 1.12 : 1.0),
                      decoration: BoxDecoration(
                        color: dayColor(dayOfYear),
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: theme.surface, width: 1.5)
                            : highlightedMonthDay
                                ? Border.all(
                                    color: theme.accent.withOpacity(0.75),
                                    width: 1)
                                : null,
                        boxShadow: isToday
                            ? [
                                BoxShadow(
                                    color: theme.accent.withOpacity(0.65),
                                    blurRadius: 12,
                                    spreadRadius: 2)
                              ]
                            : highlightedMonthDay
                                ? [
                                    BoxShadow(
                                        color: theme.accent.withOpacity(0.24),
                                        blurRadius: 8,
                                        spreadRadius: 0.5)
                                  ]
                                : null,
                      ),
                      child: ExcludeSemantics(
                          child: Text(
                        bubbleSize < 24 ? '' : '$dayOfYear',
                        maxLines: 1,
                        style: TextStyle(
                            color: labelColor(dayOfYear),
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            height: 1),
                      )),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _yearProgressLegendItem(
                      theme: theme, color: theme.primary, label: 'Passed'),
                  _yearProgressLegendItem(
                      theme: theme,
                      color: theme.accent,
                      label: 'Today',
                      glow: true),
                  _yearProgressLegendItem(
                      theme: theme,
                      color: theme.textMuted.withOpacity(0.25),
                      label: 'Remaining'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _yearProgressLegendItem(
      {required DashboardThemeStyle theme,
      required Color color,
      required String label,
      bool glow = false}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: glow
                  ? [
                      BoxShadow(
                          color: theme.accent.withOpacity(0.45),
                          blurRadius: 10,
                          spreadRadius: 1)
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: theme.textMuted, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentYear = _currentYear.year == now.year;
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.showPeriodControls ? '${_currentYear.year}' : 'Year'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final yearlyTasks = _getYearlyRepeatingTasks();
          final yearlyStats = _yearlyProductivityStats();
          final selectedDashboardTheme = _selectedDashboardTheme();
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (widget.showPeriodControls) ...[
                _yearBubbleSelector(),
                const SizedBox(height: 16),
              ],
              if (isCurrentYear)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await showQuickAddTaskDialog(
                        context,
                        todayStart,
                        widget.hiveService,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add task'),
                  ),
                ),
              if (isCurrentYear) const SizedBox(height: 12),
              _yearAgenda(month: _yearMonthLabels),
              const SizedBox(height: 8),
              _yearlyTasksPanel(yearlyTasks),
              const SizedBox(height: 16),
              _yearDayProgressMap(selectedDashboardTheme),
              const SizedBox(height: 16),
              ExpansionTile(title: const Text('Year summary'), children: [
                ProductivityPeriodSummaryCard(stats: yearlyStats)
              ]),
            ],
          );
        },
      ),
    );
  }

  static const List<String> _yearMonthLabels = [
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

  Widget _yearAgenda({required List<String> month}) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: ExpansionTile(
        leading:
            Icon(Icons.view_agenda_outlined, color: theme.colorScheme.primary),
        title: const Text('Browse dates and tasks'),
        subtitle: const Text('Open a date from the year agenda'),
        children: [
          for (var monthNumber = 1; monthNumber <= 12; monthNumber++)
            _yearAgendaMonthTile(monthNumber, month[monthNumber - 1]),
        ],
      ),
    );
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
            constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
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
