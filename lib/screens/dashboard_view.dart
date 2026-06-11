import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';
import '../models/rank_profile.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../utils/task_time_utils.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import 'journal_view.dart';
import 'journey_timeline_view.dart';
import 'productivity_timeline_view.dart';

class DashboardView extends StatefulWidget {
  final HiveService hiveService;
  final VoidCallback? onGoToDashboard;

  const DashboardView({super.key, required this.hiveService, this.onGoToDashboard});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String _selectedPriority = 'All';
  String _selectedStatus = 'All';
  String _selectedPerson = 'All';
  String _selectedCategory = 'All';
  String _selectedInsightType = 'Priority';
  String _selectedAnalyticsType = 'Status';
  late final AnimationController _pulseController;
  bool _showDetails = false;
  late DateTime _lastDashboardDate;

  @override
  void initState() {
    super.initState();
    _lastDashboardDate = _dateOnly(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDashboardDate();
    }
  }

  void _refreshDashboardDate() {
    final currentDate = _dateOnly(DateTime.now());
    if (!_isSameDay(currentDate, _lastDashboardDate)) {
      setState(() => _lastDashboardDate = currentDate);
    }
  }

  static const List<String> _priorityOrder = [
    'Low',
    'Medium',
    'High',
    'Very High',
    'Urgent (Now)',
  ];

  static const List<String> _statusOrder = [
    'Not Started',
    'In Progress',
    'Completed',
    'Cancelled',
    'Overdue',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashboardStyle().background,
      body: SafeArea(
        child: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final today = DateTime.now();
          final todayStart = DateTime(today.year, today.month, today.day);
          final allByDate = widget.hiveService.getAllTasksByDate();
          final allTasks = allByDate.values.expand((list) => list).toList();
          final dashboardTasks = _dedupeTasksForDashboard(allTasks);
          final nonRoutineDashboardTasks = dashboardTasks.where(_isNonRoutineTask).toList();
          final lifetimeStats = widget.hiveService.getLifetimeProductivityStats();
          final rankProfile = RankProfile.calculate(
            username: widget.hiveService.getUsername(),
            allTasksByDate: allByDate,
            journalEntries: widget.hiveService.getAllJournalEntries(),
            lifetimeStats: lifetimeStats,
          );

          final yearProgress = _buildYearProgress(todayStart);
          final timeProgress = _buildTimeProgress(today);
          final taskInsightItems = _buildTaskInsightItems(nonRoutineDashboardTasks);
          final insightPriorityCounts = _countInsightItems(taskInsightItems, (item) => item.priority, _priorityOrder);
          final insightStatusCounts = _countInsightItems(taskInsightItems, (item) => item.status, _statusOrder);
          final insightCategoryCounts = _countInsightItems(taskInsightItems, (item) => item.category, const []);
          final insightDelegatedCounts = _countInsightItems(taskInsightItems, (item) => item.delegateLabel, const []);

          final activeRoutineTasks = _buildEnabledRoutineOccurrences(allTasks, todayStart);
          final todayTaskRows = _buildTodayTaskRows(allTasks, todayStart);
          final pendingTodayTasks = todayTaskRows
              .where((row) => row.group != _TodayTaskGroup.completed)
              .map((row) => row.task)
              .toList();
          final todayProductivityStats = _buildTodayProductivityStats(todayTaskRows);
          final summary = _buildSummary(dashboardTasks, todayTaskRows);
          final scopedTaskCounts = _buildScopedTaskCounts(dashboardTasks, todayStart, todayTaskRows);
          final disabledRoutineTasks = _buildDisabledRoutineTasks(allTasks);

          final priorityOptions = ['All', ...insightPriorityCounts.keys];
          final statusOptions = ['All', ...insightStatusCounts.keys];
          final personOptions = ['All', ...insightDelegatedCounts.keys];
          final categoryOptions = ['All', ...insightCategoryCounts.keys];

          _selectedPriority = priorityOptions.contains(_selectedPriority) ? _selectedPriority : 'All';
          _selectedStatus = statusOptions.contains(_selectedStatus) ? _selectedStatus : 'All';
          _selectedPerson = personOptions.contains(_selectedPerson) ? _selectedPerson : 'All';
          _selectedCategory = categoryOptions.contains(_selectedCategory) ? _selectedCategory : 'All';

          final analyticsTasks = _filterAnalyticsTasks(nonRoutineDashboardTasks);
          final priorityCounts = _countByField(analyticsTasks, (t) => t.priority, _priorityOrder);
          final statusCounts = _countByField(analyticsTasks, (t) => t.status, _statusOrder);
          final categoryCounts = _countByField(analyticsTasks, (t) => t.category, const []);
          final delegatedAnalyticsCounts = _countByField(analyticsTasks, _delegateLabelForTask, const []);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              _buildDashboardHeader(rankProfile),
              const SizedBox(height: 14),
              _buildThemeSelector(),
              const SizedBox(height: 14),
              _buildHeroCard(rankProfile, summary),
              const SizedBox(height: 14),
              _summaryHeader(summary),
              const SizedBox(height: 14),
              _buildProgressOverviewStrip(timeProgress),
              const SizedBox(height: 12),
              _scopeTaskHeader(scopedTaskCounts),
              const SizedBox(height: 12),
              _yearProgressPanel(yearProgress),
              const SizedBox(height: 12),
              _timeProgressSection(timeProgress),
              const SizedBox(height: 14),
              _buildHabitRoutineSection(activeRoutineTasks),
              const SizedBox(height: 14),
              _buildDisabledRoutineBoard(disabledRoutineTasks),
              const SizedBox(height: 14),
              _todaysProductivitySection(todayProductivityStats),
              const SizedBox(height: 14),
              _todayTasksSection(todayTaskRows),
              const SizedBox(height: 12),
              _productivityAnalyticsCenter(
                tasks: analyticsTasks,
                statusCounts: statusCounts,
                categoryCounts: categoryCounts,
                priorityCounts: priorityCounts,
                delegateCounts: delegatedAnalyticsCounts,
              ),
              const SizedBox(height: 12),
              _taskInsightsFiltersSection(
                items: taskInsightItems,
                priorityOptions: priorityOptions,
                delegateOptions: personOptions,
                statusOptions: statusOptions,
                categoryOptions: categoryOptions,
              ),
              const SizedBox(height: 14),
              _buildDailyFocusStrip(pendingTodayTasks, todayStart),
              const SizedBox(height: 14),
              _buildProjectsSection(nonRoutineDashboardTasks),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    ),
    );
  }



  List<Task> _dedupeTasksForDashboard(List<Task> tasks) {
    final oneTimeTasks = <Task>[];
    final recurringByIdentity = <String, Task>{};

    for (final task in tasks) {
      if (!isRoutineTask(task)) {
        oneTimeTasks.add(task);
        continue;
      }

      final key = _recurringDashboardKey(task);
      final existing = recurringByIdentity[key];
      if (existing == null) {
        recurringByIdentity[key] = task;
        continue;
      }

      final existingDate = DateTime(existing.dueDate.year, existing.dueDate.month, existing.dueDate.day);
      final incomingDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      if (incomingDate.isAfter(existingDate)) {
        recurringByIdentity[key] = task;
        continue;
      }

      if (incomingDate.isAtSameMomentAs(existingDate)) {
        final existingDone = existing.done || existing.status.trim().toLowerCase() == 'completed';
        final incomingDone = task.done || task.status.trim().toLowerCase() == 'completed';
        if (!existingDone && incomingDone) {
          recurringByIdentity[key] = task;
        }
      }
    }

    return [...oneTimeTasks, ...recurringByIdentity.values];
  }

  String _recurringDashboardKey(Task task) {
    return '${task.task.trim().toLowerCase()}|${_normalizedRepeatFrequency(task)}';
  }


  void _openJournal() {
    Navigator.of(context).push(
      JournalView.route(
        hiveService: widget.hiveService,
        onGoToDashboard: widget.onGoToDashboard,
      ),
    );
  }

  void _openJourneyTimeline() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => JourneyTimelineView(hiveService: widget.hiveService),
      ),
    );
  }

  void _openProductivityTimeline() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductivityTimelineView(hiveService: widget.hiveService),
      ),
    );
  }


  String _normalizedRepeatFrequency(Task task) {
    final normalized = task.repeatFrequency?.trim().toLowerCase();
    switch (normalized) {
      case 'daily':
      case 'weekly':
      case 'monthly':
      case 'yearly':
        return normalized!;
      default:
        return '';
    }
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

  Map<String, int> _buildSummary(List<Task> tasks, List<_DashboardTodayTask> todayRows) {
    final total = tasks.length;
    final completed = tasks.where(_isCompletedTask).length;
    final todayTasks = todayRows.length;
    final overdue = todayRows.where((row) => row.group == _TodayTaskGroup.overdue).length;

    return {
      'TOTAL TASKS': total,
      "TODAY'S TASKS": todayTasks,
      'OVERDUE TASK': overdue,
      'COMPLETED': completed,
    };
  }

  Map<String, int> _buildScopedTaskCounts(List<Task> tasks, DateTime todayStart, List<_DashboardTodayTask> todayRows) {
    final monthlyTasks = tasks
        .where((t) => t.dueDate.year == todayStart.year && t.dueDate.month == todayStart.month)
        .length;
    final yearlyTasks = tasks.where((t) => t.dueDate.year == todayStart.year).length;
    final todayTasks = todayRows.length;

    return {
      'YEAR TASKS': yearlyTasks,
      'MONTH TASKS': monthlyTasks,
      'TODAY TASKS': todayTasks,
    };
  }

  _TodayProductivityStats _buildTodayProductivityStats(List<_DashboardTodayTask> rows) {
    final completed = rows.where((row) => row.group == _TodayTaskGroup.completed).length;
    final overdue = rows.where((row) => row.group == _TodayTaskGroup.overdue).length;
    final pending = rows.where((row) => row.group == _TodayTaskGroup.pending).length;
    return _TodayProductivityStats(
      total: rows.length,
      completed: completed,
      pending: pending,
      overdue: overdue,
    );
  }

  Map<String, int> _buildYearProgress(DateTime todayStart) {
    final yearStart = DateTime(todayStart.year, 1, 1);
    final nextYear = DateTime(todayStart.year + 1, 1, 1);
    final totalDaysInYear = nextYear.difference(yearStart).inDays;
    final daysPassed = todayStart.difference(yearStart).inDays + 1;
    final remaining = totalDaysInYear - daysPassed;

    return {
      'totalDays': totalDaysInYear,
      'daysPassed': daysPassed,
      'daysRemaining': remaining,
      'progressPercent': ((daysPassed / totalDaysInYear) * 100).round(),
    };
  }

  Map<String, Map<String, int>> _buildTimeProgress(DateTime now) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final yearStart = DateTime(now.year, 1, 1);
    final nextYear = DateTime(now.year + 1, 1, 1);
    final totalYearDays = nextYear.difference(yearStart).inDays;
    final passedYearDays = todayStart.difference(yearStart).inDays + 1;

    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final totalMonthDays = nextMonth.difference(monthStart).inDays;
    final passedMonthDays = now.day;

    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final nextWeek = weekStart.add(const Duration(days: 7));
    final totalWeekDays = nextWeek.difference(weekStart).inDays;
    final passedWeekDays = now.weekday;

    const totalDayHours = 24;
    final passedDayHours = now.hour + 1;

    Map<String, int> asProgress({
      required int passed,
      required int total,
    }) {
      final remaining = total - passed;
      final progressPercent = ((passed / total) * 100).round();
      return {
        'passed': passed,
        'total': total,
        'remaining': remaining,
        'percent': progressPercent,
      };
    }

    return {
      'Year': asProgress(passed: passedYearDays, total: totalYearDays),
      'Month': asProgress(passed: passedMonthDays, total: totalMonthDays),
      'Week': asProgress(passed: passedWeekDays, total: totalWeekDays),
      'Day': asProgress(passed: passedDayHours, total: totalDayHours),
    };
  }

  List<_DashboardTodayTask> _buildTodayTaskRows(List<Task> tasks, DateTime todayStart) {
    final rows = <_DashboardTodayTask>[];

    for (final task in tasks.where((task) => !task.repeatTask)) {
      if (_isCancelledTask(task)) continue;
      final dueDate = _dateOnly(task.dueDate);
      if (dueDate.isBefore(todayStart) && !_isCompletedTask(task)) {
        rows.add(_DashboardTodayTask(task: task, group: _TodayTaskGroup.overdue, displayStatus: 'Overdue'));
      } else if (_isSameDay(dueDate, todayStart)) {
        if (_isCompletedTask(task)) {
          rows.add(_DashboardTodayTask(task: task, group: _TodayTaskGroup.completed, displayStatus: 'Completed'));
        } else {
          rows.add(_DashboardTodayTask(task: task, group: _TodayTaskGroup.pending, displayStatus: _pendingDisplayStatus(task)));
        }
      }
    }

    rows.addAll(_buildTodayRoutineRows(tasks, todayStart));
    rows.sort((a, b) {
      final groupCompare = a.group.sortRank.compareTo(b.group.sortRank);
      if (groupCompare != 0) return groupCompare;
      final dueCompare = a.task.dueDate.compareTo(b.task.dueDate);
      if (dueCompare != 0) return dueCompare;
      return a.task.task.toLowerCase().compareTo(b.task.task.toLowerCase());
    });
    return rows;
  }

  List<_DashboardTodayTask> _buildTodayRoutineRows(List<Task> tasks, DateTime todayStart) {
    final grouped = <String, List<Task>>{};

    for (final task in tasks) {
      if (!task.repeatTask) continue;
      final frequency = _normalizedRepeatFrequency(task);
      if (!['daily', 'weekly', 'monthly', 'yearly'].contains(frequency)) continue;
      grouped.putIfAbsent(_recurringSeriesKey(task), () => <Task>[]).add(task);
    }

    final rows = <_DashboardTodayTask>[];
    for (final records in grouped.values) {
      records.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      final template = records.first;
      if (!template.routineEnabled) continue;

      final occurrenceDate = _currentRoutineOccurrenceDate(template, todayStart);
      final currentOccurrence = _recordForDate(records, occurrenceDate);

      final hasOverduePreviousOccurrence = _hasOverduePreviousRoutineOccurrence(records, template, occurrenceDate);
      if (currentOccurrence != null) {
        rows.add(_todayRoutineRowForCurrentOccurrence(currentOccurrence, hasOverduePreviousOccurrence: hasOverduePreviousOccurrence));
        continue;
      }

      final occurrenceTask = template.copyWith(
        dueDate: occurrenceDate,
        done: false,
        status: 'Not Updated',
        repeatTask: true,
        routineEnabled: true,
      );
      rows.add(_DashboardTodayTask(
        task: occurrenceTask,
        group: hasOverduePreviousOccurrence ? _TodayTaskGroup.overdue : _TodayTaskGroup.pending,
        displayStatus: hasOverduePreviousOccurrence ? 'Overdue' : 'Pending',
      ));
    }

    return rows;
  }

  Task? _recordForDate(List<Task> records, DateTime date) {
    for (final record in records) {
      if (_isSameDay(record.dueDate, date)) return record;
    }
    return null;
  }

  _DashboardTodayTask _todayRoutineRowForCurrentOccurrence(Task task, {required bool hasOverduePreviousOccurrence}) {
    final status = task.status.trim().toLowerCase();
    if (task.done || status == 'completed') {
      return _DashboardTodayTask(task: task, group: _TodayTaskGroup.completed, displayStatus: 'Completed');
    }
    if (status == 'missed') {
      return _DashboardTodayTask(task: task, group: _TodayTaskGroup.overdue, displayStatus: 'Missed');
    }
    if (status == 'overdue' || hasOverduePreviousOccurrence) {
      return _DashboardTodayTask(task: task, group: _TodayTaskGroup.overdue, displayStatus: 'Overdue');
    }
    return _DashboardTodayTask(task: task, group: _TodayTaskGroup.pending, displayStatus: 'Pending');
  }

  bool _hasOverduePreviousRoutineOccurrence(List<Task> records, Task template, DateTime occurrenceDate) {
    final previousDate = _previousRoutineOccurrenceDate(template, occurrenceDate);
    if (previousDate == null) return false;

    final firstTrackedDate = records
        .map((record) => _dateOnly(record.dueDate))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    if (firstTrackedDate.isAfter(previousDate)) return false;

    final previousOccurrence = _recordForDate(records, previousDate);
    if (previousOccurrence == null) return true;

    final status = previousOccurrence.status.trim().toLowerCase();
    return !previousOccurrence.done && status != 'completed' && status != 'cancelled';
  }

  DateTime? _previousRoutineOccurrenceDate(Task task, DateTime occurrenceDate) {
    switch (_normalizedRepeatFrequency(task)) {
      case 'daily':
        return occurrenceDate.subtract(const Duration(days: 1));
      case 'weekly':
        return occurrenceDate.subtract(const Duration(days: 7));
      default:
        return null;
    }
  }

  String _pendingDisplayStatus(Task task) {
    final status = task.status.trim();
    if (status.isEmpty || status.toLowerCase() == 'not updated') return 'Pending';
    return status;
  }

  List<Task> _buildEnabledRoutineOccurrences(List<Task> tasks, DateTime todayStart) {
    final grouped = <String, List<Task>>{};

    for (final task in tasks) {
      if (!task.repeatTask) continue;
      final frequency = _normalizedRepeatFrequency(task);
      if (!['daily', 'weekly', 'monthly', 'yearly'].contains(frequency)) continue;
      grouped.putIfAbsent(_recurringSeriesKey(task), () => <Task>[]).add(task);
    }

    final routines = <Task>[];
    for (final records in grouped.values) {
      records.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      final template = records.first;
      if (!template.routineEnabled) continue;

      final occurrenceDate = _currentRoutineOccurrenceDate(template, todayStart);
      Task? currentOccurrence;
      for (final record in records) {
        if (_isSameDay(record.dueDate, occurrenceDate)) {
          currentOccurrence = record;
          break;
        }
      }

      routines.add(
        currentOccurrence ??
            template.copyWith(
              dueDate: occurrenceDate,
              done: false,
              status: 'Not Updated',
              repeatTask: true,
              routineEnabled: true,
            ),
      );
    }

    routines.sort((a, b) {
      final frequencyCompare = _routineFrequencySortRank(a).compareTo(_routineFrequencySortRank(b));
      if (frequencyCompare != 0) return frequencyCompare;
      return a.task.toLowerCase().compareTo(b.task.toLowerCase());
    });

    return routines;
  }

  DateTime _currentRoutineOccurrenceDate(Task task, DateTime todayStart) {
    switch (_normalizedRepeatFrequency(task)) {
      case 'weekly':
        return todayStart.subtract(Duration(days: todayStart.weekday - 1));
      case 'monthly':
        return DateTime(todayStart.year, todayStart.month, 1);
      case 'yearly':
        return DateTime(todayStart.year, 1, 1);
      case 'daily':
      default:
        return todayStart;
    }
  }

  int _routineFrequencySortRank(Task task) {
    switch (_normalizedRepeatFrequency(task)) {
      case 'daily':
        return 0;
      case 'weekly':
        return 1;
      case 'monthly':
        return 2;
      case 'yearly':
        return 3;
      default:
        return 4;
    }
  }

  int _routineCurrentStreak(Task task) {
    final allTasks = widget.hiveService.getAllTasksByDate().values.expand((list) => list).where((candidate) {
      return candidate.repeatTask &&
          candidate.task.trim().toLowerCase() == task.task.trim().toLowerCase() &&
          _normalizedRepeatFrequency(candidate) == _normalizedRepeatFrequency(task);
    }).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    var streak = 0;
    for (final record in allTasks) {
      final completed = record.done || record.status.trim().toLowerCase() == 'completed';
      if (!completed) break;
      streak++;
    }
    return streak;
  }

  int _prioritySortRank(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'urgent (now)':
        return 0;
      case 'very high':
        return 1;
      case 'high':
        return 2;
      case 'medium':
        return 3;
      case 'low':
        return 4;
      default:
        return 5;
    }
  }

  bool _isPendingTask(Task task) {
    final routineAllowed = !task.repeatTask || task.routineEnabled;
    return routineAllowed && !_isCompletedTask(task) && !_isCancelledTask(task);
  }

  bool _isNonRoutineTask(Task task) => !task.repeatTask;

  String _delegateLabelForTask(Task task) => task.delegatedTo == null || task.delegatedTo!.trim().isEmpty ? 'Unassigned' : task.delegatedTo!.trim();

  List<Task> _filterAnalyticsTasks(List<Task> tasks) {
    return tasks.where((task) {
      if (!_isNonRoutineTask(task)) return false;
      if (_selectedPriority != 'All' && task.priority != _selectedPriority) return false;
      if (_selectedStatus != 'All' && task.status != _selectedStatus) return false;
      if (_selectedCategory != 'All' && task.category != _selectedCategory) return false;
      if (_selectedPerson != 'All' && _delegateLabelForTask(task) != _selectedPerson) return false;
      return true;
    }).toList();
  }

  bool _isCompletedTask(Task task) => task.done || task.status.trim().toLowerCase() == 'completed';

  bool _isCancelledTask(Task task) => task.status.trim().toLowerCase() == 'cancelled';

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DashboardThemeStyle _dashboardStyle() => DashboardThemeStyle.of(widget.hiveService.getDashboardTheme(), palette: widget.hiveService.getDashboardPalette());

  String _formatShortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String _formatDueLabel(Task task) {
    final dueDate = task.dueDate;
    final dueDay = _dateOnly(dueDate);
    final today = _dateOnly(DateTime.now());
    final dateLabel = _isSameDay(dueDay, today) ? 'today' : '${dueDate.month}/${dueDate.day}';
    final hour = task.hourSlot ?? dueDate.hour;
    final minute = task.hourSlot == null ? dueDate.minute : 0;
    if (hour == 0 && minute == 0 && task.hourSlot == null) return 'Due $dateLabel';

    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return 'Due $dateLabel at $displayHour:$displayMinute $suffix';
  }


  List<_DisabledRoutineTask> _buildDisabledRoutineTasks(List<Task> tasks) {
    final grouped = <String, List<Task>>{};
    for (final task in tasks) {
      if (!task.repeatTask || task.routineEnabled) continue;
      grouped.putIfAbsent(_recurringSeriesKey(task), () => <Task>[]).add(task);
    }

    final disabled = grouped.values.map((records) {
      records.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      final latest = records.first;
      final completedCount = records.where(_isCompletedTask).length;
      return _DisabledRoutineTask(
        task: latest,
        previousStreak: completedCount,
        lastUpdated: records.map((task) => task.dueDate).reduce((a, b) => a.isAfter(b) ? a : b),
      );
    }).toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    return disabled;
  }

  String _recurringSeriesKey(Task task) {
    return '${task.task.trim().toLowerCase()}|${task.category.trim().toLowerCase()}|${_normalizedRepeatFrequency(task)}';
  }

  List<_TaskInsightItem> _buildTaskInsightItems(List<Task> tasks) {
    final grouped = <String, List<Task>>{};
    for (final task in tasks.where(_isNonRoutineTask)) {
      grouped.putIfAbsent(_taskInsightGroupKey(task), () => <Task>[]).add(task);
    }

    final items = grouped.entries.map((entry) {
      final records = [...entry.value]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final primary = records.first;
      final phases = <_TaskInsightPhase>[];
      for (final record in records) {
        phases.addAll(_extractInsightPhases(record, records.length));
      }
      if (phases.isEmpty) {
        phases.add(_TaskInsightPhase(title: primary.task.trim(), status: primary.status));
      }
      return _TaskInsightItem(task: primary, title: _taskInsightTitle(primary), phases: phases);
    }).toList();

    items.sort((a, b) {
      final priorityCompare = _prioritySortRank(a.priority).compareTo(_prioritySortRank(b.priority));
      if (priorityCompare != 0) return priorityCompare;
      return a.task.dueDate.compareTo(b.task.dueDate);
    });
    return items;
  }

  String _taskInsightGroupKey(Task task) {
    final phaseMatch = RegExp(r'^(.*?)\s*[-:|]\s*phase\s*\d+', caseSensitive: false).firstMatch(task.task.trim());
    final title = phaseMatch?.group(1)?.trim() ?? task.task.trim();
    return '${title.toLowerCase()}|${task.category.trim().toLowerCase()}|${task.delegatedTo?.trim().toLowerCase() ?? ''}';
  }

  String _taskInsightTitle(Task task) {
    final phaseMatch = RegExp(r'^(.*?)\s*[-:|]\s*phase\s*\d+', caseSensitive: false).firstMatch(task.task.trim());
    final title = phaseMatch?.group(1)?.trim() ?? task.task.trim();
    return title.isEmpty ? 'Untitled Task' : title;
  }

  List<_TaskInsightPhase> _extractInsightPhases(Task task, int groupSize) {
    const marker = '---PHASES---';
    final markerIndex = task.description.indexOf(marker);
    if (markerIndex != -1) {
      final phaseChunk = task.description.substring(markerIndex + marker.length).trim();
      final lines = phaseChunk.split('\n').where((line) => line.trim().isNotEmpty).toList();
      return [
        for (var index = 0; index < lines.length; index++)
          if (lines[index].split('|').length >= 3)
            _TaskInsightPhase(
              title: lines[index].split('|')[0].trim().isEmpty ? 'Phase ${index + 1}' : lines[index].split('|')[0].trim(),
              status: lines[index].split('|')[2].trim().isEmpty ? 'Not Started' : lines[index].split('|')[2].trim(),
            ),
      ];
    }

    final phaseMatch = RegExp(r'^(.*?)\s*[-:|]\s*phase\s*(\d+)\s*[-:|]?\s*(.*)$', caseSensitive: false).firstMatch(task.task.trim());
    if (phaseMatch != null) {
      final phaseNumber = phaseMatch.group(2)?.trim() ?? '1';
      final suffix = phaseMatch.group(3)?.trim() ?? '';
      return [_TaskInsightPhase(title: suffix.isEmpty ? 'Phase $phaseNumber' : 'Phase $phaseNumber: $suffix', status: task.status)];
    }

    if (groupSize == 1) {
      return [_TaskInsightPhase(title: 'Main Task', status: task.status)];
    }

    return [_TaskInsightPhase(title: task.task.trim(), status: task.status)];
  }

  Map<String, int> _countInsightItems(
    List<_TaskInsightItem> items,
    String Function(_TaskInsightItem) selector,
    List<String> preferredOrder,
  ) {
    final counts = <String, int>{};
    for (final item in items) {
      final key = selector(item).trim().isEmpty ? 'Unassigned' : selector(item).trim();
      counts[key] = (counts[key] ?? 0) + 1;
    }

    if (preferredOrder.isEmpty) {
      final sortedKeys = counts.keys.toList()..sort();
      return {for (final key in sortedKeys) key: counts[key] ?? 0};
    }

    final ordered = <String, int>{};
    for (final key in preferredOrder) {
      ordered[key] = counts[key] ?? 0;
    }
    for (final entry in counts.entries) {
      if (!ordered.containsKey(entry.key)) ordered[entry.key] = entry.value;
    }
    return ordered;
  }

  Map<String, int> _countByField(
    List<Task> tasks,
    String Function(Task) selector,
    List<String> preferredOrder,
  ) {
    final counts = <String, int>{};

    for (final task in tasks) {
      final key = selector(task).trim().isEmpty ? 'Unassigned' : selector(task).trim();
      counts[key] = (counts[key] ?? 0) + 1;
    }

    if (preferredOrder.isEmpty) {
      final sortedKeys = counts.keys.toList()..sort();
      return {for (final key in sortedKeys) key: counts[key] ?? 0};
    }

    final ordered = <String, int>{};
    for (final key in preferredOrder) {
      ordered[key] = counts[key] ?? 0;
    }

    for (final entry in counts.entries) {
      if (!ordered.containsKey(entry.key)) {
        ordered[entry.key] = entry.value;
      }
    }

    return ordered;
  }


  Widget _buildDashboardHeader(RankProfile profile) {
    final style = _dashboardStyle();
    return Row(
      children: [
        ProfileAvatar(
          profile: widget.hiveService.getUserProfile(),
          radius: 22,
          accentColor: style.primary,
          showGlow: false,
          onTap: _openProductivityTimeline,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, ${profile.username}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: style.textPrimary)),
              const SizedBox(height: 2),
              Text('Focus. Plan. Achieve.', style: TextStyle(color: style.textMuted)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: style.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6))],
          ),
          child: IconButton(onPressed: _openJournal, icon: Icon(Icons.notifications_none_rounded, color: style.primary)),
        ),
      ],
    );
  }


  Widget _buildThemeSelector() {
    final style = _dashboardStyle();
    final selectedTheme = widget.hiveService.getDashboardTheme();
    final selectedPalette = widget.hiveService.getDashboardPalette();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.primary.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: style.primary.withOpacity(style.dark ? 0.16 : 0.08),
            blurRadius: style.animated ? 18 : 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: style.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Settings • Dashboard Theme',
                  style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              Text('${selectedTheme.label} • ${selectedPalette.label}', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DashboardThemeType.values.map((theme) {
                final isSelected = theme == selectedTheme;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _themeSelectorChip(
                    selected: isSelected,
                    label: theme.label,
                    leading: Icon(_themeIcon(theme), size: 17, color: _selectorTextColor(isSelected, style)),
                    style: style,
                    onTap: () => widget.hiveService.setDashboardTheme(theme),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text('Color Palette', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DashboardPaletteType.values.map((palette) {
                final isSelected = palette == selectedPalette;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _themeSelectorChip(
                    selected: isSelected,
                    label: palette.label,
                    leading: _paletteDots(palette, compact: true),
                    style: style,
                    onTap: () => widget.hiveService.setDashboardPalette(palette),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text('${selectedTheme.description} • ${selectedPalette.label} palette is applied app-wide.', style: TextStyle(color: style.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _themeSelectorChip({
    required bool selected,
    required String label,
    required Widget leading,
    required DashboardThemeStyle style,
    required VoidCallback onTap,
  }) {
    final chipColor = selected ? Color.lerp(style.elevatedSurface, style.primary, style.dark ? 0.42 : 0.22)! : style.elevatedSurface;
    final foreground = _readableOn(chipColor);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? foreground.withOpacity(0.72) : style.primary.withOpacity(0.22), width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(data: IconThemeData(color: foreground), child: leading),
              const SizedBox(width: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  letterSpacing: style.type == DashboardThemeType.minimal ? 0.4 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _selectorTextColor(bool selected, DashboardThemeStyle style) {
    final chipColor = selected ? Color.lerp(style.elevatedSurface, style.primary, style.dark ? 0.42 : 0.22)! : style.elevatedSurface;
    return _readableOn(chipColor);
  }

  Color _readableOn(Color color) {
    return color.computeLuminance() < 0.45 ? Colors.white : const Color(0xFF17211D);
  }

  Widget _paletteDots(DashboardPaletteType palette, {bool compact = false}) {
    final size = compact ? 5.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: palette.colors
          .map((color) => Container(
                width: size,
                height: size,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.12)),
                ),
              ))
          .toList(),
    );
  }

  IconData _themeIcon(DashboardThemeType theme) {
    switch (theme) {
      case DashboardThemeType.light:
        return Icons.wb_sunny_outlined;
      case DashboardThemeType.dark:
        return Icons.nightlight_round;
      case DashboardThemeType.gamified:
        return Icons.workspace_premium_outlined;
      case DashboardThemeType.calm:
        return Icons.spa_outlined;
      case DashboardThemeType.minimal:
        return Icons.business_center_outlined;
    }
  }

  Widget _buildHeroCard(RankProfile profile, Map<String, int> summary) {
    final style = _dashboardStyle();
    final completed = summary['COMPLETED'] ?? 0;
    final total = (summary['TOTAL TASKS'] ?? 1).clamp(1, 999999);
    final progress = completed / total;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, intro, _) {
        return Opacity(
          opacity: intro,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openJournal,
            child: Transform.translate(
              offset: Offset(0, -28 * (1 - intro)),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final glow = style.animated ? 14 + (_pulseController.value * 18) : 10.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: style.heroGradient),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: style.primary.withOpacity(style.dark ? 0.45 : 0.25),
                              blurRadius: glow,
                              spreadRadius: 1,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ProfileAvatar(
                                  profile: widget.hiveService.getUserProfile(),
                                  radius: 26,
                                  accentColor: const Color(0xFFFFD86D),
                                  badge: profile.currentRank.emoji,
                                  onTap: _openProductivityTimeline,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${profile.currentRank.name} ${profile.currentRank.emoji}',
                                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        'Level ${profile.level} • ${summary["TODAY'S TASKS"] ?? 0} tasks today',
                                        style: const TextStyle(color: Color(0xFFD9D9FF)),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${profile.activeStreak} days',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                    const Text('Current streak', style: TextStyle(color: Color(0xFFD9D9FF))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: const Duration(milliseconds: 1300),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: Colors.white24,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('$completed / $total completed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white70),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  ),
                                  onPressed: _openJourneyTimeline,
                                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                                  label: const Text('Open Journey Timeline'),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white70),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  ),
                                  onPressed: _openProductivityTimeline,
                                  icon: const Icon(Icons.show_chart_rounded, size: 16),
                                  label: const Text('Open Productivity Timeline'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => setState(() => _showDetails = !_showDetails),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, color: Color(0xFFFFD86D), size: 16),
                                  const SizedBox(width: 6),
                                  Text(_showDetails ? 'Hide details' : 'Show details', style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 380),
                              transitionBuilder: (child, anim) => SizeTransition(
                                sizeFactor: anim,
                                child: FadeTransition(opacity: anim, child: child),
                              ),
                              child: _showDetails
                                  ? Padding(
                                      key: const ValueKey('hero_details'),
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Row(
                                        children: [
                                          Expanded(child: _heroMetric('XP', '${profile.xp}')),
                                          Expanded(child: _heroMetric('Score', '${profile.productivityScore}%')),
                                          Expanded(child: _heroMetric('Streak', '${profile.activeStreak}')),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(key: ValueKey('hero_empty')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressOverviewStrip(Map<String, Map<String, int>> timeProgress) {
    final style = _dashboardStyle();
    final cards = ['Day', 'Week', 'Month', 'Year'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress Overview', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24, color: style.textPrimary)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cards.map((label) {
              final values = timeProgress[label] ?? const {'percent': 0, 'remaining': 0};
              final percent = values['percent'] ?? 0;
              final remaining = values['remaining'] ?? 0;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 420 + (cards.indexOf(label) * 180)),
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
                ),
                child: Container(
                width: 145,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: style.primary.withOpacity(0.25))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: style.textPrimary)),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent.toDouble()),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, value, child) => Text(
                      '${value.toInt()}%',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: style.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent / 100),
                    duration: const Duration(milliseconds: 1100),
                    builder: (context, ring, _) => LinearProgressIndicator(
                      value: ring,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE9EDF8),
                      color: style.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('$remaining left', style: TextStyle(color: style.textMuted)),
                ]),
              ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }


  Widget _darkSection(String title, Widget child, {String? action, VoidCallback? onActionTap, bool pulseAction = false}) {
    final style = _dashboardStyle();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.primary.withOpacity(0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: TextStyle(color: style.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (action != null)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = pulseAction && style.animated ? 1 + (_pulseController.value * 0.04) : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onActionTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(action, style: TextStyle(color: style.primary, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _buildDailyFocusStrip(List<Task> tasks, DateTime today) {
    final sorted = [...tasks]..sort((a,b)=>a.dueDate.compareTo(b.dueDate));
    final focus = sorted.take(3).toList();
    return _darkSection('Daily Focus', SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: focus.map((t){
        final urgent = t.priority == 'Urgent (Now)' || t.priority == 'High';
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: urgent ? 1 : 0.6),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
          builder: (context, lift, child) =>
              Transform.translate(offset: Offset(0, -2 * lift), child: child),
          child: Tooltip(
            message: 'Tap to update task',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _editTask(t),
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2442),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(left: BorderSide(color: urgent ? const Color(0xFFFF6A3D) : const Color(0xFF6D7CFF), width: 4)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.task, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(urgent ? '⚡ High Priority' : '• ${t.priority}', style: const TextStyle(color: Color(0xFFB9C6F3))),
                    const SizedBox(height: 4),
                    Text(_formatDueLabel(t), style: const TextStyle(color: Color(0xFF7F8EB9), fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ),
        );
      }).toList()),
    ), action: 'View All');
  }

  Widget _buildHabitRoutineSection(List<Task> routines) {
    return _darkSection('Habit & Routine Tracker', Column(children: [
      if (routines.isEmpty)
        const Padding(padding: EdgeInsets.all(8), child: Text('No enabled routines yet.', style: TextStyle(color: Color(0xFFB9C6F3))))
      else
        ...routines.map((task) {
          final taskColor = Color(task.colorValue);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _editTask(task),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF1A2442), borderRadius: BorderRadius.circular(12)),
              child: Row(children:[
                Container(width: 10,height: 10,decoration: BoxDecoration(color: taskColor,shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(task.task, style: const TextStyle(color: Colors.white))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(task.repeatFrequency ?? 'Daily', style: const TextStyle(color: Color(0xFF9CB3FF))),
                    Text('${_routineCurrentStreak(task)} streak', style: const TextStyle(color: Color(0xFFB9C6F3), fontSize: 11)),
                  ],
                ),
              ]),
            ),
          );
        }),
    ]));
  }


  Widget _buildDisabledRoutineBoard(List<_DisabledRoutineTask> disabledTasks) {
    return _darkSection(
      'Disabled Routine Tasks',
      Column(
        children: [
          if (disabledTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'No disabled routines. Disable a routine to pause active tracking without losing history.',
                style: TextStyle(color: Color(0xFFB9C6F3)),
              ),
            )
          else
            ...disabledTasks.map((item) {
              final task = item.task;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2442),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFA726).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.pause_circle_outline, color: Color(0xFFFFB74D)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.task, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${task.repeatFrequency ?? 'Daily'} • ${task.category}',
                            style: const TextStyle(color: Color(0xFFB9C6F3)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Previous streak: ${item.previousStreak} • Last updated: ${_formatShortDate(item.lastUpdated)}',
                            style: const TextStyle(color: Color(0xFF7F8EB9), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.hiveService.setRecurringTaskEnabledByReference(task, true),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Enable'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      action: '${disabledTasks.length}',
    );
  }

  Widget _buildProjectsSection(List<Task> tasks) {
    final style = _dashboardStyle();
    final projects = tasks.where((task) => !task.repeatTask).take(4).toList();
    return _darkSection(
      'Projects / Phases',
      Column(
        children: projects.map((project) {
          final phases = parseTaskPhases(project.description);
          final completedPhases = phases.where((phase) => phase.isCompleted).length;
          final totalPhases = phases.isEmpty ? 1 : phases.length;
          final progress = phases.isEmpty ? (project.done || project.status == 'Completed' ? 1.0 : 0.0) : completedPhases / totalPhases;
          final done = progress >= 1;
          final subtitle = phases.isEmpty
              ? '${project.category} • ${project.status}'
              : '${project.category} • $completedPhases/$totalPhases phases • ${(progress * 100).round()}%';

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _editTask(project),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(project.task, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)),
                    subtitle: Text(subtitle, style: TextStyle(color: style.primary, fontWeight: FontWeight.w700)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(done ? Icons.check_circle : Icons.timelapse, color: done ? Colors.greenAccent : Colors.orangeAccent),
                        if (phases.isNotEmpty)
                          Text('${(progress * 100).round()}%', style: TextStyle(color: style.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  if (phases.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.16),
                        color: done ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: phases.map((phase) {
                        final completed = phase.isCompleted;
                        return _projectPhaseChip(
                          label: '${phase.name.isEmpty ? 'Phase' : phase.name}: ${phase.status}',
                          color: completed ? Colors.greenAccent : Colors.orangeAccent,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
      action: 'Expand',
    );
  }


  Widget _projectPhaseChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: TextStyle(color: _dashboardStyle().dark ? Colors.white : const Color(0xFF2D241E), fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFD9D9FF), fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _summaryHeader(Map<String, int> summary) {
    final style = _dashboardStyle();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, intro, child) => Opacity(
        opacity: intro,
        child: Transform.scale(scale: 0.98 + (intro * 0.02), child: child),
      ),
      child: Container(
      decoration: BoxDecoration(
        color: style.surface,
        border: Border.all(color: style.primary.withOpacity(0.24)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: style.primary.withOpacity(style.dark ? 0.16 : 0.08), blurRadius: style.animated ? 14 : 7, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: summary.entries
            .map(
              (entry) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      right: entry.key != summary.keys.last
                          ? const BorderSide(color: Colors.black54)
                          : BorderSide.none,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(entry.key, textAlign: TextAlign.center, style: TextStyle(color: style.textMuted, letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.value}',
                        style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ),
    );
  }


  Widget _scopeTaskHeader(Map<String, int> scopedCounts) {
    final style = _dashboardStyle();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, intro, child) => Opacity(opacity: intro, child: Transform.translate(offset: Offset(-18 * (1 - intro), 0), child: child)),
      child: Container(
      decoration: BoxDecoration(
        color: style.surface,
        border: Border.all(color: style.primary.withOpacity(0.24)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: style.primary.withOpacity(style.dark ? 0.14 : 0.08), blurRadius: style.animated ? 14 : 7, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: scopedCounts.entries
            .map(
              (entry) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Text(entry.key, textAlign: TextAlign.center, style: TextStyle(color: style.textMuted, letterSpacing: 1.1, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        '${entry.value}',
                        style: TextStyle(color: style.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ),
    );
  }

  Widget _yearProgressPanel(Map<String, int> progress) {
    final style = _dashboardStyle();
    final percent = progress['progressPercent'] ?? 0;

    return _panel(
      title: 'YEAR PROGRESS OVERVIEW',
      headerColor: const Color(0xFFC9BCE2),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Days Passed: ${progress['daysPassed']} / ${progress['totalDays']}', style: TextStyle(color: style.textPrimary)),
                Text('Remaining: ${progress['daysRemaining']}', style: TextStyle(color: style.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent / 100),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: style.elevatedSurface,
                color: style.primary,
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent.toDouble()),
              duration: const Duration(milliseconds: 900),
              builder: (context, value, child) => Text('${value.toInt()}% of year completed', style: TextStyle(color: style.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productivityAnalyticsCenter({
    required List<Task> tasks,
    required Map<String, int> statusCounts,
    required Map<String, int> categoryCounts,
    required Map<String, int> priorityCounts,
    required Map<String, int> delegateCounts,
  }) {
    final style = _dashboardStyle();
    const tabs = ['Status', 'Category', 'Priority', 'Delegate'];
    final activeTab = tabs.contains(_selectedAnalyticsType) ? _selectedAnalyticsType : 'Status';
    final today = _dateOnly(DateTime.now());
    final completed = tasks.where(_isCompletedTask).length;
    final overdue = tasks.where((task) => _dateOnly(task.dueDate).isBefore(today) && _isPendingTask(task)).length;
    final pending = tasks.where(_isPendingTask).length;

    Map<String, int> activeCounts;
    if (activeTab == 'Category') {
      activeCounts = categoryCounts;
    } else if (activeTab == 'Priority') {
      activeCounts = priorityCounts;
    } else if (activeTab == 'Delegate') {
      activeCounts = delegateCounts;
    } else {
      activeCounts = statusCounts;
    }

    return _panel(
      title: 'PRODUCTIVITY ANALYTICS',
      headerColor: style.primary,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: style.animated ? 420 : 180),
        curve: Curves.easeOutCubic,
        builder: (context, intro, child) => Opacity(
          opacity: intro,
          child: Transform.translate(offset: Offset(0, 14 * (1 - intro)), child: child),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _analyticsSummaryPill('Total Tasks', tasks.length, Icons.analytics_outlined),
                  _analyticsSummaryPill('Completed', completed, Icons.check_circle_outline),
                  _analyticsSummaryPill('Pending', pending, Icons.timelapse_outlined),
                  _analyticsSummaryPill('Overdue', overdue, Icons.warning_amber_rounded),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tabs.map((tab) {
                    final selected = activeTab == tab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(tab),
                        selectedColor: style.primary.withOpacity(style.dark ? 0.34 : 0.18),
                        backgroundColor: style.elevatedSurface,
                        side: BorderSide(color: selected ? style.primary : style.primary.withOpacity(0.18)),
                        labelStyle: TextStyle(
                          color: selected ? style.primary : style.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) => setState(() => _selectedAnalyticsType = tab),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: style.animated ? 330 : 160),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final scale = Tween<double>(begin: 0.94, end: 1).animate(animation);
                final slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: scale,
                    child: SlideTransition(position: slide, child: child),
                  ),
                );
              },
              child: Padding(
                key: ValueKey(activeTab),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: activeTab == 'Priority'
                    ? _analyticsBarChart(activeCounts)
                    : activeTab == 'Delegate'
                        ? _delegateAnalyticsChart(activeCounts)
                        : _analyticsDonutChart(activeTab, activeCounts),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsSummaryPill(String label, int value, IconData icon) {
    final style = _dashboardStyle();
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: style.elevatedSurface.withOpacity(style.dark ? 0.72 : 0.56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.primary.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: style.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: Duration(milliseconds: style.animated ? 650 : 180),
                  builder: (context, animatedValue, child) => Text(
                    '${animatedValue.toInt()}',
                    style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsDonutChart(String label, Map<String, int> counts) {
    final style = _dashboardStyle();
    final entries = counts.entries.where((entry) => entry.value > 0).toList();
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    final topValue = entries.isEmpty ? 0 : entries.map((entry) => entry.value).reduce((a, b) => a > b ? a : b);
    final ringValue = total == 0 ? 0.0 : (topValue / total).clamp(0.0, 1.0).toDouble();

    return Column(
      children: [
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ringValue),
          duration: Duration(milliseconds: style.animated ? 850 : 220),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => SizedBox(
            width: 178,
            height: 178,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 178,
                  height: 178,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 24,
                    color: style.primary,
                    backgroundColor: style.primary.withOpacity(style.dark ? 0.16 : 0.10),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total Tasks', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: total.toDouble()),
                      duration: Duration(milliseconds: style.animated ? 720 : 180),
                      builder: (context, animatedValue, child) => Text(
                        '${animatedValue.toInt()}',
                        style: TextStyle(color: style.textPrimary, fontSize: 32, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(label, style: TextStyle(color: style.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _analyticsLegend(entries, total),
      ],
    );
  }

  Widget _delegateAnalyticsChart(Map<String, int> counts) {
    final style = _dashboardStyle();
    final entries = counts.entries.where((entry) => entry.value > 0).toList();
    final maxCount = entries.fold<int>(1, (max, entry) => entry.value > max ? entry.value : max);
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No delegate analytics yet.', style: TextStyle(color: style.textPrimary)),
      );
    }

    return Column(
      children: entries.map((entry) {
        final progress = entry.value / maxCount;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(width: 92, child: Text(entry.key, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: Duration(milliseconds: style.animated ? 700 : 180),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: style.primary.withOpacity(0.12),
                      color: style.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: entry.value.toDouble()),
                duration: Duration(milliseconds: style.animated ? 620 : 180),
                builder: (context, value, child) => Text('${value.toInt()}', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _analyticsBarChart(Map<String, int> counts) {
    final style = _dashboardStyle();
    final maxCount = counts.values.fold<int>(1, (max, value) => value > max ? value : max);
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: counts.entries.map((entry) {
          final value = entry.value;
          final height = (value / maxCount) * 128;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value.toDouble()),
                    duration: Duration(milliseconds: style.animated ? 650 : 180),
                    builder: (context, animatedValue, child) => Text('${animatedValue.toInt()}', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: height),
                    duration: Duration(milliseconds: style.animated ? 760 : 220),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedHeight, child) => Container(
                      height: value == 0 ? 3 : animatedHeight,
                      width: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [style.primary.withOpacity(0.45), style.secondary]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: style.primary.withOpacity(style.dark ? 0.26 : 0.12), blurRadius: 12)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(entry.key == 'Urgent (Now)' ? 'Now' : entry.key, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _analyticsLegend(List<MapEntry<String, int>> entries, int total) {
    final style = _dashboardStyle();
    if (entries.isEmpty) {
      return Text('No analytics data for current filters.', style: TextStyle(color: style.textPrimary));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: entries.map((entry) {
        final percent = total == 0 ? 0 : ((entry.value / total) * 100).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: style.elevatedSurface.withOpacity(style.dark ? 0.72 : 0.54),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: style.primary.withOpacity(0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: style.primary),
              const SizedBox(width: 6),
              Text('${entry.key} ${entry.value} • $percent%', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _timeProgressSection(Map<String, Map<String, int>> timeProgress) {
    return _panel(
      title: 'TIME PROGRESS CARDS',
      headerColor: const Color(0xFFC9BCE2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: timeProgress.entries
              .map((entry) => _timeProgressCard(entry.key, entry.value))
              .toList(),
        ),
      ),
    );
  }

  Widget _timeProgressCard(String label, Map<String, int> values) {
    final style = _dashboardStyle();
    final passed = values['passed'] ?? 0;
    final total = values['total'] ?? 1;
    final remaining = values['remaining'] ?? 0;
    final percent = values['percent'] ?? 0;

    final indexMap = {'Year': 0, 'Month': 1, 'Week': 2, 'Day': 3};
    final index = indexMap[label] ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeOut,
      builder: (context, intro, child) => Opacity(
        opacity: intro,
        child: Transform.translate(offset: Offset(0, 14 * (1 - intro)), child: child),
      ),
      child: SizedBox(
        width: 160,
        child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: style.primary.withOpacity(0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: style.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text('Passed: $passed / $total', style: TextStyle(color: style.textMuted)),
            Text('Remaining: $remaining', style: TextStyle(color: style.textMuted)),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent / 100),
              duration: Duration(milliseconds: 900 + (index * 120)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: style.elevatedSurface,
                color: style.primary,
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent.toDouble()),
              duration: Duration(milliseconds: 850 + (index * 120)),
              builder: (context, value, child) => Text(
                '${value.toInt()}%',
                style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _todaysProductivitySection(_TodayProductivityStats stats) {
    final style = _dashboardStyle();
    final badge = _productivityBadge(stats.completionRate);
    const completedColor = Color(0xFF2ECC71);
    const pendingColor = Color(0xFFFFA726);
    const overdueColor = Color(0xFFFF5252);

    return _panel(
      title: "TODAY'S PRODUCTIVITY",
      headerColor: style.primary,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: style.animated ? 500 : 180),
        curve: Curves.easeOutCubic,
        builder: (context, animationValue, child) {
          return Opacity(
            opacity: animationValue,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - animationValue)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(176, 176),
                                  painter: _TodayProductivityPiePainter(
                                    completed: stats.completed,
                                    pending: stats.pending,
                                    overdue: stats.overdue,
                                    progress: animationValue,
                                    completedColor: completedColor,
                                    pendingColor: pendingColor,
                                    overdueColor: overdueColor,
                                    backgroundColor: style.primary.withOpacity(style.dark ? 0.14 : 0.08),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: stats.completionRate.toDouble()),
                                      duration: Duration(milliseconds: style.animated ? 500 : 180),
                                      builder: (context, value, child) => Text(
                                        '${value.toInt()}%',
                                        style: TextStyle(color: style.textPrimary, fontSize: 32, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    Text('Completion', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: badge.color.withOpacity(style.dark ? 0.20 : 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: badge.color.withOpacity(0.40)),
                                ),
                                child: Text(
                                  '${badge.label} ${badge.emoji}',
                                  style: TextStyle(color: badge.color, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _todayProductivityLegend('Completed', stats.completed, completedColor),
                              _todayProductivityLegend('Pending', stats.pending, pendingColor),
                              if (stats.overdue > 0) _todayProductivityLegend('Overdue', stats.overdue, overdueColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _todayProductivityStat('Today\'s Tasks', stats.total),
                        _todayProductivityStat('Completed', stats.completed),
                        _todayProductivityStat('Pending', stats.pending),
                        _todayProductivityStat('Overdue', stats.overdue),
                        _todayProductivityStat('Completion Rate', stats.completionRate, suffix: '%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _todayProductivityLegend(String label, int value, Color color) {
    final style = _dashboardStyle();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.34), blurRadius: 8)]),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w700))),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: Duration(milliseconds: style.animated ? 500 : 180),
            builder: (context, animatedValue, child) => Text('${animatedValue.toInt()}', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _todayProductivityStat(String label, int value, {String suffix = ''}) {
    final style = _dashboardStyle();
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: style.elevatedSurface.withOpacity(style.dark ? 0.72 : 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.primary.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: Duration(milliseconds: style.animated ? 500 : 180),
            builder: (context, animatedValue, child) => Text(
              '${animatedValue.toInt()}$suffix',
              style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  _ProductivityBadge _productivityBadge(int rate) {
    if (rate <= 25) return const _ProductivityBadge(label: 'Needs Attention', emoji: '🔴', color: Color(0xFFFF5252));
    if (rate <= 50) return const _ProductivityBadge(label: 'Getting Started', emoji: '🟠', color: Color(0xFFFFA726));
    if (rate <= 75) return const _ProductivityBadge(label: 'Productive', emoji: '🟢', color: Color(0xFF2ECC71));
    return const _ProductivityBadge(label: 'Excellent', emoji: '🔥', color: Color(0xFFFF7043));
  }

  Widget _todayTasksSection(List<_DashboardTodayTask> tasks) {
    final style = _dashboardStyle();
    return _panel(
      title: "TODAY'S TASKS",
      headerColor: const Color(0xFFAED9AE),
      trailing: const Icon(Icons.expand_more, color: Colors.green),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: style.primary.withOpacity(style.dark ? 0.22 : 0.14),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('TASK', textAlign: TextAlign.center, style: TextStyle(color: style.textPrimary, letterSpacing: 3)),
          ),
          if (tasks.isEmpty)
            _linedListArea([
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Nothing for Today, Great Job !', style: TextStyle(color: style.textPrimary)),
                ),
              ),
            ])
          else
            _linedListArea(_buildPendingTaskRows(tasks)),
        ],
      ),
    );
  }


  List<Widget> _buildPendingTaskRows(List<_DashboardTodayTask> tasks) {
    final style = _dashboardStyle();
    final rows = <Widget>[];
    _TodayTaskGroup? activeGroup;

    for (final row in tasks) {
      final task = row.task;
      if (row.group != activeGroup) {
        activeGroup = row.group;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              row.group.label,
              style: TextStyle(
                color: row.group.color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        );
      }

      rows.add(
        ListTile(
          dense: true,
          onTap: () => _editTask(task),
          title: Text(task.task, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text('${task.priority} • ${row.displayStatus} • ${_formatDueLabel(task)}', style: TextStyle(color: style.textMuted)),
          trailing: Icon(
            row.group.icon,
            color: row.group.color,
          ),
        ),
      );
    }

    return rows;
  }

  Widget _taskInsightsFiltersSection({
    required List<_TaskInsightItem> items,
    required List<String> priorityOptions,
    required List<String> delegateOptions,
    required List<String> statusOptions,
    required List<String> categoryOptions,
  }) {
    final style = _dashboardStyle();
    const filters = ['Priority', 'Delegate', 'Status', 'Category'];
    final activeFilter = filters.contains(_selectedInsightType) ? _selectedInsightType : 'Priority';
    List<String> options;
    String selectedValue;
    String Function(_TaskInsightItem) itemValue;
    if (activeFilter == 'Delegate') {
      options = delegateOptions;
      selectedValue = _selectedPerson;
      itemValue = (item) => item.delegateLabel;
    } else if (activeFilter == 'Status') {
      options = statusOptions;
      selectedValue = _selectedStatus;
      itemValue = (item) => item.status;
    } else if (activeFilter == 'Category') {
      options = categoryOptions;
      selectedValue = _selectedCategory;
      itemValue = (item) => item.category;
    } else {
      options = priorityOptions;
      selectedValue = _selectedPriority;
      itemValue = (item) => item.priority;
    }
    final safeSelectedValue = options.contains(selectedValue) ? selectedValue : 'All';
    final filteredItems = safeSelectedValue == 'All' ? items : items.where((item) => itemValue(item) == safeSelectedValue).toList();

    return _panel(
      title: 'TASK INSIGHTS & FILTERS',
      headerColor: style.primary,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            color: style.elevatedSurface.withOpacity(style.dark ? 0.66 : 0.42),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final isSelected = activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: style.primary.withOpacity(style.dark ? 0.34 : 0.20),
                      backgroundColor: style.surface,
                      side: BorderSide(color: isSelected ? style.primary : style.primary.withOpacity(0.18)),
                      labelStyle: TextStyle(
                        color: isSelected ? style.primary : style.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) => setState(() => _selectedInsightType = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: Duration(milliseconds: style.animated ? 320 : 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation);
              return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
            },
            child: Column(
              key: ValueKey('$activeFilter-$safeSelectedValue-${filteredItems.length}'),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: style.primary.withOpacity(style.dark ? 0.24 : 0.16),
                      child: Text('$activeFilter:', style: TextStyle(color: style.textPrimary, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: style.animated ? 280 : 120),
                        color: style.elevatedSurface.withOpacity(style.dark ? 0.72 : 0.55),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: safeSelectedValue,
                            isExpanded: true,
                            dropdownColor: style.surface,
                            style: TextStyle(color: style.textPrimary),
                            items: options
                                .map((option) => DropdownMenuItem(value: option, child: Text(option, style: TextStyle(color: style.textPrimary))))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                if (activeFilter == 'Delegate') {
                                  _selectedPerson = value;
                                } else if (activeFilter == 'Status') {
                                  _selectedStatus = value;
                                } else if (activeFilter == 'Category') {
                                  _selectedCategory = value;
                                } else {
                                  _selectedPriority = value;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _linedListArea([
                  if (filteredItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('No non-routine tasks for selected filter.', style: TextStyle(color: style.textPrimary)),
                    )
                  else
                    ...filteredItems.map(_taskInsightTile),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskInsightTile(_TaskInsightItem item) {
    final style = _dashboardStyle();
    final taskColor = Color(item.task.colorValue);
    final progress = item.phaseProgress;
    return ListTile(
      dense: true,
      onTap: () => _editTask(item.task),
      leading: Container(
        width: 4,
        height: 44,
        decoration: BoxDecoration(
          color: taskColor,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [BoxShadow(color: taskColor.withOpacity(0.35), blurRadius: 10)],
        ),
      ),
      title: Text(item.title, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('${item.priority} • ${item.status} • ${item.category} • ${item.delegateLabel}', style: TextStyle(color: style.textMuted)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: style.primary.withOpacity(0.12),
              color: taskColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Progress: ${item.completedPhases}/${item.totalPhases} phases completed',
            style: TextStyle(color: style.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: style.primary),
    );
  }

  Widget _panel({
    required String title,
    required Color headerColor,
    required Widget child,
    Widget? trailing,
  }) {
    final style = _dashboardStyle();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: style.animated ? 380 : 180),
      curve: Curves.easeOutCubic,
      builder: (context, intro, panelChild) => Opacity(
        opacity: intro,
        child: Transform.translate(offset: Offset(0, 10 * (1 - intro)), child: panelChild),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: style.surface,
          border: Border.all(color: style.primary.withOpacity(0.22)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: style.primary.withOpacity(style.dark ? 0.14 : 0.08), blurRadius: style.animated ? 14 : 8, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [style.primary.withOpacity(style.dark ? 0.34 : 0.18), style.secondary.withOpacity(style.dark ? 0.24 : 0.12)]),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: style.textPrimary, letterSpacing: 2, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _linedListArea(List<Widget> children) {
    final style = _dashboardStyle();
    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.surface, style.elevatedSurface.withOpacity(style.dark ? 0.72 : 0.46)],
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: children.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: style.primary.withOpacity(0.16)),
        itemBuilder: (context, index) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: style.animated ? 240 + (index * 35) : 120),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(offset: Offset(12 * (1 - value), 0), child: child),
          ),
          child: children[index],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

enum _TodayTaskGroup {
  overdue,
  pending,
  completed;

  int get sortRank {
    switch (this) {
      case _TodayTaskGroup.overdue:
        return 0;
      case _TodayTaskGroup.pending:
        return 1;
      case _TodayTaskGroup.completed:
        return 2;
    }
  }

  String get label {
    switch (this) {
      case _TodayTaskGroup.overdue:
        return 'OVERDUE';
      case _TodayTaskGroup.pending:
        return 'PENDING';
      case _TodayTaskGroup.completed:
        return 'COMPLETED TODAY';
    }
  }

  Color get color {
    switch (this) {
      case _TodayTaskGroup.overdue:
        return Colors.redAccent;
      case _TodayTaskGroup.pending:
        return Colors.orangeAccent;
      case _TodayTaskGroup.completed:
        return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case _TodayTaskGroup.overdue:
        return Icons.warning_amber_rounded;
      case _TodayTaskGroup.pending:
        return Icons.radio_button_unchecked;
      case _TodayTaskGroup.completed:
        return Icons.check_circle_outline;
    }
  }
}

class _DashboardTodayTask {
  final Task task;
  final _TodayTaskGroup group;
  final String displayStatus;

  const _DashboardTodayTask({required this.task, required this.group, required this.displayStatus});
}

class _TodayProductivityStats {
  final int total;
  final int completed;
  final int pending;
  final int overdue;

  const _TodayProductivityStats({required this.total, required this.completed, required this.pending, required this.overdue});

  int get completionRate => total == 0 ? 0 : ((completed / total) * 100).round();
}

class _ProductivityBadge {
  final String label;
  final String emoji;
  final Color color;

  const _ProductivityBadge({required this.label, required this.emoji, required this.color});
}

class _TodayProductivityPiePainter extends CustomPainter {
  final int completed;
  final int pending;
  final int overdue;
  final double progress;
  final Color completedColor;
  final Color pendingColor;
  final Color overdueColor;
  final Color backgroundColor;

  const _TodayProductivityPiePainter({
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.progress,
    required this.completedColor,
    required this.pendingColor,
    required this.overdueColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = completed + pending + overdue;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    if (total == 0) {
      paint.color = backgroundColor;
      canvas.drawCircle(center, radius * 0.62, paint);
      return;
    }

    var startAngle = -math.pi / 2;
    final animationProgress = progress.clamp(0.0, 1.0).toDouble();
    for (final segment in [
      MapEntry(completedColor, completed),
      MapEntry(pendingColor, pending),
      MapEntry(overdueColor, overdue),
    ]) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * math.pi * 2 * animationProgress;
      paint.color = segment.key;
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius * 0.58, paint);
  }

  @override
  bool shouldRepaint(covariant _TodayProductivityPiePainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.pending != pending ||
        oldDelegate.overdue != overdue ||
        oldDelegate.progress != progress ||
        oldDelegate.completedColor != completedColor ||
        oldDelegate.pendingColor != pendingColor ||
        oldDelegate.overdueColor != overdueColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _TaskInsightItem {
  final Task task;
  final String title;
  final List<_TaskInsightPhase> phases;

  const _TaskInsightItem({required this.task, required this.title, required this.phases});

  String get priority => task.priority.trim().isEmpty ? 'Medium' : task.priority.trim();
  String get status => task.status.trim().isEmpty ? 'Not Started' : task.status.trim();
  String get category => task.category.trim().isEmpty ? 'Uncategorized' : task.category.trim();
  String get delegateLabel => task.delegatedTo == null || task.delegatedTo!.trim().isEmpty ? 'Unassigned' : task.delegatedTo!.trim();
  int get totalPhases => phases.isEmpty ? 1 : phases.length;
  int get completedPhases => phases.where((phase) => phase.status.trim().toLowerCase() == 'completed').length;
  double get phaseProgress => totalPhases == 0 ? 0 : completedPhases / totalPhases;
}

class _TaskInsightPhase {
  final String title;
  final String status;

  const _TaskInsightPhase({required this.title, required this.status});
}

class _DisabledRoutineTask {
  final Task task;
  final int previousStreak;
  final DateTime lastUpdated;

  const _DisabledRoutineTask({
    required this.task,
    required this.previousStreak,
    required this.lastUpdated,
  });
}
