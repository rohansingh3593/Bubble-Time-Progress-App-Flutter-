import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/dashboard_themes.dart';
import '../models/instruction.dart';
import '../models/rank_profile.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../utils/text_formatters.dart';
import '../utils/task_time_utils.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import 'goal_dashboard_view.dart';
import 'instruction_dashboard_view.dart';
import 'reward_money_history_view.dart';
import 'journal_view.dart';
import 'journey_timeline_view.dart';
import 'motivation_motto_dashboard_view.dart';
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
  Timer? _scheduleClockTimer;
  DateTime _scheduleNow = DateTime.now();
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
    _scheduleClockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _scheduleNow = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleClockTimer?.cancel();
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

          return DefaultTabController(
            length: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                final content = Column(
                  children: [
                    _buildDashboardTabs(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _dashboardTabList([
                            _buildHeroCard(rankProfile, summary),
                            _buildProgressOverviewStrip(timeProgress),
                            _buildMottoHeroCard(),
                            _summaryHeader(summary),
                            _todayScheduleSection(todayTaskRows, todayProductivityStats),
                            _todayTasksSection(todayTaskRows),
                            _todaysProductivitySection(todayProductivityStats, todayTaskRows),
                            _instructionProductivitySection(today),
                          ]),
                          _dashboardTabList([
                            _buildFeatureLaunchCard(
                              icon: Icons.insert_chart_outlined_rounded,
                              title: 'Reports & Analytics',
                              subtitle: 'Progress now lives in its own sidebar page, keeping this tab focused on task analytics and productivity reports.',
                              actionLabel: 'Open Progress',
                              onTap: _openProgressScreen,
                            ),
                            _productivityAnalyticsCenter(
                              tasks: analyticsTasks,
                              statusCounts: statusCounts,
                              categoryCounts: categoryCounts,
                              priorityCounts: priorityCounts,
                              delegateCounts: delegatedAnalyticsCounts,
                            ),
                          ]),
                          _dashboardTabList([
                            _scopeTaskHeader(scopedTaskCounts),
                            _todayTasksSection(todayTaskRows),
                            _buildHabitRoutineSection(activeRoutineTasks),
                            _buildDisabledRoutineBoard(disabledRoutineTasks),
                            _taskInsightsFiltersSection(
                              items: taskInsightItems,
                              priorityOptions: priorityOptions,
                              delegateOptions: personOptions,
                              statusOptions: statusOptions,
                              categoryOptions: categoryOptions,
                            ),
                          ]),
                          _dashboardTabList([
                            _buildFeatureLaunchCard(
                              icon: Icons.flag_circle_rounded,
                              title: 'Goal Command Center',
                              subtitle: 'Open active goals, completed goals, progress galleries, saved money, deadlines, and timelines without changing goal logic.',
                              actionLabel: 'Open Goals',
                              onTap: _openGoalDashboard,
                            ),
                            _buildProjectsSection(nonRoutineDashboardTasks),
                          ]),
                          _dashboardTabList([
                            _buildFeatureLaunchCard(
                              icon: Icons.rule_folder_rounded,
                              title: 'Instruction Center',
                              subtitle: 'Manage standalone instructions, task instructions, selectable levels, and daily follow/miss tracking with the existing engine.',
                              actionLabel: 'Open Instructions',
                              onTap: _openInstructionDashboard,
                            ),
                            _instructionProductivitySection(today),
                          ]),
                          _dashboardTabList([
                            _buildFeatureLaunchCard(
                              icon: Icons.auto_graph_rounded,
                              title: 'Growth Timeline',
                              subtitle: 'Review journal, reflections, achievements, Points history, money history, streak records, and motivation.',
                              actionLabel: 'Open Timeline',
                              onTap: _openJourneyTimeline,
                            ),
                            _buildMottoHeroCard(),
                            _buildGrowthActionGrid(),
                          ]),
                        ],
                      ),
                    ),
                  ],
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 20 : 16, 10, 16, 18),
                  child: content,
                );
              },
            ),
          );
        },
      ),
    ),
    );
  }





  Widget _dashboardTabList(List<Widget> children) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemCount: children.length,
    );
  }

  Widget _buildDashboardTabs() {
    final style = _dashboardStyle();
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: style.primary.withOpacity(0.12))),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppThemeColors.readableTextOn(style.primary, style),
        unselectedLabelColor: style.textMuted,
        indicator: BoxDecoration(color: style.primary, borderRadius: BorderRadius.circular(16)),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'Overview'),
          Tab(icon: Icon(Icons.query_stats_rounded), text: 'Productivity'),
          Tab(icon: Icon(Icons.task_alt_rounded), text: 'Tasks'),
          Tab(icon: Icon(Icons.flag_rounded), text: 'Goals'),
          Tab(icon: Icon(Icons.rule_rounded), text: 'Instructions'),
          Tab(icon: Icon(Icons.trending_up_rounded), text: 'Growth'),
        ],
      ),
    );
  }

  Widget _buildModernSidebar(RankProfile profile) {
    final style = _dashboardStyle();
    final items = [
      (Icons.home_rounded, 'Dashboard', widget.onGoToDashboard ?? () {}),
      (Icons.task_alt_rounded, 'Tasks', _openProductivityTimeline),
      (Icons.repeat_rounded, 'Routine', _openProductivityTimeline),
      (Icons.rule_folder_rounded, 'Instructions', _openInstructionDashboard),
      (Icons.flag_circle_rounded, 'Goals', _openGoalDashboard),
      (Icons.account_balance_wallet_rounded, 'Money', _openRewardMoneyHistory),
      (Icons.lightbulb_rounded, 'Motivation', _openMotivationMottoDashboard),
      (Icons.insert_chart_outlined_rounded, 'Progress', _openProgressScreen),
      (Icons.analytics_rounded, 'Reports', _openProductivityTimeline),
      (Icons.settings_rounded, 'Settings', _openSettingsPanel),
    ];
    return Container(
      width: 230,
      margin: const EdgeInsets.fromLTRB(16, 10, 0, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: style.primary.withOpacity(0.14))),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Momentum', style: TextStyle(color: style.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(profile.currentRank.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: item.$3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  Icon(item.$1, color: style.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800))),
                ]),
              ),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _buildQuickStatsRibbon(Map<String, int> summary, Map<String, int> scopedCounts, RankProfile profile) {
    final cards = [
      _quickStatCard('Tasks', scopedCounts['Today'] ?? 0, Icons.task_alt_rounded, () => _showTaskListSheet('Today tasks', _dedupeTasksForDashboard(widget.hiveService.getAllTasksByDate().values.expand((list) => list).toList()))),
      _quickStatCard('Goals', summary['Completed'] ?? 0, Icons.flag_rounded, _openGoalDashboard),
      _quickStatCard('Coins', widget.hiveService.getRewardMoneySummary().availableRupees, Icons.paid_rounded, _openRewardMoneyHistory),
      _quickStatCard('Points', profile.xp, Icons.bolt_rounded, _openProductivityTimeline),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cards
            .map((card) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(width: 145, child: card),
                ))
            .toList(),
      ),
    );
  }

  Widget _quickStatCard(String label, int value, IconData icon, VoidCallback onTap) {
    final style = _dashboardStyle();
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: style.primary.withOpacity(0.13))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: style.primary), const SizedBox(height: 10), Text(_formatCompactNumber(value), style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800))]),
      ),
    );
  }

  Widget _buildFeatureLaunchCard({required IconData icon, required String title, required String subtitle, required String actionLabel, required VoidCallback onTap}) {
    final style = _dashboardStyle();
    return LayoutBuilder(
      builder: (context, constraints) {
        final leading = CircleAvatar(radius: 26, backgroundColor: style.primary.withOpacity(0.14), child: Icon(icon, color: style.primary));
        final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
        ]);
        final action = ElevatedButton(onPressed: onTap, child: Text(actionLabel, maxLines: 1, overflow: TextOverflow.ellipsis));
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: style.primary.withOpacity(0.14))),
          child: constraints.maxWidth < 520
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [leading, const SizedBox(width: 14), Expanded(child: copy)]),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: action),
                ])
              : Row(children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  Flexible(flex: 0, child: action),
                ]),
        );
      },
    );
  }

  Widget _buildGrowthActionGrid() {
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _growthButton(Icons.menu_book_rounded, 'Journal', _openJournal),
      _growthButton(Icons.timeline_rounded, 'Personal Timeline', _openJourneyTimeline),
      _growthButton(Icons.account_balance_wallet_rounded, 'Money History', _openRewardMoneyHistory),
      _growthButton(Icons.insights_rounded, 'Points & Analytics', _openProductivityTimeline),
    ]);
  }

  Widget _growthButton(IconData icon, String label, VoidCallback onTap) {
    final style = _dashboardStyle();
    return SizedBox(width: 210, child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, color: style.primary), label: Text(label), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: style.textPrimary, side: BorderSide(color: style.primary.withOpacity(0.22)))));
  }

  Widget _buildMottoHeroCard() {
    final motto = widget.hiveService.getFeaturedMotivationMotto();
    if (motto == null) return const SizedBox.shrink();
    final style = _dashboardStyle();
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _openMotivationMottoDashboard,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: style.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: style.secondary.withOpacity(0.24)),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: style.secondary.withOpacity(0.2), child: Icon(Icons.chat_bubble_outline_rounded, color: style.secondary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Today’s Motto:', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(toTitleCase(motto.quote), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
            ),
          ],
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
    Navigator.of(context)
        .push(
          JournalView.route(
            hiveService: widget.hiveService,
            onGoToDashboard: widget.onGoToDashboard,
          ),
        )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openSettingsPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close settings',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: FractionallySizedBox(
              widthFactor: MediaQuery.of(context).size.width < 760 ? 1 : 0.58,
              heightFactor: 1,
              child: _DashboardSettingsPanel(
                hiveService: widget.hiveService,
                onClose: () => Navigator.of(context).pop(),
                themeSelectorBuilder: (_) => _buildThemeSelector(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
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

  void _openProgressScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _buildProgressScreen(),
      ),
    );
  }




  void _openInstructionDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InstructionDashboardView(hiveService: widget.hiveService),
      ),
    );
  }

  void _openGoalDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GoalDashboardView(hiveService: widget.hiveService),
      ),
    );
  }

  void _openMotivationMottoDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MotivationMottoDashboardView(hiveService: widget.hiveService),
      ),
    );
  }

  void _openRewardMoneyHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RewardMoneyHistoryView(hiveService: widget.hiveService),
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


  void _openJournalForTask(Task task) {
    Navigator.of(context)
        .push(
          JournalView.route(
            hiveService: widget.hiveService,
            onGoToDashboard: widget.onGoToDashboard,
            initialDate: task.dueDate,
          ),
        )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _editTaskDetails(Task task) async {
    if (isDailyJournalSystemTask(task)) {
      _openJournalForTask(task);
      return;
    }

    final updated = await showTaskFormDialog(
      context,
      date: task.dueDate,
      initialTask: task,
      title: isRoutineTask(task) ? 'Edit Routine Details' : 'Update Task',
      actionLabel: isRoutineTask(task) ? 'Save Routine' : 'Save Task',
      onDelete: isRoutineTask(task) ? null : () => widget.hiveService.deleteTaskByReference(task),
    );

    if (updated == null) return;
    if (isRoutineTask(task)) {
      await widget.hiveService.updateRecurringTaskSeriesByReference(task, updated.copyWith(repeatTask: true));
    } else {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  Future<void> _openTodayTaskQuickOccurrence(_DashboardTodayTask row) async {
    final task = row.task;
    if (isDailyJournalSystemTask(task)) {
      await _showDailyJournalCompletionPrompt(
        task,
        message: 'Daily Journal is completed only by writing and saving your journal.',
      );
      return;
    }

    if (isRoutineTask(task) || hasTaskLinkedInstructions(widget.hiveService, task)) {
      await _editTask(task);
      return;
    }

    if (_isCompletedTask(task)) {
      await _showTodayTaskLockedMessage(
        '${task.task} is already completed today${_timeLabelForTask(task) == null ? '.' : ' at ${_timeLabelForTask(task)}.'}',
      );
      return;
    }

    if (task.status.trim().toLowerCase() == 'missed') {
      await _showTodayTaskLockedMessage(
        '${task.task} is already marked missed for today.',
        actionLabel: 'View Details',
        onAction: () => _editTaskDetails(task),
      );
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Have you done this task today?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(toTitleCase(task.task), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text('Complete'),
                onTap: () => Navigator.pop(context, 'complete'),
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                title: const Text('Missed'),
                onTap: () => Navigator.pop(context, 'missed'),
              ),
              if (isRoutineTask(task))
                ListTile(
                  leading: const Icon(Icons.pause_circle_outline),
                  title: const Text('Disable Routine'),
                  onTap: () => Navigator.pop(context, 'disable'),
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Close'),
                onTap: () => Navigator.pop(context, 'close'),
              ),
            ],
          ),
        ),
      ),
    );

    switch (action) {
      case 'complete':
        final completedAt = DateTime.now();
        final scheduleResult = _scheduleResultForCompletion(task, completedAt);
        await widget.hiveService.updateTaskByReference(
          task,
          task.copyWith(
            done: true,
            status: 'Completed',
            dueDate: DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day, completedAt.hour, completedAt.minute),
          ),
        );
        if (!mounted) return;
        if (scheduleResult != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(scheduleResult.message)),
          );
        }
        break;
      case 'missed':
        await widget.hiveService.updateTaskByReference(task, task.copyWith(done: false, status: 'Missed'));
        break;
      case 'disable':
        await widget.hiveService.setRecurringTaskEnabledByReference(task, false);
        break;
    }
  }

  Future<void> _showTodayTaskLockedMessage(String message, {String actionLabel = 'OK', VoidCallback? onAction}) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onAction?.call();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailyJournalCompletionPrompt(Task task, {required String message}) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📔 Daily Journal'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openJournalForTask(task);
            },
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Go To Journal'),
          ),
        ],
      ),
    );
  }

  _DashboardScheduleResult? _scheduleResultForCompletion(Task task, DateTime completedAt) {
    if (!task.repeatTask) return null;
    final schedule = _dashboardRoutineScheduleForTask(task);
    if (schedule == null) return null;
    var completedMinutes = completedAt.hour * 60 + completedAt.minute;
    final start = schedule.startMinutes;
    var end = schedule.endMinutes;
    if (end < start) {
      end += 24 * 60;
      if (completedMinutes < start) completedMinutes += 24 * 60;
    }
    final onTime = completedMinutes >= start && completedMinutes <= end;
    return _DashboardScheduleResult(
      onTime
          ? 'Completed on time! +${schedule.bonusPoints} bonus points earned.'
          : 'Task completed, but outside the scheduled time. No schedule bonus added.',
      onTime ? schedule.bonusPoints : 0,
    );
  }

  _DashboardRoutineSchedule? _dashboardRoutineScheduleForTask(Task task) {
    int? start;
    int? end;
    int? bonus;
    for (final line in task.description.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('⏰ Schedule Start:')) {
        start = _parseScheduleMinutes(trimmed.substring('⏰ Schedule Start:'.length).trim());
      } else if (trimmed.startsWith('⏰ Schedule End:')) {
        end = _parseScheduleMinutes(trimmed.substring('⏰ Schedule End:'.length).trim());
      } else if (trimmed.startsWith('⏰ Schedule Bonus:')) {
        bonus = int.tryParse(trimmed.substring('⏰ Schedule Bonus:'.length).replaceAll('points', '').trim());
      }
    }
    if (start == null || end == null) return null;
    return _DashboardRoutineSchedule(startMinutes: start, endMinutes: end, bonusPoints: bonus ?? 20);
  }

  int? _parseScheduleMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour * 60) + minute;
  }

  String? _timeLabelForTask(Task task) {
    if (task.dueDate.hour == 0 && task.dueDate.minute == 0 && task.hourSlot == null) return null;
    final hour = task.dueDate.hour;
    final minute = task.dueDate.minute.toString().padLeft(2, '0');
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$minute $period';
  }

  void _showTaskListSheet(String title, List<Task> tasks) {
    final style = _dashboardStyle();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${tasks.length} task${tasks.length == 1 ? '' : 's'}', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: tasks.isEmpty
                      ? const Center(child: Text('No tasks found for this filter.'))
                      : ListView.separated(
                          controller: scrollController,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return ListTile(
                              leading: CircleAvatar(backgroundColor: Color(task.colorValue).withOpacity(0.14), child: Icon(_isCompletedTask(task) ? Icons.check : Icons.task_alt, color: Color(task.colorValue))),
                              title: Text(toTitleCase(task.task), style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text(toTitleCaseMetadata([task.priority, task.status, _formatDueLabel(task)])),
                              trailing: Icon(_isCompletedTask(task) ? Icons.check_circle_outline : Icons.chevron_right, color: _isCompletedTask(task) ? Colors.green : style.primary),
                              onTap: () {
                                Navigator.pop(context);
                                if (isDailyJournalSystemTask(task)) {
                                  _showDailyJournalCompletionPrompt(
                                    task,
                                    message: _isCompletedTask(task)
                                        ? 'Daily Journal is completed only by writing and saving your journal.'
                                        : 'Write a journal to complete this task.',
                                  );
                                } else {
                                  _editTaskDetails(task);
                                }
                              },
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemCount: tasks.length,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTodayTaskOccurrenceSheet(String title, List<_DashboardTodayTask> rows) {
    final style = _dashboardStyle();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${rows.length} task${rows.length == 1 ? '' : 's'}', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text('No tasks found for this filter.'))
                      : ListView.separated(
                          controller: scrollController,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final task = row.task;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(task.colorValue).withOpacity(0.14),
                                child: Icon(_isCompletedTask(task) ? Icons.check : Icons.task_alt, color: Color(task.colorValue)),
                              ),
                              title: Text(toTitleCase(task.task), style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text(toTitleCaseMetadata([task.priority, row.displayStatus, _formatDueLabel(task)])),
                              trailing: Icon(isRoutineTask(task) || hasTaskLinkedInstructions(widget.hiveService, task) ? Icons.event_repeat_rounded : Icons.touch_app_rounded, color: style.primary),
                              onTap: () async {
                                Navigator.pop(context);
                                await _openTodayTaskQuickOccurrence(row);
                              },
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemCount: rows.length,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStandaloneInstructionActions(InstructionRule instruction, DateTime today) async {
    if (instruction.isTaskLinked) {
      await _showTodayTaskLockedMessage('This instruction is linked to a task. Update it from the related task occurrence.');
      return;
    }

    final entry = widget.hiveService.instructionEntryForDate(instruction, today);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(toTitleCase(instruction.name), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(entry == null
                      ? (instruction.description.trim().isEmpty ? 'Choose Complete or Missed for today.' : instruction.description.trim())
                      : 'This instruction is already updated today.'),
                ),
                if (entry == null && instruction.enabled) ...[
                  if (instruction.isOptionBased) ...[
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: const Text('Complete'),
                      subtitle: const Text('Select one or more instruction options'),
                      onTap: () => Navigator.pop(context, 'options'),
                    ),
                    ListTile(leading: const Icon(Icons.cancel_outlined, color: Colors.red), title: const Text('Missed'), onTap: () => Navigator.pop(context, 'missed')),
                  ] else if (instruction.isLevelBased) ...[
                    ListTile(
                      leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                      title: const Text('Missed'),
                      onTap: () => Navigator.pop(context, 'missed'),
                    ),
                    ...instruction.levels.map((level) => ListTile(
                          leading: const Icon(Icons.emoji_events_outlined, color: Colors.green),
                          title: Text('${level.displayLabel} (+${level.bonusPoints})'),
                          subtitle: Text('${level.pointsEarned} Points'),
                          onTap: () => Navigator.pop(context, 'level:${level.id}'),
                        )),
                  ] else ...[
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: const Text('Followed'),
                      onTap: () => Navigator.pop(context, 'followed'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                      title: const Text('Missed'),
                      onTap: () => Navigator.pop(context, 'missed'),
                    ),
                  ],
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('This instruction is already updated today.', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                  ),
                ListTile(
                  leading: Icon(instruction.enabled ? Icons.pause_circle_outline : Icons.play_circle_outline),
                  title: Text(instruction.enabled ? 'Disable Instruction' : 'Enable Instruction'),
                  onTap: () => Navigator.pop(context, 'toggle'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Close'),
                  onTap: () => Navigator.pop(context, 'close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null || action == 'close') return;
    if (action == 'options' && instruction.options.isNotEmpty) {
      final selected = await _showInstructionOptionsCompletionDialog(instruction);
      if (selected == null) return;
      await widget.hiveService.updateInstructionStatus(
        instruction,
        today,
        selected.isEmpty ? InstructionHistoryEntry.statusMissed : InstructionHistoryEntry.statusFollowed,
        options: selected,
      );
      return;
    }
    if (action.startsWith('level:') && instruction.levels.isNotEmpty) {
      final levelId = action.substring('level:'.length);
      final level = instruction.levels.firstWhere((item) => item.id == levelId, orElse: () => instruction.levels.first);
      await widget.hiveService.updateInstructionStatus(instruction, today, InstructionHistoryEntry.statusFollowed, level: level);
      return;
    }
    switch (action) {
      case 'followed':
        await widget.hiveService.updateInstructionStatus(instruction, today, InstructionHistoryEntry.statusFollowed);
        break;
      case 'missed':
        await widget.hiveService.updateInstructionStatus(instruction, today, InstructionHistoryEntry.statusMissed);
        break;
      case 'toggle':
        await widget.hiveService.setInstructionEnabled(instruction, !instruction.enabled);
        break;
    }
  }


  Future<List<InstructionOption>?> _showInstructionOptionsCompletionDialog(InstructionRule instruction) async {
    final selectedIds = <String>{};
    return showDialog<List<InstructionOption>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(toTitleCase(instruction.name)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (instruction.description.trim().isNotEmpty) ...[
                    Text(instruction.description.trim(), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                    const SizedBox(height: 10),
                  ],
                  ...instruction.options.map((option) {
                    final checked = selectedIds.contains(option.id);
                    return CheckboxListTile(
                      value: checked,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${option.name} +${option.bonusPoints} ${option.emoji}'),
                      subtitle: Text('${option.pointsEarned} Points${option.description.isEmpty ? '' : ' • ${option.description}'}'),
                      onChanged: (value) => setDialogState(() {
                        if (value == true) {
                          selectedIds.add(option.id);
                        } else {
                          selectedIds.remove(option.id);
                        }
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, const <InstructionOption>[]), child: const Text('Missed')),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                instruction.options.where((option) => selectedIds.contains(option.id)).toList(),
              ),
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInstructionFilterSheet(String title, List<InstructionRule> instructions, DateTime today) {
    final style = _dashboardStyle();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (instructions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No instructions found for this filter.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: instructions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final instruction = instructions[index];
                      final entry = widget.hiveService.instructionEntryForDate(instruction, today);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(instruction.colorValue).withOpacity(0.14),
                          child: Icon(Icons.rule_folder_outlined, color: Color(instruction.colorValue)),
                        ),
                        title: Text(toTitleCase(instruction.name), style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(toTitleCaseMetadata([instruction.repeatType, entry?.status ?? 'Pending'])),
                        trailing: Text('+${instruction.bonusPoints}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
                        onTap: () {
                          Navigator.pop(context);
                          _showStandaloneInstructionActions(instruction, today);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_DashboardTodayTask> _todayRowsForFilter(List<_DashboardTodayTask> rows, String filter) {
    switch (filter) {
      case 'completed':
        return rows.where((row) => row.group == _TodayTaskGroup.completed).toList();
      case 'pending':
        return rows.where((row) => row.group == _TodayTaskGroup.pending).toList();
      case 'overdue':
        return rows.where((row) => row.group == _TodayTaskGroup.overdue).toList();
      default:
        return rows;
    }
  }

  List<Task> _analyticsTasksForFilter(List<Task> tasks, String filter) {
    final today = _dateOnly(DateTime.now());
    switch (filter) {
      case 'completed':
        return tasks.where(_isCompletedTask).toList();
      case 'pending':
        return tasks.where(_isPendingTask).toList();
      case 'overdue':
        return tasks.where((task) => _dateOnly(task.dueDate).isBefore(today) && _isPendingTask(task)).toList();
      default:
        return tasks;
    }
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

  List<_TodayScheduleEntry> _buildTodayScheduleEntries(List<_DashboardTodayTask> rows, DateTime now) {
    final taskEntries = <_TodayScheduleEntry>[];
    for (final row in rows) {
      if (row.group == _TodayTaskGroup.overdue && !_isSameDay(_dateOnly(row.task.dueDate), _dateOnly(now))) continue;
      final range = _scheduleRangeForTask(row.task);
      if (range == null) continue;
      taskEntries.add(_TodayScheduleEntry(startMinutes: range.start, endMinutes: range.end, taskRow: row));
    }
    taskEntries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final entries = <_TodayScheduleEntry>[];
    var cursor = 8 * 60;
    final dayEnd = math.max(18 * 60, taskEntries.isEmpty ? 18 * 60 : taskEntries.map((entry) => entry.endMinutes).reduce(math.max));
    for (final taskEntry in taskEntries) {
      if (taskEntry.startMinutes > cursor) {
        entries.add(_TodayScheduleEntry(startMinutes: cursor, endMinutes: taskEntry.startMinutes));
      }
      entries.add(taskEntry);
      cursor = math.max(cursor, taskEntry.endMinutes);
    }
    if (cursor < dayEnd) entries.add(_TodayScheduleEntry(startMinutes: cursor, endMinutes: dayEnd));
    return entries;
  }

  _ScheduleRange? _scheduleRangeForTask(Task task) {
    final routineSchedule = _dashboardRoutineScheduleForTask(task);
    if (routineSchedule == null) return null;
    return _ScheduleRange(start: routineSchedule.startMinutes, end: routineSchedule.endMinutes);
  }

  _TodayScheduleState _scheduleStateFor(_DashboardTodayTask row, _TodayScheduleEntry entry, DateTime now) {
    final status = row.task.status.trim().toLowerCase();
    if (_isCompletedTask(row.task)) return _TodayScheduleState.completed;
    if (status == 'missed') return _TodayScheduleState.missed;
    final nowMinutes = now.hour * 60 + now.minute;
    if (nowMinutes >= entry.startMinutes && nowMinutes < entry.endMinutes) return _TodayScheduleState.active;
    if (nowMinutes >= entry.endMinutes || row.group == _TodayTaskGroup.overdue) return _TodayScheduleState.overdue;
    if (nowMinutes < entry.startMinutes) return _TodayScheduleState.upcoming;
    return _TodayScheduleState.pending;
  }

  Color _scheduleStateColor(_TodayScheduleState state, AppThemeColors theme) {
    switch (state) {
      case _TodayScheduleState.completed:
        return theme.success;
      case _TodayScheduleState.active:
        return theme.accent;
      case _TodayScheduleState.pending:
        return theme.warning;
      case _TodayScheduleState.overdue:
      case _TodayScheduleState.missed:
        return theme.danger;
      case _TodayScheduleState.upcoming:
        return theme.cardTint;
    }
  }

  String _scheduleStateLabel(_TodayScheduleState state) {
    switch (state) {
      case _TodayScheduleState.completed:
        return 'Completed';
      case _TodayScheduleState.active:
        return 'Active';
      case _TodayScheduleState.pending:
        return 'Pending';
      case _TodayScheduleState.overdue:
        return 'Overdue';
      case _TodayScheduleState.upcoming:
        return 'Upcoming';
      case _TodayScheduleState.missed:
        return 'Missed';
    }
  }

  String _formatScheduleTime(int minutes) {
    final normalized = minutes.clamp(0, 24 * 60).toInt();
    final hour = (normalized ~/ 60) % 24;
    final minute = normalized % 60;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return minute == 0 ? '$displayHour $period' : '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  List<_PositionedTodayScheduleEntry> _positionOverlappingTodayEntries(List<_TodayScheduleEntry> entries) {
    final positioned = <_PositionedTodayScheduleEntry>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final overlappingIndexes = <int>[];
      for (var j = 0; j < entries.length; j++) {
        final other = entries[j];
        if (entry.startMinutes < other.endMinutes && other.startMinutes < entry.endMinutes) {
          overlappingIndexes.add(j);
        }
      }
      final columnCount = overlappingIndexes.length.clamp(1, 4).toInt();
      final column = overlappingIndexes.indexOf(i).clamp(0, columnCount - 1).toInt();
      positioned.add(_PositionedTodayScheduleEntry(entry: entry, column: column, columnCount: columnCount));
    }
    return positioned;
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

  List<InstructionRule> _linkedInstructionsForRoutine(Task task) {
    return widget.hiveService
        .getTaskLinkedInstructions()
        .where((instruction) => instruction.enabled && instruction.isLinkedToTask(task.task))
        .toList();
  }

  _RoutineMood _routineMoodForTask(Task task) {
    final linkedInstructions = _linkedInstructionsForRoutine(task);
    final missedCount = _routineConsecutiveMisses(task);
    if (missedCount > 0) return _missedRoutineMood(missedCount);

    final completed = _isCompletedTask(task);
    if (!completed) {
      return const _RoutineMood(emoji: '😐', label: 'Neutral', detail: 'Pending occurrence', score: 40);
    }

    if (linkedInstructions.isEmpty) {
      return const _RoutineMood(emoji: '😐', label: 'Neutral', detail: 'No instructions attached', score: 50);
    }

    final followed = linkedInstructions.where((instruction) {
      return widget.hiveService.instructionEntryForDate(instruction, task.dueDate)?.followed ?? false;
    }).length;
    final ratio = followed / linkedInstructions.length;
    final streak = _routineCurrentStreak(task);
    final score = (60 + (ratio * 30) + (math.min(streak, 10) / 10 * 10)).round().clamp(0, 100).toInt();
    return _routineMoodFromScore(
      score,
      detail: '$followed/${linkedInstructions.length} instructions',
    );
  }

  _RoutineMood _missedRoutineMood(int misses) {
    if (misses >= 7) return _RoutineMood(emoji: '😵', label: 'Burned Out', detail: 'Missed $misses consecutive occurrences', score: 0);
    if (misses >= 4) return _RoutineMood(emoji: '😫', label: 'Exhausted', detail: 'Missed $misses consecutive occurrences', score: 0);
    if (misses >= 2) return _RoutineMood(emoji: '😠', label: 'Angry', detail: 'Missed $misses consecutive occurrences', score: 0);
    return const _RoutineMood(emoji: '😞', label: 'Sad', detail: 'Missed today', score: 0);
  }

  _RoutineMood _routineMoodFromScore(int score, {required String detail}) {
    if (score >= 90) return _RoutineMood(emoji: '🤩', label: 'Excellent', detail: detail, score: score);
    if (score >= 75) return _RoutineMood(emoji: '😄', label: 'Happy', detail: detail, score: score);
    if (score >= 60) return _RoutineMood(emoji: '🙂', label: 'Good', detail: detail, score: score);
    if (score >= 40) return _RoutineMood(emoji: '😐', label: 'Neutral', detail: detail, score: score);
    if (score >= 20) return _RoutineMood(emoji: '😕', label: 'Concerned', detail: detail, score: score);
    return _RoutineMood(emoji: '😞', label: 'Sad', detail: detail, score: score);
  }

  int _routineConsecutiveMisses(Task task) {
    final frequency = _normalizedRepeatFrequency(task);
    if (!['daily', 'weekly', 'monthly', 'yearly'].contains(frequency)) return 0;
    final occurrences = <DateTime, Task>{};
    for (final candidate in widget.hiveService.getAllTasksByDate().values.expand((list) => list)) {
      if (!_isSameRoutineSeries(candidate, task)) continue;
      final occurrence = _routineOccurrenceDateFor(candidate, _dateOnly(candidate.dueDate));
      occurrences[occurrence] = candidate;
    }

    var cursor = _routineOccurrenceDateFor(task, _dateOnly(DateTime.now()));
    var misses = 0;
    while (true) {
      final occurrenceTask = occurrences[cursor];
      if (occurrenceTask == null || _isCompletedTask(occurrenceTask)) break;
      final status = occurrenceTask.status.trim().toLowerCase();
      if (status == 'missed' || status == 'overdue' || status == 'cancelled') {
        misses++;
        final previous = _previousRoutineOccurrenceForFrequency(frequency, cursor);
        if (previous == null) break;
        cursor = previous;
      } else {
        break;
      }
    }
    return misses;
  }

  int _routineCurrentStreak(Task task) {
    final frequency = _normalizedRepeatFrequency(task);
    if (!['daily', 'weekly', 'monthly', 'yearly'].contains(frequency)) return 0;

    final completedOccurrences = <DateTime>{};
    for (final candidate in widget.hiveService.getAllTasksByDate().values.expand((list) => list)) {
      if (!_isSameRoutineSeries(candidate, task) || !_isCompletedTask(candidate)) continue;
      final occurrence = _routineOccurrenceDateFor(candidate, _dateOnly(candidate.dueDate));
      completedOccurrences.add(occurrence);
    }

    final todayOccurrence = _routineOccurrenceDateFor(task, _dateOnly(DateTime.now()));
    var cursor = completedOccurrences.contains(todayOccurrence)
        ? todayOccurrence
        : _previousRoutineOccurrenceForFrequency(frequency, todayOccurrence);

    var streak = 0;
    while (cursor != null && completedOccurrences.contains(cursor)) {
      streak++;
      cursor = _previousRoutineOccurrenceForFrequency(frequency, cursor);
    }
    return streak;
  }

  bool _isSameRoutineSeries(Task a, Task b) {
    return a.repeatTask &&
        b.repeatTask &&
        a.task.trim().toLowerCase() == b.task.trim().toLowerCase() &&
        a.category.trim().toLowerCase() == b.category.trim().toLowerCase() &&
        _normalizedRepeatFrequency(a) == _normalizedRepeatFrequency(b);
  }

  DateTime _routineOccurrenceDateFor(Task task, DateTime date) {
    switch (_normalizedRepeatFrequency(task)) {
      case 'weekly':
        return date.subtract(Duration(days: date.weekday - 1));
      case 'monthly':
        return DateTime(date.year, date.month, 1);
      case 'yearly':
        return DateTime(date.year, 1, 1);
      case 'daily':
      default:
        return date;
    }
  }

  DateTime? _previousRoutineOccurrenceForFrequency(String frequency, DateTime occurrence) {
    switch (frequency) {
      case 'daily':
        return occurrence.subtract(const Duration(days: 1));
      case 'weekly':
        return occurrence.subtract(const Duration(days: 7));
      case 'monthly':
        return DateTime(occurrence.year, occurrence.month - 1, 1);
      case 'yearly':
        return DateTime(occurrence.year - 1, 1, 1);
      default:
        return null;
    }
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

  AppThemeColors _dashboardThemeColors() => AppThemeColors.fromDashboardStyle(_dashboardStyle());

  Color _dashboardThemeTaskColor(int storedColorValue) {
    final theme = _dashboardThemeColors();
    final colors = <Color>[
      theme.primary,
      theme.secondary,
      theme.accent,
      theme.success,
      theme.warning,
      theme.danger,
      theme.primarySoft,
    ];
    const legacyTaskColors = <int>[
      0xFFFFC107,
      0xFF43A047,
      0xFF1E88E5,
      0xFFE53935,
      0xFF7E57C2,
      0xFFFF8F00,
      0xFFE91E63,
    ];
    final legacyIndex = legacyTaskColors.indexOf(storedColorValue);
    final index = legacyIndex >= 0 ? legacyIndex : storedColorValue.abs() % colors.length;
    return colors[index % colors.length];
  }

  Color _routineMoodColor(_RoutineMood mood, AppThemeColors theme) {
    if (mood.score >= 75) return theme.success;
    if (mood.score >= 60) return theme.accent;
    if (mood.score >= 40) return theme.warning;
    if (mood.score >= 20) return Color.lerp(theme.warning, theme.danger, 0.35) ?? theme.warning;
    return theme.danger;
  }

  String _formatShortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String _formatCompactNumber(int value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return '$value';
  }

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
    final avatar = ProfileAvatar(
      profile: widget.hiveService.getUserProfile(),
      radius: 22,
      accentColor: style.primary,
      showGlow: false,
      onTap: _openProductivityTimeline,
    );
    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${profile.username}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: style.textPrimary),
        ),
        const SizedBox(height: 2),
        Text('Focus. Plan. Achieve.', style: TextStyle(color: style.textMuted)),
      ],
    );
    final actions = <Widget>[
      _headerActionButton(
        icon: Icons.notifications_none_rounded,
        tooltip: 'Notifications',
        style: style,
        onTap: _openJournal,
      ),
      _instructionHeaderButton(style),
      _goalHeaderButton(style),
      _mottoHeaderButton(style),
      _rewardMoneyBadge(style),
      _headerActionButton(
        icon: Icons.settings_rounded,
        tooltip: 'Dashboard settings',
        style: style,
        onTap: _openSettingsPanel,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: greeting),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      actions[index],
                    ],
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: greeting),
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              actions[index],
            ],
          ],
        );
      },
    );
  }


  Widget _instructionHeaderButton(DashboardThemeStyle style) {
    return _headerActionButton(
      icon: Icons.menu_book_rounded,
      tooltip: 'Instruction dashboard',
      style: style,
      onTap: _openInstructionDashboard,
    );
  }


  Widget _goalHeaderButton(DashboardThemeStyle style) {
    return _headerActionButton(
      icon: Icons.flag_circle_outlined,
      tooltip: 'Goal dashboard',
      style: style,
      onTap: _openGoalDashboard,
    );
  }


  Widget _mottoHeaderButton(DashboardThemeStyle style) {
    return _headerActionButton(
      icon: Icons.chat_bubble_outline_rounded,
      tooltip: 'Motivation Motto',
      style: style,
      onTap: _openMotivationMottoDashboard,
    );
  }


  Color _headerTabBackground(DashboardThemeStyle style) {
    return Color.lerp(style.surface, style.primary, style.dark ? 0.18 : 0.10) ?? style.surface;
  }

  BoxShadow _headerTabShadow(DashboardThemeStyle style) {
    return BoxShadow(
      color: style.primary.withOpacity(style.dark ? 0.22 : 0.12),
      blurRadius: 10,
      offset: const Offset(0, 6),
    );
  }

  Widget _rewardMoneyBadge(DashboardThemeStyle style) {
    final rewardSummary = widget.hiveService.getRewardMoneySummary();
    return Tooltip(
      message: 'Reward money history',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openRewardMoneyHistory,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _headerTabBackground(style),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: style.primary.withOpacity(0.22)),
              boxShadow: [_headerTabShadow(style)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: style.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  '₹${_formatCompactNumber(rewardSummary.availableRupees)}',
                  style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _headerActionButton({
    required IconData icon,
    required String tooltip,
    required DashboardThemeStyle style,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _headerTabBackground(style),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: style.primary.withOpacity(0.22)),
              boxShadow: [_headerTabShadow(style)],
            ),
            child: Icon(icon, color: style.primary, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    final style = _dashboardStyle();
    final selectedTheme = widget.hiveService.getDashboardTheme();
    final selectedPalette = widget.hiveService.getDashboardPalette();
    final selectedFont = widget.hiveService.getAppFontFamily();
    final selectedScale = widget.hiveService.getAppFontScale();
    final selectedWeight = widget.hiveService.getAppFontWeight();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.primary.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: style.primary.withOpacity(style.dark ? 0.18 : 0.08), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: style.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Dashboard Theme', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 4),
          Text('${selectedTheme.label} • ${selectedPalette.label}', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DashboardThemeType.values.map((theme) {
                final isSelected = theme == selectedTheme;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ThemeSettingTab(
                    selected: isSelected,
                    label: theme.label,
                    icon: _themeIcon(theme),
                    theme: style,
                    onTap: () => widget.hiveService.setDashboardTheme(theme),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text('Color Palette', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _paletteSelectorGrid(
            style: style,
            selectedPalette: selectedPalette,
          ),
          const SizedBox(height: 14),
          _buildTypographySelector(
            style: style,
            selectedFont: selectedFont,
            selectedScale: selectedScale,
            selectedWeight: selectedWeight,
          ),
          const SizedBox(height: 8),
          Text(
            '${selectedTheme.description} • ${selectedPalette.label} palette • ${selectedFont.familyName} typography applied app-wide.',
            style: TextStyle(color: style.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }



  Widget _paletteSelectorGrid({
    required DashboardThemeStyle style,
    required DashboardPaletteType selectedPalette,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final crossAxisCount = availableWidth >= 620
            ? 4
            : availableWidth >= 430
                ? 3
                : 2;
        final spacing = 10.0;
        final tileWidth = (availableWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Wrap(
            key: ValueKey(selectedPalette.storageKey),
            spacing: spacing,
            runSpacing: spacing,
            children: dashboardThemePickerPalettes.map((palette) {
              final isSelected = palette == selectedPalette;
              return SizedBox(
                width: tileWidth.clamp(132.0, 220.0).toDouble(),
                child: _paletteSelectorTile(
                  palette: palette,
                  selected: isSelected,
                  style: style,
                  onTap: () => widget.hiveService.setDashboardPalette(palette),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _paletteSelectorTile({
    required DashboardPaletteType palette,
    required bool selected,
    required DashboardThemeStyle style,
    required VoidCallback onTap,
  }) {
    final theme = AppThemeColors.fromDashboardStyle(style);
    final background = selected ? style.selectedTabBg : style.unselectedTabBg;
    final borderColor = selected ? style.primary : style.tabBorder;
    final textColor = selected ? style.selectedTabText : style.unselectedTabText;
    final recommendation = _paletteRecommendation(palette);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
            boxShadow: [
              BoxShadow(
                color: selected ? style.primary.withOpacity(0.20) : theme.shadow.withOpacity(0.22),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _paletteDots(palette, compact: false)),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.check_circle_rounded, size: 18, color: style.selectedTabText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                palette.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 12.5, height: 1.05),
              ),
              if (recommendation != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accent.withOpacity(style.dark ? 0.20 : 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.accent.withOpacity(0.28)),
                  ),
                  child: Text(
                    recommendation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.accent, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _paletteRecommendation(DashboardPaletteType palette) {
    switch (palette) {
      case DashboardPaletteType.earthyForestHues:
        return 'Calm app';
      case DashboardPaletteType.refreshingSummerFun:
        return 'Eye-catching';
      case DashboardPaletteType.vividNightfall:
        return 'Premium';
      case DashboardPaletteType.aquaFocus:
        return 'Focused';
      case DashboardPaletteType.fieryOcean:
        return 'Bold';
      case DashboardPaletteType.oliveGardenFeast:
        return 'Journal';
      default:
        return null;
    }
  }

  Widget _paletteDots(DashboardPaletteType palette, {bool compact = false}) {
    final size = compact ? 5.0 : 12.0;
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: palette.colors
          .map((color) => Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppThemeColors.fromDashboardStyle(_dashboardStyle()).border),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTypographySelector({
    required DashboardThemeStyle style,
    required AppFontFamily selectedFont,
    required AppFontScale selectedScale,
    required AppFontWeightChoice selectedWeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.text_fields_rounded, color: style.primary, size: 18),
            const SizedBox(width: 8),
            Text('Typography', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${selectedFont.familyName} • ${selectedScale.label} • ${selectedWeight.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AppFontFamily.values.map((font) {
              final isSelected = font == selectedFont;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _fontChoiceCard(
                  font: font,
                  selected: isSelected,
                  style: style,
                  scale: selectedScale,
                  weight: selectedWeight,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Text('Font Size', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AppFontScale.values.map((scale) {
              final isSelected = scale == selectedScale;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ThemeSettingTab(
                  selected: isSelected,
                  label: scale.label,
                  theme: style,
                  onTap: () => widget.hiveService.setAppFontScale(scale),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Text('Font Weight', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AppFontWeightChoice.values.map((weight) {
              final isSelected = weight == selectedWeight;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ThemeSettingTab(
                  selected: isSelected,
                  label: weight.label,
                  theme: style,
                  onTap: () => widget.hiveService.setAppFontWeight(weight),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppThemeColors.fromDashboardStyle(style).card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppThemeColors.fromDashboardStyle(style).border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The quick brown fox jumps over the lazy dog.',
                style: _fontPreviewStyle(selectedFont, style, selectedScale, selectedWeight, size: 13),
              ),
              const SizedBox(height: 5),
              Text(
                'Small Wins. Massive Progress.',
                style: _fontPreviewStyle(selectedFont, style, selectedScale, selectedWeight, size: 16, heading: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fontChoiceCard({
    required AppFontFamily font,
    required bool selected,
    required DashboardThemeStyle style,
    required AppFontScale scale,
    required AppFontWeightChoice weight,
  }) {
    final cardColor = selected ? style.primary : (style.cardTint ?? style.elevatedSurface).withOpacity(0.50);
    final foreground = selected ? style.selectedTabText : style.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.hiveService.setAppFontFamily(font),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? style.primary : style.primary.withOpacity(0.20), width: selected ? 1.5 : 1),
            boxShadow: selected
                ? [BoxShadow(color: style.primary.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 8))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Aa', style: _fontPreviewStyle(font, style, scale, weight, size: 18, heading: true, color: foreground)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(font.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _fontPreviewStyle(font, style, scale, weight, size: 13, heading: true, color: foreground)),
                        Text(font.familyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _fontPreviewStyle(font, style, scale, weight, size: 11, color: foreground.withOpacity(0.75))),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, color: foreground, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Small Wins. Massive Progress.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _fontPreviewStyle(font, style, scale, weight, size: 12, color: foreground),
              ),
              const SizedBox(height: 4),
              Text(
                font.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground.withOpacity(0.72), fontSize: 10.5, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _fontPreviewStyle(
    AppFontFamily font,
    DashboardThemeStyle style,
    AppFontScale scale,
    AppFontWeightChoice weight, {
    required double size,
    bool heading = false,
    Color? color,
  }) {
    final textStyle = TextStyle(
      color: color ?? style.textPrimary,
      fontSize: size * scale.scale,
      fontWeight: heading ? _strongerPreviewWeight(weight.weight, 2) : weight.weight,
      letterSpacing: heading && style.type == DashboardThemeType.minimal ? 0.4 : 0,
      height: 1.18,
    );
    switch (font) {
      case AppFontFamily.modern:
        return GoogleFonts.inter(textStyle: textStyle);
      case AppFontFamily.elegant:
        return GoogleFonts.poppins(textStyle: textStyle);
      case AppFontFamily.minimal:
        return GoogleFonts.manrope(textStyle: textStyle);
      case AppFontFamily.friendly:
        return GoogleFonts.nunito(textStyle: textStyle);
      case AppFontFamily.professional:
        return GoogleFonts.roboto(textStyle: textStyle);
      case AppFontFamily.premium:
        return GoogleFonts.outfit(textStyle: textStyle);
      case AppFontFamily.classic:
        return GoogleFonts.lato(textStyle: textStyle);
      case AppFontFamily.reading:
        return GoogleFonts.merriweather(textStyle: textStyle);
      case AppFontFamily.rounded:
        return GoogleFonts.quicksand(textStyle: textStyle);
      case AppFontFamily.tech:
        return GoogleFonts.spaceGrotesk(textStyle: textStyle);
      case AppFontFamily.luxury:
        return GoogleFonts.plusJakartaSans(textStyle: textStyle);
      case AppFontFamily.futuristic:
        return GoogleFonts.sora(textStyle: textStyle);
    }
  }

  FontWeight _strongerPreviewWeight(FontWeight weight, int steps) {
    final nextIndex = (weight.index + steps).clamp(0, FontWeight.values.length - 1).toInt();
    return FontWeight.values[nextIndex];
  }



  Color _readableOn(Color color) {
    return AppThemeColors.readableTextOn(color, _dashboardStyle());
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
    final rewardSummary = widget.hiveService.getRewardMoneySummary();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final identity = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${profile.currentRank.name} ${profile.currentRank.emoji}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'Combined dashboard summary',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Color(0xFFD9D9FF)),
                                    ),
                                  ],
                                );
                                final streak = Column(
                                  crossAxisAlignment: constraints.maxWidth < 360 ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'All totals',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                    const Text('No duplicate cards', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFD9D9FF))),
                                  ],
                                );
                                final avatar = ProfileAvatar(
                                  profile: widget.hiveService.getUserProfile(),
                                  radius: constraints.maxWidth < 180 ? 18 : 26,
                                  accentColor: const Color(0xFFFFD86D),
                                  badge: profile.currentRank.emoji,
                                  onTap: _openProductivityTimeline,
                                );
                                if (constraints.maxWidth < 140) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      avatar,
                                      const SizedBox(height: 8),
                                      identity,
                                      const SizedBox(height: 8),
                                      streak,
                                    ],
                                  );
                                }
                                if (constraints.maxWidth < 360) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [avatar, const SizedBox(width: 10), Expanded(child: identity)]),
                                      const SizedBox(height: 8),
                                      streak,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    avatar,
                                    const SizedBox(width: 12),
                                    Expanded(child: identity),
                                    const SizedBox(width: 12),
                                    Flexible(flex: 0, child: streak),
                                  ],
                                );
                              },
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
                              runSpacing: 10,
                              children: [
                                _heroMetric('Level', '${profile.level}'),
                                _heroMetric('Points', _formatCompactNumber(profile.points)),
                                _heroMetric('Money', '₹${_formatCompactNumber(rewardSummary.availableRupees)}'),
                                _heroMetric('Streak', '${profile.activeStreak} days'),
                                _heroMetric('Today Tasks', '${summary["TODAY'S TASKS"] ?? 0}'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
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
                                  const SizedBox(width: 10),
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
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => setState(() => _showDetails = !_showDetails),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.stars_rounded, color: Color(0xFFFFD86D), size: 16),
                                    const SizedBox(width: 6),
                                    Text(_showDetails ? 'Hide details' : 'Show details', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
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
                                          Expanded(child: _heroMetric('Score', '${profile.productivityScore}%')),
                                          Expanded(child: _heroMetric('Active Days', '${profile.totalActiveDays}')),
                                          Expanded(child: _heroMetric('Journals', '${profile.journalEntries}')),
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
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 420 + (cards.indexOf(label) * 180)),
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
                ),
                child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openProgressScreen,
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
              ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }



  Widget _buildProgressScreen() {
    final style = _dashboardStyle();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yearProgress = _buildYearProgress(todayStart);
    final timeProgress = _buildTimeProgress(now);
    return Scaffold(
      backgroundColor: style.background,
      appBar: AppBar(
        title: const Text('Progress'),
        backgroundColor: style.surface,
        foregroundColor: style.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: style.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: style.primary.withOpacity(0.14)),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppThemeColors.readableTextOn(style.primary, style),
                    unselectedLabelColor: style.textMuted,
                    indicator: BoxDecoration(color: style.primary, borderRadius: BorderRadius.circular(14)),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Year'),
                      Tab(text: 'Month'),
                      Tab(text: 'Week'),
                      Tab(text: 'Time'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    children: [
                      _progressTabList([_yearProgressDetailCard(yearProgress, todayStart)]),
                      _progressTabList([_monthProgressDetailCard(timeProgress['Month']!, now)]),
                      _progressTabList([_weekProgressDetailCard(timeProgress['Week']!, now)]),
                      _progressTabList([_timeProgressSection(timeProgress)]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressTabList(List<Widget> children) {
    return ListView.separated(
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemCount: children.length,
    );
  }

  Widget _yearProgressDetailCard(Map<String, int> progress, DateTime todayStart) {
    final style = _dashboardStyle();
    final percent = progress['progressPercent'] ?? 0;
    final total = progress['totalDays'] ?? 365;
    final passed = progress['daysPassed'] ?? 0;
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return _progressDetailCard(
      icon: Icons.calendar_month_rounded,
      title: 'Year Progress',
      percent: percent,
      passedLabel: '$passed days passed',
      remainingLabel: '${progress['daysRemaining'] ?? 0} days left',
      color: style.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: monthNames.map((month) {
                final selected = monthNames.indexOf(month) == todayStart.month - 1;
                return Container(
                  margin: const EdgeInsets.only(right: 18),
                  child: Text(month, style: TextStyle(color: selected ? style.primary : style.textPrimary, fontWeight: FontWeight.w900)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(total, (index) {
              final day = index + 1;
              final isToday = day == passed;
              final isPassed = day < passed;
              return _progressBubble(
                '$day',
                isToday ? Colors.orange : isPassed ? style.primary : style.elevatedSurface,
                isToday || isPassed ? AppThemeColors.readableTextOn(isToday ? Colors.orange : style.primary, style) : style.textMuted,
                size: 26,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _monthProgressDetailCard(Map<String, int> progress, DateTime now) {
    final style = _dashboardStyle();
    final total = progress['total'] ?? 31;
    final passed = progress['passed'] ?? now.day;
    return _progressDetailCard(
      icon: Icons.calendar_view_month_rounded,
      title: 'Month Progress',
      percent: progress['percent'] ?? 0,
      passedLabel: '$passed days passed',
      remainingLabel: '${progress['remaining'] ?? 0} days left',
      color: style.secondary,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(total, (index) {
          final day = index + 1;
          final isToday = day == now.day;
          final isPassed = day < now.day;
          return _progressBubble(
            '$day',
            isToday ? Colors.orange : isPassed ? style.secondary : style.elevatedSurface,
            isToday || isPassed ? AppThemeColors.readableTextOn(isToday ? Colors.orange : style.secondary, style) : style.textMuted,
            size: 34,
          );
        }),
      ),
    );
  }

  Widget _weekProgressDetailCard(Map<String, int> progress, DateTime now) {
    final style = _dashboardStyle();
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _progressDetailCard(
      icon: Icons.view_week_rounded,
      title: 'Week Progress',
      percent: progress['percent'] ?? 0,
      passedLabel: '${progress['passed'] ?? 0} days passed',
      remainingLabel: '${progress['remaining'] ?? 0} days left',
      color: Colors.green,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            final day = index + 1;
            final isToday = day == now.weekday;
            final isPassed = day < now.weekday;
            return SizedBox(
              width: 64,
              child: Column(
                children: [
                  _progressBubble(
                    '$day',
                    isToday ? Colors.orange : isPassed ? Colors.green : style.elevatedSurface,
                    isToday || isPassed ? Colors.white : style.textMuted,
                    size: 42,
                  ),
                  const SizedBox(height: 6),
                  Text(labels[index], style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _progressDetailCard({required IconData icon, required String title, required int percent, required String passedLabel, required String remainingLabel, required Color color, required Widget child}) {
    final style = _dashboardStyle();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: color.withOpacity(style.dark ? 0.16 : 0.08), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('$passedLabel  •  $remainingLabel', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800)),
              ]);
              final percentBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.28))),
                child: Text('$percent%', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
              );
              if (constraints.maxWidth < 430) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)), const SizedBox(width: 12), Expanded(child: titleBlock)]),
                  const SizedBox(height: 10),
                  percentBadge,
                ]);
              }
              return Row(children: [
                CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
                const SizedBox(width: 12),
                Expanded(child: titleBlock),
                const SizedBox(width: 12),
                percentBadge,
              ]);
            },
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: (percent / 100).clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: style.elevatedSurface, color: color),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _progressBubble(String label, Color background, Color foreground, {double size = 30}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: Border.all(color: foreground.withOpacity(0.12))),
      child: Text(label, style: TextStyle(color: foreground, fontSize: size < 30 ? 10 : 12, fontWeight: FontWeight.w900)),
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

  Widget _buildHabitRoutineSection(List<Task> routines) {
    final theme = _dashboardThemeColors();
    final style = _dashboardStyle();
    final cardBackground = theme.card;
    final onCard = AppThemeColors.readableTextOn(cardBackground, style);
    return _darkSection('Habit & Routine Tracker', Column(children: [
      if (routines.isEmpty)
        Padding(padding: const EdgeInsets.all(8), child: Text('No enabled routines yet.', style: TextStyle(color: theme.textSecondary)))
      else
        ...routines.map((task) {
          final taskColor = _dashboardThemeTaskColor(task.colorValue);
          final mood = _routineMoodForTask(task);
          final moodColor = _routineMoodColor(mood, theme);
          final linkedInstructions = _linkedInstructionsForRoutine(task);
          final followedInstructions = linkedInstructions.where((instruction) {
            return widget.hiveService.instructionEntryForDate(instruction, task.dueDate)?.followed ?? false;
          }).length;
          final instructionSummary = linkedInstructions.isEmpty
              ? 'No instructions'
              : '$followedInstructions/${linkedInstructions.length} Instructions';
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _editTaskDetails(task),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
                boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(children: [
                Text(mood.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: taskColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(toTitleCase(task.task), style: TextStyle(color: onCard, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('${task.repeatFrequency ?? 'Daily'} • $instructionSummary', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      Text('Mood: ${mood.emoji} ${mood.label}', style: TextStyle(color: moodColor, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: theme.warning, size: 18),
                    Text('${_routineCurrentStreak(task)} streak', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                  ],
                ),
              ]),
            ),
          );
        }),
    ]));
  }


  Widget _buildDisabledRoutineBoard(List<_DisabledRoutineTask> disabledTasks) {
    final theme = _dashboardThemeColors();
    final style = _dashboardStyle();
    final cardBackground = theme.card;
    final onCard = AppThemeColors.readableTextOn(cardBackground, style);
    final iconBackground = theme.warning.withOpacity(0.14);
    return _darkSection(
      'Disabled Routine Tasks',
      Column(
        children: [
          if (disabledTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'No disabled routines. Disable a routine to pause active tracking without losing history.',
                style: TextStyle(color: theme.textSecondary),
              ),
            )
          else
            ...disabledTasks.map((item) {
              final task = item.task;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                  boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.pause_circle_outline, color: AppThemeColors.readableTextOn(iconBackground, style)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(toTitleCase(task.task), style: TextStyle(color: onCard, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${task.repeatFrequency ?? 'Daily'} • ${task.category}',
                            style: TextStyle(color: theme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Previous streak: ${item.previousStreak} • Last updated: ${_formatShortDate(item.lastUpdated)}',
                            style: TextStyle(color: theme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.hiveService.setRecurringTaskEnabledByReference(task, true),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Enable'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.success,
                        foregroundColor: AppThemeColors.readableTextOn(theme.success, style),
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
                    title: Text(toTitleCase(project.task), style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)),
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
      tween: Tween(begin: 0.0, end: 1.0),
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
      tween: Tween(begin: 0.0, end: 1.0),
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
        tween: Tween(begin: 0.0, end: 1.0),
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
                  _analyticsSummaryPill('Total Tasks', tasks.length, Icons.analytics_outlined, onTap: () => _showTaskListSheet('All non-routine tasks', _analyticsTasksForFilter(tasks, 'all'))),
                  _analyticsSummaryPill('Completed', completed, Icons.check_circle_outline, onTap: () => _showTaskListSheet('Completed non-routine tasks', _analyticsTasksForFilter(tasks, 'completed'))),
                  _analyticsSummaryPill('Pending', pending, Icons.timelapse_outlined, onTap: () => _showTaskListSheet('Pending non-routine tasks', _analyticsTasksForFilter(tasks, 'pending'))),
                  _analyticsSummaryPill('Overdue', overdue, Icons.warning_amber_rounded, onTap: () => _showTaskListSheet('Overdue non-routine tasks', _analyticsTasksForFilter(tasks, 'overdue'))),
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

  Widget _analyticsSummaryPill(String label, int value, IconData icon, {VoidCallback? onTap}) {
    final style = _dashboardStyle();
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
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
      tween: Tween(begin: 0.0, end: 1.0),
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

  Widget _todayScheduleSection(List<_DashboardTodayTask> todayRows, _TodayProductivityStats stats) {
    final style = _dashboardStyle();
    final theme = AppThemeColors.fromDashboardStyle(style);
    final now = _scheduleNow;
    final entries = _buildTodayScheduleEntries(todayRows, now);
    final positionedEntries = _positionOverlappingTodayEntries(entries.where((entry) => entry.taskRow != null).toList());
    final dateLabel = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    const hourHeight = 72.0;
    const labelWidth = 58.0;
    const timelineHeight = hourHeight * 24;

    return _panel(
      title: 'TODAY SCHEDULE',
      headerColor: style.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today Schedule', style: TextStyle(color: style.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(dateLabel, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.success.withOpacity(0.34)),
                  ),
                  child: Text('${stats.completionRate}% Complete', style: TextStyle(color: theme.success, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final laneAreaWidth = constraints.maxWidth - labelWidth;
                return SizedBox(
                  height: timelineHeight,
                  child: Stack(
                    children: [
                      for (var hour = 0; hour < 24; hour++)
                        Positioned(
                          top: hour * hourHeight,
                          left: 0,
                          right: 0,
                          height: hourHeight,
                          child: InkWell(
                            onTap: _openQuickAddForNow,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: labelWidth, child: Text(_formatScheduleTime(hour * 60), style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800))),
                                Expanded(child: Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.border.withOpacity(0.35)))))),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        top: ((now.hour * 60 + now.minute) / 60) * hourHeight,
                        left: labelWidth,
                        right: 0,
                        child: Container(height: 2, color: theme.accent),
                      ),
                      for (final positioned in positionedEntries)
                        Positioned(
                          top: (positioned.entry.startMinutes / 60) * hourHeight,
                          left: labelWidth + positioned.column * ((laneAreaWidth - ((positioned.columnCount - 1) * 6)) / positioned.columnCount + 6),
                          width: (laneAreaWidth - ((positioned.columnCount - 1) * 6)) / positioned.columnCount,
                          height: ((positioned.entry.endMinutes - positioned.entry.startMinutes) / 60 * hourHeight).clamp(36.0, timelineHeight),
                          child: _scheduleTaskTile(positioned.entry, theme, style, compact: positioned.columnCount > 2 || (positioned.entry.endMinutes - positioned.entry.startMinutes) <= 75),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleTaskTile(_TodayScheduleEntry entry, AppThemeColors theme, DashboardThemeStyle style, {bool compact = false}) {
    final row = entry.taskRow!;
    final state = _scheduleStateFor(row, entry, _scheduleNow);
    final baseColor = _scheduleStateColor(state, theme);
    final active = state == _TodayScheduleState.active;
    final opacity = state == _TodayScheduleState.missed ? 0.12 : (active ? 0.28 : 0.16);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = active ? (0.45 + (_pulseController.value * 0.35)) : 0.22;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openTodayTaskQuickOccurrence(row),
          child: Container(
            padding: EdgeInsets.all(compact ? 4 : 12),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(opacity),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: baseColor.withOpacity(active ? pulse : 0.38), width: active ? 2 : 1),
              boxShadow: active ? [BoxShadow(color: theme.accent.withOpacity(pulse), blurRadius: 20, spreadRadius: 1)] : null,
            ),
            child: child,
          ),
        );
      },
      child: compact
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    '${toTitleCase(row.task.task)} • ${_scheduleStateLabel(state)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) SizedBox(width: 76, child: Text(_formatScheduleTime(entry.startMinutes), style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w900))),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (active)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(999)),
                    child: Text('Active Now', style: TextStyle(color: AppThemeColors.readableTextOn(theme.accent, style), fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                Text(toTitleCase(row.task.task), style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text('${_formatScheduleTime(entry.startMinutes)} - ${_formatScheduleTime(entry.endMinutes)}', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                ],
                Text(_scheduleStateLabel(state), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: baseColor, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _freeTimeTile({required int start, required int end, VoidCallback? onTap}) {
    final style = _dashboardStyle();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: style.elevatedSurface.withOpacity(0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: style.textMuted.withOpacity(0.16)),
        ),
        child: Row(
          children: [
            SizedBox(width: 76, child: Text(_formatScheduleTime(start), style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800))),
            Expanded(child: Text('${_formatScheduleTime(start)} - ${_formatScheduleTime(end)}\nFree Time', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800))),
            Icon(Icons.add_circle_outline, color: style.primary),
          ],
        ),
      ),
    );
  }

  void _openQuickAddForNow() {
    showTaskFormDialog(context, date: DateTime.now(), title: 'Add Task', actionLabel: 'Add Task').then((task) {
      if (task != null) widget.hiveService.addTask(_dateOnly(task.dueDate), task);
    });
  }

  Widget _todaysProductivitySection(_TodayProductivityStats stats, List<_DashboardTodayTask> todayRows) {
    final style = _dashboardStyle();
    final theme = AppThemeColors.fromDashboardStyle(style);
    final badge = _productivityBadge(stats.completionRate);
    final completedColor = theme.completed;
    final pendingColor = theme.pending;
    final overdueColor = theme.overdue;

    return _panel(
      title: "TODAY'S PRODUCTIVITY",
      headerColor: style.primary,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
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
                        _todayProductivityStat('Total Tasks', stats.total, onTap: () => _showTodayTaskOccurrenceSheet("All today's tasks", _todayRowsForFilter(todayRows, 'all'))),
                        _todayProductivityStat('Completed', stats.completed, onTap: () => _showTodayTaskOccurrenceSheet("Completed today", _todayRowsForFilter(todayRows, 'completed'))),
                        _todayProductivityStat('Pending', stats.pending, onTap: () => _showTodayTaskOccurrenceSheet("Pending today", _todayRowsForFilter(todayRows, 'pending'))),
                        _todayProductivityStat('Overdue', stats.overdue, onTap: () => _showTodayTaskOccurrenceSheet("Overdue today", _todayRowsForFilter(todayRows, 'overdue'))),
                        _todayProductivityStat('Completion Rate', stats.completionRate, suffix: '%', onTap: () => _showTodayTaskOccurrenceSheet("All today's tasks", _todayRowsForFilter(todayRows, 'all'))),
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

  Widget _todayProductivityStat(String label, int value, {String suffix = '', VoidCallback? onTap}) {
    final style = _dashboardStyle();
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  _ProductivityBadge _productivityBadge(int rate) {
    final theme = AppThemeColors.fromDashboardStyle(_dashboardStyle());
    if (rate <= 25) return _ProductivityBadge(label: 'Needs Attention', emoji: '🔴', color: theme.danger);
    if (rate <= 50) return _ProductivityBadge(label: 'Getting Started', emoji: '🟠', color: theme.warning);
    if (rate <= 75) return _ProductivityBadge(label: 'Productive', emoji: '🟢', color: theme.success);
    return _ProductivityBadge(label: 'Excellent', emoji: '🔥', color: theme.accent);
  }

  Widget _instructionProductivitySection(DateTime today) {
    final style = _dashboardStyle();
    final instructions = widget.hiveService.getStandaloneInstructions();
    final enabled = instructions.where((instruction) => instruction.enabled).toList();
    final followed = enabled.where((instruction) => widget.hiveService.instructionEntryForDate(instruction, today)?.followed ?? false).length;
    final missed = enabled.where((instruction) => widget.hiveService.instructionEntryForDate(instruction, today)?.missed ?? false).length;
    final pending = enabled.where((instruction) => widget.hiveService.instructionEntryForDate(instruction, today) == null).length;
    final score = enabled.isEmpty ? 0 : ((followed / enabled.length) * 100).round();
    final bonus = widget.hiveService.instructionBonusForDate(today, standaloneOnly: true);

    return _panel(
      title: 'INSTRUCTION PRODUCTIVITY',
      headerColor: style.primary.withOpacity(style.dark ? 0.24 : 0.14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _instructionProductivityStat('Standalone Instructions', instructions.length, style.primary, onTap: () => _showInstructionFilterSheet('All standalone instructions', enabled, today)),
              _instructionProductivityStat('😀 Followed Today', followed, AppThemeColors.fromDashboardStyle(style).success, onTap: () => _showInstructionFilterSheet('Followed instructions', enabled.where((instruction) => widget.hiveService.instructionEntryForDate(instruction, today)?.followed ?? false).toList(), today)),
              _instructionProductivityStat('😞 Missed', missed, AppThemeColors.fromDashboardStyle(style).danger, onTap: () => _showInstructionFilterSheet('Missed instructions', enabled.where((instruction) => widget.hiveService.instructionEntryForDate(instruction, today)?.missed ?? false).toList(), today)),
              _instructionProductivityStat('😐 Pending', pending, AppThemeColors.fromDashboardStyle(style).warning, onTap: () => _showInstructionFilterSheet('Pending instructions', enabled.where((instruction) => widget.hiveService.instructionEntryForDate(instruction, today) == null).toList(), today)),
              _instructionProductivityStat('⭐ Completion', score, style.primary, suffix: '%', onTap: () => _showInstructionFilterSheet('All standalone instructions', enabled, today)),
              _instructionProductivityStat('🎁 Bonus Points', bonus, AppThemeColors.fromDashboardStyle(style).bonus, prefix: '+', onTap: () => _showInstructionFilterSheet('Bonus-earning instructions', enabled.where((instruction) => widget.hiveService.instructionEntryForDate(instruction, today)?.followed ?? false).toList(), today)),
              ],
            ),
            const SizedBox(height: 14),
            Center(child: _InstructionDonutChart(followed: followed, pending: pending, missed: missed)),
            const SizedBox(height: 12),
            if (enabled.isEmpty)
              Text('No standalone instructions yet. Add one from the Instruction Dashboard.', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700))
            else
              ...enabled.take(6).map((instruction) {
              final entry = widget.hiveService.instructionEntryForDate(instruction, today);
              final dashboardTheme = AppThemeColors.fromDashboardStyle(style);
              final statusColor = entry?.followed == true
                  ? dashboardTheme.success
                  : entry?.missed == true
                      ? dashboardTheme.danger
                      : dashboardTheme.muted;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(instruction.colorValue).withOpacity(0.14),
                  child: Icon(Icons.rule_folder_outlined, color: Color(instruction.colorValue)),
                ),
                title: Text(toTitleCase(instruction.name), style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900)),
                subtitle: Text((entry?.hasLevel == true || entry?.hasOption == true) ? toTitleCaseMetadata(['Today: ${entry!.selectionSummary}', 'Bonus: +${entry.bonusPoints}', '${widget.hiveService.instructionCurrentStreak(instruction, today)} Streak']) : toTitleCaseMetadata([instruction.repeatType, instruction.isLevelBased ? '${instruction.levels.length} Levels' : instruction.isOptionBased ? '${instruction.options.length} Options' : '+${instruction.bonusPoints} Points', '${widget.hiveService.instructionCurrentStreak(instruction, today)} Streak']), style: TextStyle(color: style.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                trailing: Text(entry?.status ?? 'Pending', style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
                onTap: () => _showStandaloneInstructionActions(instruction, today),
              );
              }),
          ],
        ),
      ),
    );
  }

  Widget _instructionProductivityStat(String label, int value, Color color, {String prefix = '', String suffix = '', VoidCallback? onTap}) {
    final style = _dashboardStyle();
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(style.dark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 4),
            Text('$prefix$value$suffix', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
          ],
        ),
      ),
    );
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
          onTap: () => _openTodayTaskQuickOccurrence(row),
          title: Text(toTitleCase(task.task), style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text(toTitleCaseMetadata([task.priority, row.displayStatus, _formatDueLabel(task)]), style: TextStyle(color: style.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
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
      tween: Tween(begin: 0.0, end: 1.0),
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
          tween: Tween(begin: 0.0, end: 1.0),
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


class _RoutineMood {
  final String emoji;
  final String label;
  final String detail;
  final int score;

  const _RoutineMood({required this.emoji, required this.label, required this.detail, required this.score});

  Color get color {
    if (score >= 75) return Colors.greenAccent;
    if (score >= 60) return const Color(0xFFB2FF59);
    if (score >= 40) return const Color(0xFFFFF176);
    if (score >= 20) return const Color(0xFFFFB74D);
    return const Color(0xFFFF8A80);
  }
}

class _InstructionDonutChart extends StatelessWidget {
  final int followed;
  final int pending;
  final int missed;

  const _InstructionDonutChart({required this.followed, required this.pending, required this.missed});

  @override
  Widget build(BuildContext context) {
    final total = followed + pending + missed;
    if (total == 0) return const SizedBox.shrink();
    final theme = context.dashboardTheme;
    return SizedBox(
      width: 128,
      height: 128,
      child: CustomPaint(
        painter: _InstructionDonutPainter(
          followed: followed,
          pending: pending,
          missed: missed,
          followedColor: theme.success,
          pendingColor: theme.warning,
          missedColor: theme.danger,
        ),
        child: Center(
          child: Text('$total\nRules', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: theme.textPrimary)),
        ),
      ),
    );
  }
}

class _InstructionDonutPainter extends CustomPainter {
  final int followed;
  final int pending;
  final int missed;
  final Color followedColor;
  final Color pendingColor;
  final Color missedColor;

  const _InstructionDonutPainter({
    required this.followed,
    required this.pending,
    required this.missed,
    required this.followedColor,
    required this.pendingColor,
    required this.missedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = followed + pending + missed;
    if (total <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    var start = -math.pi / 2;
    void draw(int value, Color color) {
      if (value <= 0) return;
      final sweep = (value / total) * math.pi * 2;
      paint.color = color;
      canvas.drawArc(rect.deflate(12), start, sweep, false, paint);
      start += sweep;
    }
    draw(followed, followedColor);
    draw(pending, pendingColor);
    draw(missed, missedColor);
  }

  @override
  bool shouldRepaint(covariant _InstructionDonutPainter oldDelegate) {
    return oldDelegate.followed != followed ||
        oldDelegate.pending != pending ||
        oldDelegate.missed != missed ||
        oldDelegate.followedColor != followedColor ||
        oldDelegate.pendingColor != pendingColor ||
        oldDelegate.missedColor != missedColor;
  }
}

class _DashboardRoutineSchedule {
  final int startMinutes;
  final int endMinutes;
  final int bonusPoints;

  const _DashboardRoutineSchedule({required this.startMinutes, required this.endMinutes, required this.bonusPoints});
}

class _DashboardScheduleResult {
  final String message;
  final int bonusPoints;

  const _DashboardScheduleResult(this.message, this.bonusPoints);
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

enum _TodayScheduleState {
  completed,
  active,
  pending,
  overdue,
  upcoming,
  missed;
}

class _ScheduleRange {
  final int start;
  final int end;

  const _ScheduleRange({required this.start, required this.end});
}

class _TodayScheduleEntry {
  final int startMinutes;
  final int endMinutes;
  final _DashboardTodayTask? taskRow;

  const _TodayScheduleEntry({
    required this.startMinutes,
    required this.endMinutes,
    this.taskRow,
  });
}

class _PositionedTodayScheduleEntry {
  final _TodayScheduleEntry entry;
  final int column;
  final int columnCount;

  const _PositionedTodayScheduleEntry({
    required this.entry,
    required this.column,
    required this.columnCount,
  });
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


extension DashboardThemeSettingColors on DashboardThemeStyle {
  Color get onPrimary => AppThemeColors.readableTextOn(primary, this);
  Color get selectedTabBg => primary;
  Color get selectedTabText => onPrimary;
  Color get unselectedTabBg => surface;
  Color get unselectedTabText => textPrimary;
  Color get softTabBg => primary.withOpacity(0.10);
  Color get tabBorder => primary.withOpacity(0.22);
}

class ThemeSettingTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final DashboardThemeStyle theme;

  const ThemeSettingTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = theme.selectedTabBg;
    final selectedText = theme.selectedTabText;
    final unselectedBg = theme.unselectedTabBg;
    final unselectedText = theme.unselectedTabText;
    final borderColor = selected ? theme.primary : theme.tabBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: selected
                ? [BoxShadow(color: theme.primary.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 6))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: selected ? selectedText : theme.primary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? selectedText : unselectedText,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSettingsPanel extends StatelessWidget {
  final HiveService hiveService;
  final VoidCallback onClose;
  final WidgetBuilder themeSelectorBuilder;

  const _DashboardSettingsPanel({
    required this.hiveService,
    required this.onClose,
    required this.themeSelectorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final style = DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
        final speed = hiveService.getDashboardAnimationSpeed();
        return AnimatedContainer(
          duration: speed.duration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: style.background,
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(-8, 0))],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, color: style.primary, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dashboard Settings', style: TextStyle(color: style.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                            Text('Appearance, typography, layout, charts, and motion', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close settings',
                        onPressed: onClose,
                        icon: Icon(Icons.close_rounded, color: style.textPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      themeSelectorBuilder(context),
                      const SizedBox(height: 14),
                      _settingsSection(
                        style: style,
                        icon: Icons.dashboard_customize_rounded,
                        title: 'Dashboard Layout Style',
                        child: _wrapChoiceChips(
                          children: DashboardLayoutStyle.values.map((layout) {
                            final selected = layout == hiveService.getDashboardLayoutStyle();
                            return _simpleSettingsChip(
                              style: style,
                              label: layout.label,
                              selected: selected,
                              onTap: () => hiveService.setDashboardLayoutStyle(layout),
                            );
                          }).toList(),
                        ),
                      ),
                      _settingsSection(
                        style: style,
                        icon: Icons.animation_rounded,
                        title: 'Card Animation Style',
                        child: _wrapChoiceChips(
                          children: DashboardCardAnimationStyle.values.map((animation) {
                            final selected = animation == hiveService.getDashboardCardAnimationStyle();
                            return _simpleSettingsChip(
                              style: style,
                              label: animation.label,
                              selected: selected,
                              onTap: () => hiveService.setDashboardCardAnimationStyle(animation),
                            );
                          }).toList(),
                        ),
                      ),
                      _settingsSection(
                        style: style,
                        icon: Icons.speed_rounded,
                        title: 'UI Animation Speed',
                        child: _wrapChoiceChips(
                          children: DashboardAnimationSpeed.values.map((speedOption) {
                            final selected = speedOption == hiveService.getDashboardAnimationSpeed();
                            return _simpleSettingsChip(
                              style: style,
                              label: speedOption.label,
                              selected: selected,
                              onTap: () => hiveService.setDashboardAnimationSpeed(speedOption),
                            );
                          }).toList(),
                        ),
                      ),
                      _settingsSection(
                        style: style,
                        icon: Icons.bar_chart_rounded,
                        title: 'Chart Style',
                        child: _wrapChoiceChips(
                          children: DashboardChartStyle.values.map((chart) {
                            final selected = chart == hiveService.getDashboardChartStyle();
                            return _simpleSettingsChip(
                              style: style,
                              label: chart.label,
                              selected: selected,
                              onTap: () => hiveService.setDashboardChartStyle(chart),
                            );
                          }).toList(),
                        ),
                      ),
                      _settingsSection(
                        style: style,
                        icon: Icons.interests_rounded,
                        title: 'Icon Pack',
                        child: _wrapChoiceChips(
                          children: DashboardIconPack.values.map((pack) {
                            final selected = pack == hiveService.getDashboardIconPack();
                            return _simpleSettingsChip(
                              style: style,
                              label: pack.label,
                              selected: selected,
                              onTap: () => hiveService.setDashboardIconPack(pack),
                            );
                          }).toList(),
                        ),
                      ),
                      _settingsSection(
                        style: style,
                        icon: Icons.brightness_auto_rounded,
                        title: 'Dynamic Theme',
                        child: Column(
                          children: [
                            _settingsSwitch(
                              style: style,
                              title: 'Follow System Theme',
                              value: hiveService.getFollowSystemTheme(),
                              onChanged: hiveService.setFollowSystemTheme,
                            ),
                            _settingsSwitch(
                              style: style,
                              title: 'Auto Day/Night',
                              value: hiveService.getAutoDayNight(),
                              onChanged: hiveService.setAutoDayNight,
                            ),
                            _settingsSwitch(
                              style: style,
                              title: 'Adaptive Colors',
                              value: hiveService.getAdaptiveColors(),
                              onChanged: hiveService.setAdaptiveColors,
                            ),
                          ],
                        ),
                      ),
                      _settingsSection(
                        style: style,
                        icon: Icons.preview_rounded,
                        title: 'Live Preview',
                        child: _livePreview(style),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingsSection({required DashboardThemeStyle style, required IconData icon, required String title, required Widget child}) {
    return AnimatedContainer(
      duration: hiveService.getDashboardAnimationSpeed().duration,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: style.primary, size: 19),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _wrapChoiceChips({required List<Widget> children}) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }

  Widget _simpleSettingsChip({required DashboardThemeStyle style, required String label, required bool selected, required VoidCallback onTap}) {
    return ThemeSettingTab(
      label: label,
      selected: selected,
      onTap: onTap,
      theme: style,
    );
  }


  Widget _settingsSwitch({required DashboardThemeStyle style, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)),
      value: value,
      activeColor: style.primary,
      onChanged: onChanged,
    );
  }

  Widget _livePreview(DashboardThemeStyle style) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [style.elevatedSurface, style.surface]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard Preview', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Hello, Rohan', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: 0.85, minHeight: 10, backgroundColor: style.elevatedSurface, color: style.primary),
          ),
          const SizedBox(height: 8),
          Text('Daily Progress 85%', style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _previewPill(style, 'Today Tasks')),
              const SizedBox(width: 8),
              Expanded(child: _previewPill(style, 'Analytics')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewPill(DashboardThemeStyle style, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: style.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: style.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}
