import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/productivity_period_summary.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import '../models/task_model.dart';
import '../models/productivity_snapshot.dart';
import 'journal_view.dart';

class MonthView extends StatefulWidget {
  final HiveService hiveService;

  const MonthView({super.key, required this.hiveService});

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _currentMonth;
  final ScrollController _monthSelectorController = ScrollController();
  bool _showMonthlyTasks = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
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
      final target = ((_currentMonth.month - 1) * 92.0) - (MediaQuery.of(context).size.width / 2) + 70;
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
    _centerSelectedMonthAfterLayout();
  }

  void _changeSelectorYear(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year + delta, _currentMonth.month);
    });
    _centerSelectedMonthAfterLayout();
  }

  Color _getBubbleColor(DateTime date, Map<String, int> summary, DateTime today) {
    if (date.isBefore(today)) {
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

  Future<void> _openQuickAddForDate(DateTime date) async {
    final selectedDate = DateTime(date.year, date.month, date.day);
    final task = await showTaskFormDialog(
      context,
      date: selectedDate,
      title: 'Add Task',
      actionLabel: 'Save Task',
    );

    if (task != null) {
      await widget.hiveService.addTask(selectedDate, task);
    }
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
            title: isRoutineTask(task) ? 'Edit Routine Details' : 'Update Task',
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
        case RoutineOccurrenceAction.savedOccurrence:
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

  List<String> _getDayHeaders() {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }

  List<DateTime> _daysInCurrentMonth() {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    return List.generate(daysInMonth, (index) => DateTime(_currentMonth.year, _currentMonth.month, index + 1));
  }

  bool _isCompletedTask(Task task) {
    return task.done || task.status.trim().toLowerCase() == 'completed';
  }

  PeriodProductivityStats _monthlyProductivityStats() {
    final days = _daysInCurrentMonth();
    final snapshots = days.map((date) => widget.hiveService.calculateProductivitySnapshotForDate(date)).toList();
    final monthTasks = days.expand((date) => widget.hiveService.getTasksForDate(date)).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedTasks = monthTasks.where(_isCompletedTask).length;
    final pendingTasks = monthTasks.where((task) => !_isCompletedTask(task) && task.status != 'Cancelled').length;
    final overdueTasks = monthTasks.where((task) {
      final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return due.isBefore(today) && !_isCompletedTask(task) && task.status != 'Cancelled';
    }).length;

    return PeriodProductivityStats(
      title: '📅 Monthly Productivity',
      periodLabel: '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
      snapshots: snapshots,
      maximumPoints: days.length * ProductivitySnapshot.maximumPoints.round(),
      totalDays: days.length,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      overdueTasks: overdueTasks,
      intervals: _monthlyWeekIntervals(days, snapshots),
    );
  }

  List<ProductivityIntervalSummary> _monthlyWeekIntervals(List<DateTime> days, List<ProductivitySnapshot> snapshots) {
    final intervals = <ProductivityIntervalSummary>[];
    for (var start = 0; start < days.length; start += 7) {
      final end = (start + 7).clamp(0, days.length).toInt();
      final weekSnapshots = snapshots.sublist(start, end);
      final points = weekSnapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints);
      final maxPoints = weekSnapshots.length * ProductivitySnapshot.maximumPoints;
      intervals.add(ProductivityIntervalSummary(
        label: 'Week ${intervals.length + 1}',
        points: points,
        score: maxPoints == 0 ? 0 : (points / maxPoints * 100).clamp(0.0, 100.0).toDouble(),
      ));
    }
    return intervals;
  }

  int _getWeekdayOffset(DateTime month) {
    // Monday = 1, Sunday = 7
    final firstDay = DateTime(month.year, month.month, 1);
    return (firstDay.weekday - 1) % 7; // 0 for Monday
  }

  int _getDaysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
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



  List<Task> _getMonthlyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    return allTasksByDate.values
        .expand((tasks) => tasks)
        .where((task) {
          final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          return task.repeatTask &&
              task.repeatFrequency == 'Monthly' &&
              !dueDate.isBefore(monthStart) &&
              !dueDate.isAfter(monthEnd);
        })
        .toList();
  }

  Widget _monthlyTasksPanel(List<Task> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showMonthlyTasks = !_showMonthlyTasks),
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
                      "MONTHLY TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_showMonthlyTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showMonthlyTasks)
            SizedBox(
              height: 140,
              child: tasks.isEmpty
                  ? const Center(child: Text('Nothing for this month, Great Job !'))
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

  Widget _monthBubbleSelector() {
    const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 7))],
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
                Text('${_currentMonth.year}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary)),
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final weekdayOffset = _getWeekdayOffset(_currentMonth);
    final totalCells = weekdayOffset + daysInMonth;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_getMonthName(_currentMonth.month)} ${_currentMonth.year} Progress'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final monthlyTasks = _getMonthlyRepeatingTasks();
          final monthlyStats = _monthlyProductivityStats();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _monthBubbleSelector(),
              const SizedBox(height: 16),
              ProductivityPeriodSummaryCard(stats: monthlyStats),
              const SizedBox(height: 16),
              Row(
                children: _getDayHeaders().map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8.0),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4.0,
                  mainAxisSpacing: 4.0,
                ),
                itemCount: totalCells,
                itemBuilder: (context, index) {
                  if (index < weekdayOffset) {
                    return const SizedBox.shrink();
                  }

                  final day = index - weekdayOffset + 1;
                  final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                  final summary = _getCompletedSummaryForDate(date);
                  final isToday = isCurrentMonth && day == now.day;
                  final todayStart = DateTime(now.year, now.month, now.day);

                  return BubbleWidget(
                    color: _getBubbleColor(date, summary, todayStart),
                    isHighlighted: isToday,
                    onTap: () => _openQuickAddForDate(date),
                    label: day.toString(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _monthlyTasksPanel(monthlyTasks),
            ],
          );
        },
      ),
      floatingActionButton: isCurrentMonth
          ? FloatingActionButton(
              onPressed: () async {
                final today = DateTime(now.year, now.month, now.day);
                await showQuickAddTaskDialog(context, today, widget.hiveService);
              },
              tooltip: 'Add task for today',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
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
            constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
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
