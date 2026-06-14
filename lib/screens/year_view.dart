import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/productivity_period_summary.dart';
import '../utils/grid_utils.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import '../constants/dashboard_themes.dart';
import '../models/task_model.dart';
import '../models/productivity_snapshot.dart';
import 'task_screen.dart';
import 'journal_view.dart';

class YearView extends StatefulWidget {
  final HiveService hiveService;

  const YearView({super.key, required this.hiveService});

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  late DateTime _currentYear;
  final ScrollController _yearSelectorController = ScrollController();
  bool _showYearlyTasks = true;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now();
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
      final target = (selectedIndex * 96.0) - (MediaQuery.of(context).size.width / 2) + 72;
      _yearSelectorController.animateTo(
        target.clamp(0.0, _yearSelectorController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _selectYear(int year) {
    setState(() {
      _currentYear = DateTime(year);
    });
    _centerSelectedYearAfterLayout();
  }

  void _showTaskScreen(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: TaskScreen(
            date: date,
            hiveService: widget.hiveService,
          ),
        ),
      ),
    );
  }




  void _openJournalForTask(Task task) {
    Navigator.of(context).push(
      JournalView.route(hiveService: widget.hiveService, initialDate: task.dueDate),
    );
  }

  Future<void> _editTask(Task task) async {
    if (isRoutineTask(task) || hasTaskLinkedInstructions(widget.hiveService, task)) {
      final action = await showRoutineOccurrenceDialog(context: context, task: task, hiveService: widget.hiveService);
      if (action == null || action == RoutineOccurrenceAction.close) return;

      switch (action) {
        case RoutineOccurrenceAction.openJournal:
          _openJournalForTask(task);
          return;
        case RoutineOccurrenceAction.disableRoutine:
          await widget.hiveService.setRecurringTaskEnabledByReference(task, false);
          return;
        case RoutineOccurrenceAction.editDetails:
          final edited = await showTaskFormDialog(
            context,
            date: task.dueDate,
            initialTask: task,
            title: isRoutineTask(task) ? 'Edit Routine Details' : 'View Task Details',
            actionLabel: isRoutineTask(task) ? 'Save Routine' : 'Save Task',
          );
          if (edited != null) {
            if (isRoutineTask(task)) {
              await widget.hiveService.updateRecurringTaskSeriesByReference(task, edited.copyWith(repeatTask: true));
            } else {
              await widget.hiveService.updateTaskByReference(task, edited);
            }
          }
          return;
        case RoutineOccurrenceAction.missOccurrence:
          await widget.hiveService.updateTaskByReference(task, task.copyWith(done: false, status: 'Missed'));
          return;
        case RoutineOccurrenceAction.completeOccurrence:
          await widget.hiveService.updateTaskByReference(task, task.copyWith(done: true, status: 'Completed'));
          return;
        case RoutineOccurrenceAction.close:
          return;
      }
    }

    final updated = await showTaskFormDialog(
      context,
      date: task.dueDate,
      initialTask: task,
      title: 'Update Task',
      actionLabel: 'Save Task',
      onDelete: () => widget.hiveService.deleteTaskByReference(task),
    );

    if (updated != null) {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  Color _getBubbleColor(DateTime date, Map<String, int> summary, DateTime today) {
    final isPassed = date.isBefore(today);
    if (isPassed) {
      return AppColors.passed;
    }

    if (summary['completed']! > 0 && summary['pending']! == 0) {
      return AppColors.taskCompleted;
    } else if (summary['pending']! > 0) {
      return AppColors.taskPending;
    } else {
      return AppColors.taskNone;
    }
  }


  bool _isCompletedTask(Task task) {
    return task.done || task.status.trim().toLowerCase() == 'completed';
  }

  List<DateTime> _daysInCurrentYear() {
    final daysInYear = DateTime(_currentYear.year + 1, 1, 1).difference(DateTime(_currentYear.year, 1, 1)).inDays;
    return List.generate(daysInYear, (index) => DateTime(_currentYear.year, 1, index + 1));
  }

  PeriodProductivityStats _yearlyProductivityStats() {
    final days = _daysInCurrentYear();
    final snapshots = days.map((date) => widget.hiveService.calculateProductivitySnapshotForDate(date)).toList();
    final yearTasks = days.expand((date) => widget.hiveService.getTasksForDate(date)).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedTasks = yearTasks.where(_isCompletedTask).length;
    final pendingTasks = yearTasks.where((task) => !_isCompletedTask(task) && task.status != 'Cancelled').length;
    final overdueTasks = yearTasks.where((task) {
      final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return due.isBefore(today) && !_isCompletedTask(task) && task.status != 'Cancelled';
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

  List<ProductivityIntervalSummary> _yearlyMonthIntervals(List<ProductivitySnapshot> snapshots) {
    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return List.generate(12, (monthIndex) {
      final month = monthIndex + 1;
      final monthSnapshots = snapshots.where((snapshot) => snapshot.date.month == month).toList();
      final points = monthSnapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints);
      final maxPoints = monthSnapshots.length * ProductivitySnapshot.maximumPoints;
      return ProductivityIntervalSummary(
        label: labels[monthIndex],
        points: points,
        score: maxPoints == 0 ? 0 : (points / maxPoints * 100).clamp(0.0, 100.0).toDouble(),
      );
    });
  }

  Map<String, int> _getCompletedSummaryForDate(DateTime date) {
    final completedTasks = widget.hiveService
        .getTasksForDate(date)
        .where((task) => task.status == 'Completed')
        .toList();

    return {
      'completed': completedTasks.length,
      'pending': 0,
    };
  }



  List<Task> _getYearlyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final yearStart = DateTime(_currentYear.year, 1, 1);
    final yearEnd = DateTime(_currentYear.year, 12, 31);

    return allTasksByDate.values
        .expand((tasks) => tasks)
        .where((task) {
          final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          return task.repeatTask &&
              task.repeatFrequency == 'Yearly' &&
              !dueDate.isBefore(yearStart) &&
              !dueDate.isAfter(yearEnd);
        })
        .toList();
  }

  Widget _yearlyTasksPanel(List<Task> tasks) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showYearlyTasks = !_showYearlyTasks),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFAED9AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "YEARLY TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_showYearlyTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showYearlyTasks)
            SizedBox(
              height: 140,
              child: tasks.isEmpty
                  ? const Center(child: Text('Nothing for this year, Great Job !'))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          dense: true,
                          onTap: () => _editTask(task),
                          title: Text(task.task),
                          subtitle: Text('${task.priority} • ${task.status}'),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _yearBubbleSelector() {
    final years = _selectorYears();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 7))],
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
    final totalDays = DateTime(_currentYear.year, 12, 31).difference(yearStart).inDays + 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentYear = _currentYear.year == today.year;
    final todayIndex = isCurrentYear ? today.difference(yearStart).inDays : -1;
    final selectedYearIsPast = _currentYear.year < today.year;
    final selectedYearIsFuture = _currentYear.year > today.year;
    final currentYearPassedDays = todayIndex.clamp(0, totalDays).toInt();
    final passedDays = selectedYearIsPast ? totalDays : selectedYearIsFuture ? 0 : currentYearPassedDays;
    final remainingDays = selectedYearIsPast ? 0 : selectedYearIsFuture ? totalDays : (totalDays - passedDays - 1).clamp(0, totalDays).toInt();
    final progress = totalDays == 0 ? 0.0 : (passedDays / totalDays).clamp(0.0, 1.0);
    final progressLabel = '${(progress * 100).round()}%';
    const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    Color dayColor(DateTime date) {
      final normalized = DateTime(date.year, date.month, date.day);
      if (isCurrentYear && normalized.isAtSameMomentAs(today)) return theme.accent;
      if (selectedYearIsPast || (isCurrentYear && normalized.isBefore(today))) return theme.primary;
      return theme.textMuted.withOpacity(0.28);
    }

    bool isTodayDate(DateTime date) => isCurrentYear && DateTime(date.year, date.month, date.day).isAtSameMomentAs(today);

    return LayoutBuilder(
      builder: (context, constraints) {
        final monthColumns = constraints.maxWidth < 600 ? 7 : constraints.maxWidth < 1024 ? 10 : 14;
        final spacing = constraints.maxWidth < 600 ? 5.0 : 6.0;
        final horizontalPadding = constraints.maxWidth < 600 ? 28.0 : 36.0;
        final availableDotWidth = constraints.maxWidth - horizontalPadding - (spacing * (monthColumns - 1));
        final dotCellWidth = availableDotWidth / monthColumns;
        final dotSize = dotCellWidth.clamp(28.0, 42.0).toDouble();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.primary.withOpacity(0.14)),
            boxShadow: [BoxShadow(color: theme.primary.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Year Day Progress', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('$passedDays days passed • $remainingDays days left', style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: (theme.cardTint ?? theme.elevatedSurface).withOpacity(theme.dark ? 0.40 : 0.72),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.primary.withOpacity(0.14)),
                    ),
                    child: Text(progressLabel, style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  color: theme.primary,
                  backgroundColor: theme.primary.withOpacity(0.12),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(12, (monthIndex) {
                final month = monthIndex + 1;
                final daysInMonth = DateTime(_currentYear.year, month + 1, 0).day;
                return Padding(
                  padding: EdgeInsets.only(bottom: monthIndex == 11 ? 0 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(monthLabels[monthIndex], style: TextStyle(color: theme.textMuted, fontSize: 13, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: List.generate(daysInMonth, (dayIndex) {
                          final date = DateTime(_currentYear.year, month, dayIndex + 1);
                          final isToday = isTodayDate(date);
                          return SizedBox(
                            width: dotCellWidth,
                            height: dotSize,
                            child: Tooltip(
                              message: '${date.day}/${date.month}/${date.year}',
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: dotSize,
                                  height: dotSize,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: dayColor(date),
                                    shape: BoxShape.circle,
                                    boxShadow: isToday ? [BoxShadow(color: theme.accent.withOpacity(0.55), blurRadius: 12, spreadRadius: 2)] : null,
                                  ),
                                  child: Text(
                                    '${dayIndex + 1}',
                                    style: TextStyle(
                                      color: selectedYearIsPast || (isCurrentYear && date.isBefore(today)) || isToday ? theme.surface : theme.textMuted,
                                      fontSize: dotSize < 34 ? 10 : 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _yearProgressLegendItem(theme: theme, color: theme.primary, label: 'Passed'),
                  _yearProgressLegendItem(theme: theme, color: theme.accent, label: 'Today', glow: true),
                  _yearProgressLegendItem(theme: theme, color: theme.textMuted.withOpacity(0.28), label: 'Remaining'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _yearProgressLegendItem({required DashboardThemeStyle theme, required Color color, required String label, bool glow = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: glow ? [BoxShadow(color: theme.accent.withOpacity(0.45), blurRadius: 10, spreadRadius: 1)] : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w800)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentYear = _currentYear.year == now.year;
    final daysInYear = DateTime(_currentYear.year + 1, 1, 1)
        .difference(DateTime(_currentYear.year, 1, 1))
        .inDays;
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentYear.year} Progress'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final yearlyTasks = _getYearlyRepeatingTasks();
          final yearlyStats = _yearlyProductivityStats();
          final selectedDashboardTheme = _selectedDashboardTheme();
          return LayoutBuilder(
            builder: (context, constraints) {
              final gridDims = calculateGridDimensions(
                daysInYear,
                constraints.maxWidth,
                420,
                viewType: 'year',
              );

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _yearBubbleSelector(),
                  const SizedBox(height: 16),
                  _yearDayProgressMap(selectedDashboardTheme),
                  const SizedBox(height: 16),
                  ProductivityPeriodSummaryCard(stats: yearlyStats),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 420,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridDims['columns'],
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
                      ),
                      itemCount: daysInYear,
                      itemBuilder: (context, index) {
                        final date = DateTime(_currentYear.year, 1, index + 1);
                        final summary = _getCompletedSummaryForDate(date);
                        final isToday = isCurrentYear && date.day == now.day && date.month == now.month;

                        return BubbleWidget(
                          color: _getBubbleColor(date, summary, todayStart),
                          isHighlighted: isToday,
                          onTap: () => _showTaskScreen(date),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _yearlyTasksPanel(yearlyTasks),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: isCurrentYear
          ? FloatingActionButton(
              onPressed: () async {
                await showQuickAddTaskDialog(context, todayStart, widget.hiveService);
              },
              tooltip: 'Add task for today',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _PeriodSelectorPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodSelectorPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? AppColors.primaryDark : AppColors.primary.withOpacity(0.18), width: selected ? 1.8 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: AppColors.primary.withOpacity(0.34), blurRadius: 16, offset: const Offset(0, 7))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 7),
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
