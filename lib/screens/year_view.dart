import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/productivity_period_summary.dart';
import '../utils/grid_utils.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import '../models/task_model.dart';
import '../models/productivity_snapshot.dart';
import 'task_screen.dart';

class YearView extends StatefulWidget {
  final HiveService hiveService;

  const YearView({super.key, required this.hiveService});

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  late DateTime _currentYear;
  bool _showYearlyTasks = true;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now();
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



  Future<void> _editTask(Task task) async {
    if (isRoutineTask(task)) {
      final action = await showRoutineOccurrenceDialog(context: context, task: task);
      if (action == null || action == RoutineOccurrenceAction.close) return;

      switch (action) {
        case RoutineOccurrenceAction.disableRoutine:
          await widget.hiveService.setRecurringTaskEnabledByReference(task, false);
          return;
        case RoutineOccurrenceAction.editDetails:
          final edited = await showTaskFormDialog(
            context,
            date: task.dueDate,
            initialTask: task,
            title: 'Edit Routine Details',
            actionLabel: 'Save Routine',
          );
          if (edited != null) {
            await widget.hiveService.updateRecurringTaskSeriesByReference(task, edited.copyWith(repeatTask: true));
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Prev Year'),
                    onPressed: () {
                      setState(() {
                        _currentYear = DateTime(_currentYear.year - 1);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('Next Year'),
                    onPressed: () {
                      setState(() {
                        _currentYear = DateTime(_currentYear.year + 1);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final yearlyTasks = _getYearlyRepeatingTasks();
          final yearlyStats = _yearlyProductivityStats();
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
                  _yearlyTasksPanel(yearlyTasks),
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