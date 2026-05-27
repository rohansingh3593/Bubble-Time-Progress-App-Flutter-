import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/rank_profile.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/rank_profile_card.dart';
import 'journal_view.dart';
import 'journey_timeline_view.dart';

class DashboardView extends StatefulWidget {
  final HiveService hiveService;

  const DashboardView({super.key, required this.hiveService});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with SingleTickerProviderStateMixin {
  String _selectedPriority = 'All';
  String _selectedStatus = 'All';
  String _selectedPerson = 'All';
  String _selectedCategory = 'All';
  late final AnimationController _pulseController;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final today = DateTime.now();
          final todayStart = DateTime(today.year, today.month, today.day);
          final allByDate = widget.hiveService.getAllTasksByDate();
          final allTasks = allByDate.values.expand((list) => list).toList();
          final dashboardTasks = _dedupeTasksForDashboard(allTasks);
          final rankProfile = RankProfile.calculate(
            username: widget.hiveService.getUsername(),
            allTasksByDate: allByDate,
            journalEntries: widget.hiveService.getAllJournalEntries(),
          );

          final summary = _buildSummary(dashboardTasks, todayStart);
          final scopedTaskCounts = _buildScopedTaskCounts(dashboardTasks, todayStart);
          final yearProgress = _buildYearProgress(todayStart);
          final timeProgress = _buildTimeProgress(today);
          final priorityCounts = _countByField(dashboardTasks, (t) => t.priority, _priorityOrder);
          final statusCounts = _countByField(dashboardTasks, (t) => t.status, _statusOrder);
          final categoryCounts = _countByField(dashboardTasks, (t) => t.category, const []);
          final delegatedCounts = _countByField(
            dashboardTasks,
            (t) => (t.delegatedTo == null || t.delegatedTo!.trim().isEmpty)
                ? 'Unassigned'
                : t.delegatedTo!.trim(),
            const [],
          );

          final todayTasks = dashboardTasks
              .where((task) => _isSameDay(task.dueDate, todayStart))
              .toList();

          final priorityOptions = ['All', ...priorityCounts.keys];
          final statusOptions = ['All', ...statusCounts.keys];
          final personOptions = ['All', ...delegatedCounts.keys];
          final categoryOptions = ['All', ...categoryCounts.keys];

          _selectedPriority = priorityOptions.contains(_selectedPriority) ? _selectedPriority : 'All';
          _selectedStatus = statusOptions.contains(_selectedStatus) ? _selectedStatus : 'All';
          _selectedPerson = personOptions.contains(_selectedPerson) ? _selectedPerson : 'All';
          _selectedCategory = categoryOptions.contains(_selectedCategory) ? _selectedCategory : 'All';

          final priorityTasks = _filterBy(dashboardTasks, _selectedPriority, (task) => task.priority);
          final statusTasks = _filterBy(dashboardTasks, _selectedStatus, (task) => task.status);
          final personTasks = _filterBy(
            dashboardTasks,
            _selectedPerson,
            (task) => (task.delegatedTo == null || task.delegatedTo!.trim().isEmpty)
                ? 'Unassigned'
                : task.delegatedTo!.trim(),
          );
          final categoryTasks = _filterBy(dashboardTasks, _selectedCategory, (task) => task.category);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              _buildDashboardHeader(rankProfile),
              const SizedBox(height: 14),
              _buildHeroCard(rankProfile, summary),
              const SizedBox(height: 14),
              _buildProgressOverviewStrip(timeProgress),
              const SizedBox(height: 14),
              _buildDailyFocusStrip(dashboardTasks, todayStart),
              const SizedBox(height: 14),
              _buildHabitRoutineSection(todayTasks),
              const SizedBox(height: 14),
              _buildProjectsSection(dashboardTasks),
              const SizedBox(height: 14),
              _buildSmartAnalyticsSection(dashboardTasks, todayStart, rankProfile),
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
              _filterListSection(
                title: 'BY PRIORITY',
                label: 'PRIORITY',
                selectedValue: _selectedPriority,
                options: priorityOptions,
                onChanged: (value) => setState(() => _selectedPriority = value),
                tasks: priorityTasks,
              ),
              const SizedBox(height: 12),
              _filterListSection(
                title: 'DELEGATED TO',
                label: 'PERSON',
                selectedValue: _selectedPerson,
                options: personOptions,
                onChanged: (value) => setState(() => _selectedPerson = value),
                tasks: personTasks,
                helperText: 'You have to enter your task here',
              ),
              const SizedBox(height: 12),
              _filterListSection(
                title: 'BY STATUS',
                label: 'STATUS',
                selectedValue: _selectedStatus,
                options: statusOptions,
                onChanged: (value) => setState(() => _selectedStatus = value),
                tasks: statusTasks,
              ),
              const SizedBox(height: 12),
              _statusBubbles(statusCounts),
              const SizedBox(height: 12),
              _todayTasksSection(todayTasks),
              const SizedBox(height: 12),
              _categoryDonut(categoryCounts),
              const SizedBox(height: 12),
              _filterListSection(
                title: 'BY CATEGORY',
                label: 'CATEGORY',
                selectedValue: _selectedCategory,
                options: categoryOptions,
                onChanged: (value) => setState(() => _selectedCategory = value),
                tasks: categoryTasks,
              ),
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
      MaterialPageRoute(
        builder: (context) => JournalView(hiveService: widget.hiveService),
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
    if (_isOccurrenceLocked(task)) {
      final period = _occurrenceLabel(task);
      final statusLabel = task.done || _normalizedStatus(task) == 'completed' ? 'completed' : task.status.toLowerCase();
      return showDialog<Task>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already updated'),
          content: Text('This recurring task was already $statusLabel for $period. You can update it again in the next occurrence.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    }

    return showDialog<Task>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${task.task} status'),
        content: const Text('Recurring tasks keep their details fixed. Update only this occurrence status.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(task.copyWith(done: false, status: 'Missed')),
            child: const Text('Mark Missed'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(task.copyWith(done: true, status: 'Completed')),
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
          );

    if (updated != null) {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  Map<String, int> _buildSummary(List<Task> tasks, DateTime todayStart) {
    final total = tasks.length;
    final completed = tasks.where((t) => t.done || t.status == 'Completed').length;
    final todayTasks = tasks.where((t) => _isSameDay(t.dueDate, todayStart)).length;
    final overdue = tasks
        .where(
          (t) =>
              t.dueDate.isBefore(todayStart) &&
              !t.done &&
              t.status != 'Completed' &&
              t.status != 'Cancelled',
        )
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
    final todayTasks = tasks.where((t) => _isSameDay(t.dueDate, todayStart)).length;

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

  List<Task> _filterBy(List<Task> tasks, String selected, String Function(Task) selector) {
    if (selected == 'All') return tasks;
    return tasks.where((task) => selector(task) == selected).toList();
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
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF5B4DFF),
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
              Text('Hello, ${profile.username}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text('Focus. Plan. Achieve.', style: TextStyle(color: Color(0xFF5A6785))),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6))],
          ),
          child: IconButton(onPressed: _openJournal, icon: const Icon(Icons.notifications_none_rounded)),
        ),
      ],
    );
  }

  Widget _buildHeroCard(RankProfile profile, Map<String, int> summary) {
    final completed = summary['COMPLETED'] ?? 0;
    final total = (summary['TOTAL TASKS'] ?? 1).clamp(1, 999999);
    final progress = completed / total;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, intro, _) => Opacity(
        opacity: intro,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - intro)),
          child: AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final glow = 14 + (_pulseController.value * 18);
        return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6A54FF), Color(0xFF2D5BFF)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F63FF).withOpacity(0.45),
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
                    Text('${profile.currentRank.name} ${profile.currentRank.emoji}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                    Text('Level ${profile.level} • ${summary["TODAY'S TASKS"] ?? 0} tasks today', style: const TextStyle(color: Color(0xFFD9D9FF))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${profile.activeStreak} days', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
            transitionBuilder: (child, anim) => SizeTransition(sizeFactor: anim, child: FadeTransition(opacity: anim, child: child)),
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
  }

  Widget _buildProgressOverviewStrip(Map<String, Map<String, int>> timeProgress) {
    final cards = ['Day', 'Week', 'Month', 'Year'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Progress Overview', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDDE3F2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent.toDouble()),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, value, child) => Text(
                      '${value.toInt()}%',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
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
                      color: const Color(0xFF5D6BFF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('$remaining left', style: const TextStyle(color: Color(0xFF63708A))),
                ]),
              ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }


  Widget _darkSection(String title, Widget child, {String? action}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121A31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A355A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (action != null) Text(action, style: const TextStyle(color: Color(0xFF9CB3FF))),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _buildDailyFocusStrip(List<Task> tasks, DateTime today) {
    final sorted = [...tasks]..sort((a,b)=>a.dueDate.compareTo(b.dueDate));
    final focus = sorted.where((t)=>!t.done && t.status!='Completed').take(6).toList();
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
          ]),
        ),
        );
      }).toList()),
    ), action: 'View All');
  }

  Widget _buildHabitRoutineSection(List<Task> todayTasks) {
    final habits = todayTasks.where((t)=>t.repeatTask).toList();
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
    return _darkSection('Journey & Reflection', Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('🌅 Wake up routine completed', style: TextStyle(color: Colors.white)),
      SizedBox(height: 6),
      Text('📘 Deep work block tracked', style: TextStyle(color: Colors.white)),
      SizedBox(height: 6),
      Text('😊 Mood: Focused', style: TextStyle(color: Colors.white)),
    ]), action: 'Timeline');
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB9B0D8),
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
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
                      Text(entry.key, textAlign: TextAlign.center, style: const TextStyle(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }


  Widget _scopeTaskHeader(Map<String, int> scopedCounts) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD4EDF6),
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
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
                      Text(entry.key, textAlign: TextAlign.center, style: const TextStyle(letterSpacing: 1.1, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _yearProgressPanel(Map<String, int> progress) {
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
                Text('Days Passed: ${progress['daysPassed']} / ${progress['totalDays']}'),
                Text('Remaining: ${progress['daysRemaining']}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              color: const Color(0xFF8B6BD9),
            ),
            const SizedBox(height: 6),
            Text('$percent% of year completed'),
          ],
        ),
      ),
    );
  }

  Widget _priorityChart(Map<String, int> priorityCounts) {
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
                    Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: 44,
                      height: value == 0 ? 2 : height,
                      color: (colors[entry.key] ?? Colors.grey).withOpacity(0.45),
                    ),
                    const SizedBox(height: 8),
                    Text(entry.key == 'Urgent (Now)' ? '🔥 Now' : entry.key, style: const TextStyle(fontSize: 11)),
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
    final passed = values['passed'] ?? 0;
    final total = values['total'] ?? 1;
    final remaining = values['remaining'] ?? 0;
    final percent = values['percent'] ?? 0;

    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8AFD6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text('Passed: $passed / $total'),
            Text('Remaining: $remaining'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent / 100,
              minHeight: 7,
              backgroundColor: Colors.grey[300],
              color: const Color(0xFF8B6BD9),
            ),
            const SizedBox(height: 6),
            Text(
              '$percent%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBubbles(Map<String, int> statusCounts) {
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
                      const Icon(Icons.circle, size: 10, color: Color(0xFFB8AFD6)),
                      const SizedBox(width: 4),
                      Text('${entry.key} (${entry.value})'),
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Container(
            width: 170,
            height: 170,
            decoration: const BoxDecoration(color: Color(0xFFB8AFD6), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              total == 0 ? '0' : '${firstEntry.value}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _todayTasksSection(List<Task> tasks) {
    return _panel(
      title: "TODAY'S TASKS",
      headerColor: const Color(0xFFAED9AE),
      trailing: const Icon(Icons.expand_more, color: Colors.green),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE8C1A0),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text('TASK', textAlign: TextAlign.center, style: TextStyle(letterSpacing: 3)),
          ),
          if (tasks.isEmpty)
            _linedListArea(const [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Nothing for Today, Great Job !'),
                ),
              ),
            ])
          else
            _linedListArea(
              tasks
                  .map(
                    (task) => ListTile(
                      dense: true,
                      onTap: () => _editTask(task),
                      title: Text(task.task),
                      subtitle: Text('${task.priority} • ${task.status}'),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _categoryDonut(Map<String, int> categoryCounts) {
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
                  const Icon(Icons.circle, size: 10, color: Color(0xFFB8AFD6)),
                  const SizedBox(width: 6),
                  Text('${topCategory.key} (${topCategory.value})'),
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
              border: Border.all(color: const Color(0xFFB8AFD6), width: 45),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filterListSection({
    required String title,
    required String label,
    required String selectedValue,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required List<Task> tasks,
    String? helperText,
  }) {
    return _panel(
      title: title,
      headerColor: _headerColorFor(title),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: const Color(0xFFE8C1A0),
                child: Text('$label:', style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFFE3E3E3),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedValue,
                      isExpanded: true,
                      items: options
                          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onChanged(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          _linedListArea([
            if (helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(helperText, style: const TextStyle(color: Color(0xFF4B3E68))),
              ),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No tasks for selected filter.'),
              )
            else
              ...tasks.map(
                (task) => ListTile(
                  dense: true,
                  onTap: () => _editTask(task),
                  title: Text(task.task),
                  subtitle: Text('${task.priority} • ${task.status} • ${task.category}'),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required Color headerColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: headerColor,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _linedListArea(List<Widget> children) {
    return Container(
      width: double.infinity,
      height: 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECE8E6), Color(0xFFECE8E6)],
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: children.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black26),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Color _headerColorFor(String title) {
    if (title == 'BY PRIORITY') return const Color(0xFFE8C1A0);
    if (title == 'DELEGATED TO') return const Color(0xFFE5A9B8);
    if (title == 'BY STATUS') return const Color(0xFFE8C1A0);
    if (title == 'BY CATEGORY') return const Color(0xFFA5CAD1);
    return const Color(0xFFE8C1A0);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
