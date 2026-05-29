import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';
import '../models/rank_profile.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/rank_profile_card.dart';
import 'journal_view.dart';
import 'journey_timeline_view.dart';

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
          final rankProfile = RankProfile.calculate(
            username: widget.hiveService.getUsername(),
            allTasksByDate: allByDate,
            journalEntries: widget.hiveService.getAllJournalEntries(),
          );

          final summary = _buildSummary(dashboardTasks, todayStart);
          final scopedTaskCounts = _buildScopedTaskCounts(dashboardTasks, todayStart);
          final yearProgress = _buildYearProgress(todayStart);
          final timeProgress = _buildTimeProgress(today);
          final priorityCounts = _countByField(nonRoutineDashboardTasks, (t) => t.priority, _priorityOrder);
          final statusCounts = _countByField(nonRoutineDashboardTasks, (t) => t.status, _statusOrder);
          final categoryCounts = _countByField(nonRoutineDashboardTasks, (t) => t.category, const []);
          final taskInsightItems = _buildTaskInsightItems(nonRoutineDashboardTasks);
          final insightPriorityCounts = _countInsightItems(taskInsightItems, (item) => item.priority, _priorityOrder);
          final insightStatusCounts = _countInsightItems(taskInsightItems, (item) => item.status, _statusOrder);
          final insightCategoryCounts = _countInsightItems(taskInsightItems, (item) => item.category, const []);
          final insightDelegatedCounts = _countInsightItems(taskInsightItems, (item) => item.delegateLabel, const []);

          final dueTodayTasks = dashboardTasks
              .where((task) => _isSameDay(task.dueDate, todayStart))
              .toList();
          final pendingTodayTasks = _buildPendingTodayTasks(dashboardTasks, todayStart);
          final disabledRoutineTasks = _buildDisabledRoutineTasks(allTasks);

          final priorityOptions = ['All', ...insightPriorityCounts.keys];
          final statusOptions = ['All', ...insightStatusCounts.keys];
          final personOptions = ['All', ...insightDelegatedCounts.keys];
          final categoryOptions = ['All', ...insightCategoryCounts.keys];

          _selectedPriority = priorityOptions.contains(_selectedPriority) ? _selectedPriority : 'All';
          _selectedStatus = statusOptions.contains(_selectedStatus) ? _selectedStatus : 'All';
          _selectedPerson = personOptions.contains(_selectedPerson) ? _selectedPerson : 'All';
          _selectedCategory = categoryOptions.contains(_selectedCategory) ? _selectedCategory : 'All';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              _buildDashboardHeader(rankProfile),
              const SizedBox(height: 14),
              _buildThemeSelector(),
              const SizedBox(height: 14),
              _buildHeroCard(rankProfile, summary),
              const SizedBox(height: 14),
              _buildProgressOverviewStrip(timeProgress),
              const SizedBox(height: 14),
              _buildDailyFocusStrip(pendingTodayTasks, todayStart),
              const SizedBox(height: 14),
              _buildHabitRoutineSection(dueTodayTasks),
              const SizedBox(height: 14),
              _buildDisabledRoutineBoard(disabledRoutineTasks),
              const SizedBox(height: 14),
              _buildProjectsSection(nonRoutineDashboardTasks),
              const SizedBox(height: 14),
              _buildSmartAnalyticsSection(nonRoutineDashboardTasks, todayStart, rankProfile),
              const SizedBox(height: 14),
              _buildJourneySection(),
              const SizedBox(height: 14),
              RankProfileCard(
                profile: rankProfile,
                onUsernameChanged: widget.hiveService.setUsername,
                onTap: _openJournal,
                onJourneyTap: _openJourneyTimeline,
              ),
              const SizedBox(height: 12),
              _summaryHeader(summary),
              const SizedBox(height: 12),
              _scopeTaskHeader(scopedTaskCounts),
              const SizedBox(height: 12),
              _yearProgressPanel(yearProgress),
              const SizedBox(height: 12),
              _timeProgressSection(timeProgress),
              const SizedBox(height: 12),
              _priorityChart(priorityCounts),
              const SizedBox(height: 12),
              _taskInsightsFiltersSection(
                items: taskInsightItems,
                priorityOptions: priorityOptions,
                delegateOptions: personOptions,
                statusOptions: statusOptions,
                categoryOptions: categoryOptions,
              ),
              const SizedBox(height: 12),
              _statusBubbles(statusCounts),
              const SizedBox(height: 12),
              _todayTasksSection(pendingTodayTasks),
              const SizedBox(height: 12),
              _categoryDonut(categoryCounts),
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
      if (!_isRecurringTask(task)) {
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

  bool _isRecurringTask(Task task) => task.repeatTask && _normalizedRepeatFrequency(task).isNotEmpty;


  String _normalizedStatus(Task task) => task.status.trim().toLowerCase();

  bool _isOccurrenceLocked(Task task) {
    final status = _normalizedStatus(task);
    return task.done || status == 'completed' || status == 'cancelled' || status == 'missed' || status == 'overdue';
  }

  String _occurrenceLabel(Task task) {
    switch (_normalizedRepeatFrequency(task)) {
      case 'daily':
        return 'today';
      case 'weekly':
        return 'this week';
      case 'monthly':
        return 'this month';
      case 'yearly':
        return 'this year';
      default:
        return 'this period';
    }
  }

  Future<Task?> _showRecurringStatusUpdateDialog(Task task) {
    Future<void> toggleRoutine(BuildContext dialogContext) async {
      await widget.hiveService.setRecurringTaskEnabledByReference(task, !task.routineEnabled);
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    }

    Widget toggleButton(BuildContext dialogContext) {
      return TextButton.icon(
        onPressed: () => toggleRoutine(dialogContext),
        icon: Icon(task.routineEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline),
        label: Text(task.routineEnabled ? 'Disable Routine' : 'Enable Routine'),
      );
    }

    if (_isOccurrenceLocked(task)) {
      final period = _occurrenceLabel(task);
      final statusLabel = task.done || _normalizedStatus(task) == 'completed' ? 'completed' : task.status.toLowerCase();
      return showDialog<Task>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already updated'),
          content: Text('This recurring task was already $statusLabel for $period. You can update it again in the next occurrence. You can still enable or disable this routine without deleting its history.'),
          actions: [
            toggleButton(context),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    }

    return showDialog<Task>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${task.task} status'),
        content: const Text('Recurring tasks keep their details fixed. Update this occurrence status, or disable the routine to stop active tracking while keeping history.'),
        actions: [
          toggleButton(context),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: task.routineEnabled
                ? () => Navigator.of(context).pop(task.copyWith(done: false, status: 'Missed'))
                : null,
            child: const Text('Mark Missed'),
          ),
          ElevatedButton(
            onPressed: task.routineEnabled
                ? () => Navigator.of(context).pop(task.copyWith(done: true, status: 'Completed'))
                : null,
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTask(Task task) async {
    final updated = _isRecurringTask(task)
        ? await _showRecurringStatusUpdateDialog(task)
        : await showTaskFormDialog(
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

  Map<String, int> _buildSummary(List<Task> tasks, DateTime todayStart) {
    final total = tasks.length;
    final completed = tasks.where(_isCompletedTask).length;
    final todayTasks = _buildPendingTodayTasks(tasks, todayStart).length;
    final overdue = tasks
        .where((task) => _dateOnly(task.dueDate).isBefore(todayStart) && _isPendingTask(task))
        .length;

    return {
      'TOTAL TASKS': total,
      "TODAY'S TASKS": todayTasks,
      'OVERDUE TASK': overdue,
      'COMPLETED': completed,
    };
  }


  Map<String, int> _buildScopedTaskCounts(List<Task> tasks, DateTime todayStart) {
    final monthlyTasks = tasks
        .where((t) => t.dueDate.year == todayStart.year && t.dueDate.month == todayStart.month)
        .length;
    final yearlyTasks = tasks.where((t) => t.dueDate.year == todayStart.year).length;
    final todayTasks = _buildPendingTodayTasks(tasks, todayStart).length;

    return {
      'YEAR TASKS': yearlyTasks,
      'MONTH TASKS': monthlyTasks,
      'TODAY TASKS': todayTasks,
    };
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


  List<Task> _buildPendingTodayTasks(List<Task> tasks, DateTime todayStart) {
    final indexedTasks = tasks.asMap().entries.where((entry) {
      final task = entry.value;
      final dueDate = _dateOnly(task.dueDate);
      return !dueDate.isAfter(todayStart) && _isPendingTask(task);
    }).toList();

    indexedTasks.sort((a, b) {
      final priorityCompare = _prioritySortRank(a.value.priority).compareTo(_prioritySortRank(b.value.priority));
      if (priorityCompare != 0) return priorityCompare;

      final dueCompare = a.value.dueDate.compareTo(b.value.dueDate);
      if (dueCompare != 0) return dueCompare;

      return a.key.compareTo(b.key);
    });

    return indexedTasks.map((entry) => entry.value).toList();
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

  bool _isCompletedTask(Task task) => task.done || task.status.trim().toLowerCase() == 'completed';

  bool _isCancelledTask(Task task) => task.status.trim().toLowerCase() == 'cancelled';

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DashboardThemeStyle _dashboardStyle() => DashboardThemeStyle.of(widget.hiveService.getDashboardTheme());

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
        CircleAvatar(
          radius: 22,
          backgroundColor: style.primary,
          child: Text(
            profile.username.isNotEmpty ? profile.username[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
          ),
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
              Text(selectedTheme.label, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
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
                  child: ChoiceChip(
                    selected: isSelected,
                    label: Text(theme.label),
                    avatar: Icon(_themeIcon(theme), size: 18),
                    selectedColor: style.primary.withOpacity(style.dark ? 0.30 : 0.18),
                    backgroundColor: style.elevatedSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? style.primary : style.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(color: isSelected ? style.primary : style.primary.withOpacity(0.16)),
                    onSelected: (_) => widget.hiveService.setDashboardTheme(theme),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(selectedTheme.description, style: TextStyle(color: style.textMuted, fontSize: 12)),
        ],
      ),
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
              offset: Offset(0, 24 * (1 - intro)),
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
                                const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD86D), size: 32),
                                const SizedBox(width: 10),
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


  Widget _darkSection(String title, Widget child, {String? action, VoidCallback? onActionTap}) {
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
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onActionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(action, style: TextStyle(color: style.primary, fontWeight: FontWeight.w700)),
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
    final focus = sorted.take(6).toList();
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
        );
      }).toList()),
    ), action: 'View All');
  }

  Widget _buildHabitRoutineSection(List<Task> todayTasks) {
    final habits = todayTasks.where((t)=>t.repeatTask && t.routineEnabled).toList();
    return _darkSection('Habit & Routine Tracker', Column(children: [
      if (habits.isEmpty)
        const Padding(padding: EdgeInsets.all(8), child: Text('No recurring habits for today.', style: TextStyle(color: Color(0xFFB9C6F3))))
      else
        ...habits.take(4).map((task)=>Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF1A2442), borderRadius: BorderRadius.circular(12)),
          child: Row(children:[
            Container(width: 10,height: 10,decoration: const BoxDecoration(color: Color(0xFF6D7CFF),shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(task.task, style: const TextStyle(color: Colors.white))),
            Text(task.repeatFrequency ?? 'Daily', style: const TextStyle(color: Color(0xFF9CB3FF))),
          ]),
        )),
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
    final projects = tasks.where((t)=>!t.repeatTask).take(4).toList();
    return _darkSection('Projects / Phases', Column(children: projects.map((p) {
      final done = p.done || p.status=='Completed';
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(p.task, style: const TextStyle(color: Colors.white)),
        subtitle: Text(p.category, style: const TextStyle(color: Color(0xFF9CB3FF))),
        trailing: Icon(done ? Icons.check_circle : Icons.timelapse, color: done ? Colors.greenAccent : Colors.orangeAccent),
      );
    }).toList()), action: 'Expand');
  }

  Widget _buildSmartAnalyticsSection(List<Task> tasks, DateTime today, RankProfile profile) {
    final completed = tasks.where((t)=>t.done || t.status=='Completed').length;
    final bestDay = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][today.weekday-1];
    final rate = tasks.isEmpty ? 0 : ((completed / tasks.length)*100).round();
    return _darkSection('Smart Analytics', Wrap(spacing: 10, runSpacing: 10, children: [
      _miniAnalytic('Best Day', bestDay),
      _miniAnalytic('Habit Consistency', '${profile.productivityScore}%'),
      _miniAnalytic('Completion', '$rate%'),
      _miniAnalytic('Most Productive Time', '8 AM'),
    ]));
  }

  Widget _miniAnalytic(String k, String v) => Container(
    width: 150,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFF1A2442), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: const TextStyle(color: Color(0xFF9CB3FF), fontSize: 12)),
      const SizedBox(height: 4),
      Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _buildJourneySection() {
    final style = _dashboardStyle();
    return _darkSection('Journey & Reflection', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('🌅 Wake up routine completed', style: TextStyle(color: style.textPrimary)),
      const SizedBox(height: 6),
      Text('📘 Deep work block tracked', style: TextStyle(color: style.textPrimary)),
      const SizedBox(height: 6),
      Text('😊 Mood: Focused', style: TextStyle(color: style.textPrimary)),
    ]), action: 'Open Journal', onActionTap: _openJournal);
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

  Widget _priorityChart(Map<String, int> priorityCounts) {
    final style = _dashboardStyle();
    final maxCount = priorityCounts.values.fold<int>(1, (max, value) => value > max ? value : max);

    final colors = {
      'Low': const Color(0xFF53C989),
      'Medium': const Color(0xFFE3C86D),
      'High': const Color(0xFFF57D4A),
      'Very High': const Color(0xFFE35B7C),
      'Urgent (Now)': const Color(0xFFAF7AF9),
    };

    return _panel(
      title: 'TASKS ON EACH PRIORITY',
      headerColor: const Color(0xFFE8C1A0),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: priorityCounts.entries.map((entry) {
                final value = entry.value;
                final height = (value / maxCount) * 120;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: value.toDouble()),
                      duration: const Duration(milliseconds: 550),
                      builder: (context, animatedValue, child) => Text('${animatedValue.toInt()}', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: height),
                      duration: Duration(milliseconds: style.animated ? 700 : 250),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedHeight, child) => Container(
                        width: 44,
                        height: value == 0 ? 2 : animatedHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [(colors[entry.key] ?? style.primary).withOpacity(0.40), style.primary.withOpacity(0.72)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(entry.key == 'Urgent (Now)' ? '🔥 Now' : entry.key, style: TextStyle(color: style.textMuted, fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
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

  Widget _statusBubbles(Map<String, int> statusCounts) {
    final style = _dashboardStyle();
    final total = statusCounts.values.fold<int>(0, (sum, value) => sum + value);
    final firstEntry = statusCounts.entries.firstWhere(
      (element) => element.value > 0,
      orElse: () => const MapEntry('In Progress', 0),
    );

    return _panel(
      title: 'TASKS ON EACH STATUS',
      headerColor: const Color(0xFFB8AFD6),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: statusCounts.entries
                .where((entry) => entry.value > 0)
                .map(
                  (entry) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: style.primary),
                      const SizedBox(width: 4),
                      Text('${entry.key} (${entry.value})', style: TextStyle(color: style.textPrimary)),
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: style.animated ? 700 : 250),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Transform.scale(scale: 0.85 + (value * 0.15), child: child),
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(color: style.primary.withOpacity(style.dark ? 0.32 : 0.18), shape: BoxShape.circle, border: Border.all(color: style.primary.withOpacity(0.45), width: 18)),
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (total == 0 ? 0 : firstEntry.value).toDouble()),
                duration: const Duration(milliseconds: 650),
                builder: (context, value, child) => Text(
                  '${value.toInt()}',
                  style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _todayTasksSection(List<Task> tasks) {
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


  List<Widget> _buildPendingTaskRows(List<Task> tasks) {
    final style = _dashboardStyle();
    final todayStart = _dateOnly(DateTime.now());
    final rows = <Widget>[];
    String? activeGroup;

    for (final task in tasks) {
      final group = _dateOnly(task.dueDate).isBefore(todayStart) ? 'Overdue' : 'Today';
      if (group != activeGroup) {
        activeGroup = group;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              group.toUpperCase(),
              style: TextStyle(
                color: group == 'Overdue' ? Colors.redAccent : Colors.green,
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
          subtitle: Text('${task.priority} • ${task.status} • ${_formatDueLabel(task)}', style: TextStyle(color: style.textMuted)),
          trailing: Icon(
            group == 'Overdue' ? Icons.warning_amber_rounded : Icons.radio_button_unchecked,
            color: group == 'Overdue' ? Colors.redAccent : Colors.green,
          ),
        ),
      );
    }

    return rows;
  }

  Widget _categoryDonut(Map<String, int> categoryCounts) {
    final style = _dashboardStyle();
    final topCategory = categoryCounts.entries.fold<MapEntry<String, int>>(
      const MapEntry('No Category', 0),
      (best, current) => current.value > best.value ? current : best,
    );

    return _panel(
      title: 'TASKS ON EACH CATEGORY / PROJECT',
      headerColor: const Color(0xFFE5A9B8),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: style.primary),
                  const SizedBox(width: 6),
                  Text('${topCategory.key} (${topCategory.value})', style: TextStyle(color: style.textPrimary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: style.primary.withOpacity(style.dark ? 0.38 : 0.24), width: 45),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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
