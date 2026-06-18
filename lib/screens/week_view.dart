import 'package:flutter/material.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/period_progress_bubble_map.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import '../constants/dashboard_themes.dart';
import '../models/task_model.dart';
import '../models/productivity_snapshot.dart';
import 'journal_view.dart';
import '../utils/text_formatters.dart';

class WeekView extends StatefulWidget {
  final HiveService hiveService;

  const WeekView({super.key, required this.hiveService});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  late DateTime _currentWeekStart;
  bool _showWeeklyTasks = true;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
  }

  DateTime _getWeekStart(DateTime date) {
    // Monday as start of week
    final weekday = date.weekday; // 1 = Monday, 7 = Sunday
    final daysToSubtract = weekday - 1;
    return DateTime(date.year, date.month, date.day - daysToSubtract);
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

  List<String> _getDayLabels() {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }

  String _formatWeekRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final startStr = '${start.month}/${start.day}';
    final endStr = '${end.month}/${end.day}';
    return '$startStr - $endStr';
  }

  List<Task> _getWeeklyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final weekStart = DateTime(_currentWeekStart.year, _currentWeekStart.month, _currentWeekStart.day);
    final weekEnd = weekStart.add(const Duration(days: 6));

    return allTasksByDate.values
        .expand((tasks) => tasks)
        .where((task) {
          final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          return task.repeatTask &&
              task.repeatFrequency == 'Weekly' &&
              !dueDate.isBefore(weekStart) &&
              !dueDate.isAfter(weekEnd);
        })
        .toList();
  }

  _WeeklyProductivityStats _weeklyProductivityStats(List<DateTime> days) {
    final snapshots = days
        .map((date) => widget.hiveService.calculateProductivitySnapshotForDate(date))
        .toList();
    final weekTasks = days.expand((date) => widget.hiveService.getTasksForDate(date)).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedTasks = weekTasks.where(_isCompletedTask).length;
    final pendingTasks = weekTasks.where((task) => !_isCompletedTask(task) && task.status != 'Cancelled').length;
    final overdueTasks = weekTasks.where((task) {
      final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return due.isBefore(today) && !_isCompletedTask(task) && task.status != 'Cancelled';
    }).length;
    return _WeeklyProductivityStats(
      weekStart: days.first,
      snapshots: snapshots,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      overdueTasks: overdueTasks,
    );
  }

  bool _isCompletedTask(Task task) {
    return task.done || task.status.trim().toLowerCase() == 'completed';
  }

  String _formatHours(double hours) {
    if (hours == 0) return '0 hrs';
    if (hours == hours.roundToDouble()) return '${hours.round()} hrs';
    return '${hours.toStringAsFixed(1)} hrs';
  }

  Widget _weeklyProductivitySection(_WeeklyProductivityStats stats) {
    final score = stats.productivityScore;
    final rating = ProductivitySnapshot.ratingForScore(score);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '📆 Weekly Productivity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ),
              _ScoreBadge(score: score, rating: rating),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _WeekMetricCard(label: 'Score', value: '${score.round()}%', icon: Icons.insights),
              _WeekMetricCard(label: 'Rating', value: rating, icon: Icons.emoji_events_outlined),
              _WeekMetricCard(label: 'Total Points', value: '${stats.totalPoints} / ${_WeeklyProductivityStats.maximumWeeklyPoints}', icon: Icons.stars_outlined),
              _WeekMetricCard(label: 'Hours Recorded', value: _formatHours(stats.totalHours), icon: Icons.timer_outlined),
              _WeekMetricCard(label: 'Completed Tasks', value: '${stats.completedTasks}', icon: Icons.check_circle_outline),
              _WeekMetricCard(label: 'Pending Tasks', value: '${stats.pendingTasks}', icon: Icons.pending_actions_outlined),
              _WeekMetricCard(label: 'Overdue Tasks', value: '${stats.overdueTasks}', icon: Icons.warning_amber_rounded),
              _WeekMetricCard(label: 'Average Daily Score', value: '${stats.averageDailyScore.round()}%', icon: Icons.show_chart),
              _WeekMetricCard(label: 'Best Day', value: stats.bestDayLabel(_getDayLabels()), icon: Icons.arrow_upward_rounded),
              _WeekMetricCard(label: 'Lowest Day', value: stats.lowestDayLabel(_getDayLabels()), icon: Icons.arrow_downward_rounded),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Weekly Breakdown', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          _categoryBreakdown(stats),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _weeklyBarChart(stats)),
              const SizedBox(width: 12),
              SizedBox(width: 120, child: _completedPendingDonut(stats)),
            ],
          ),
          const SizedBox(height: 16),
          _dailyScoreLineChart(stats),
          const SizedBox(height: 16),
          _matrixSummary(stats),
          const SizedBox(height: 16),
          _dailyBreakdown(stats),
        ],
      ),
    );
  }

  Widget _categoryBreakdown(_WeeklyProductivityStats stats) {
    final items = [
      ('🔥 Important + Urgent', stats.bothHours, const Color(0xFFFF7043)),
      ('🔵 Important Only', stats.importantHours, const Color(0xFF42A5F5)),
      ('🟡 Urgent Only', stats.urgentHours, const Color(0xFFFFCA28)),
      ('⚪ Neither', stats.neitherHours, const Color(0xFFBDBDBD)),
    ];
    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(_formatHours(item.$2), style: TextStyle(color: item.$3, fontWeight: FontWeight.w900)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _weeklyBarChart(_WeeklyProductivityStats stats) {
    final labels = _getDayLabels();
    return Container(
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F4EC), borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(stats.snapshots.length, (index) {
          final value = stats.snapshots[index].productivityScore.clamp(0, 100).toDouble();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: value / 100,
                        child: Container(
                          width: 18,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _dailyScoreLineChart(_WeeklyProductivityStats stats) {
    return Container(
      height: 150,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F4EC), borderRadius: BorderRadius.circular(18)),
      child: CustomPaint(
        painter: _WeeklyScoreLinePainter(stats.snapshots.map((snapshot) => snapshot.productivityScore).toList()),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _completedPendingDonut(_WeeklyProductivityStats stats) {
    final total = stats.completedTasks + stats.pendingTasks + stats.overdueTasks;
    final completedRatio = total == 0 ? 0.0 : stats.completedTasks / total;
    return Column(
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: completedRatio,
                strokeWidth: 12,
                color: AppColors.taskCompleted,
                backgroundColor: AppColors.taskPending.withOpacity(0.25),
              ),
              Text('${(completedRatio * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('Completed vs Pending', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _matrixSummary(_WeeklyProductivityStats stats) {
    final cells = [
      ('Urgent Only', stats.urgentHours, '50 pts/hr', const Color(0xFFFFF8E1)),
      ('Both', stats.bothHours, '100 pts/hr', const Color(0xFFFFEBEE)),
      ('Neither', stats.neitherHours, '10 pts/hr', const Color(0xFFF5F5F5)),
      ('Important Only', stats.importantHours, '80 pts/hr', const Color(0xFFE3F2FD)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Important / Urgent Matrix Summary', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.0,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: cells
              .map((cell) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(color: cell.$4, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(cell.$1, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                        const SizedBox(height: 4),
                        Text(_formatHours(cell.$2), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(cell.$3, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _dailyBreakdown(_WeeklyProductivityStats stats) {
    final labels = _getDayLabels();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Breakdown', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        ...List.generate(stats.snapshots.length, (index) {
          final snapshot = stats.snapshots[index];
          final recorded = snapshot.productivityScore > 0 || snapshot.totalPoints > 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: recorded ? AppColors.primary.withOpacity(0.08) : Colors.grey.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(width: 42, child: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.w900))),
                Expanded(child: Text(recorded ? '${snapshot.productivityScore.round()}% ${snapshot.rating}' : '0% Not Recorded')),
                Text('${snapshot.totalPoints} pts', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _weeklyTasksPanel(List<Task> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showWeeklyTasks = !_showWeeklyTasks),
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
                      "WEEKLY TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_showWeeklyTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showWeeklyTasks)
            SizedBox(
              height: 140,
              child: tasks.isEmpty
                  ? const Center(child: Text('Nothing for this week, Great Job !'))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          dense: true,
                          onTap: () => _editTask(task),
                          title: Text(toTitleCase(task.task)),
                          subtitle: Text('${task.priority} • ${task.status}'),
                        );
                      },
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

  Widget _weekDayProgressMap(DashboardThemeStyle theme, List<DateTime> weekDays, DateTime todayStart) {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final isCurrentWeek = !todayStart.isBefore(_currentWeekStart) && !todayStart.isAfter(weekEnd);
    final isPastWeek = weekEnd.isBefore(todayStart);
    final isFutureWeek = _currentWeekStart.isAfter(todayStart);
    final todayIndex = isCurrentWeek ? todayStart.difference(_currentWeekStart).inDays : -1;
    final passedDays = isPastWeek ? 7 : isFutureWeek ? 0 : todayIndex.clamp(0, 7).toInt();
    final remainingDays = isPastWeek ? 0 : isFutureWeek ? 7 : (7 - passedDays - 1).clamp(0, 7).toInt();
    return PeriodProgressBubbleMap(
      theme: theme,
      title: 'Week Day Progress',
      subtitle: '$passedDays days passed • $remainingDays days left',
      totalItems: 7,
      minBubbleSize: 30,
      maxBubbleSize: 38,
      passedItems: passedDays,
      currentIndex: isCurrentWeek ? todayIndex : null,
      itemsPerRow: 7,
      tooltipBuilder: (index) {
        final date = weekDays[index];
        return '${date.month}/${date.day}/${date.year}';
      },
      bubbleLabelBuilder: (index) => '${index + 1}',
      belowLabelBuilder: (index) => _getDayLabels()[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekDays = List.generate(7, (i) => _currentWeekStart.add(Duration(days: i)));
    final isCurrentWeek = _currentWeekStart.isBefore(todayStart) &&
        todayStart.isBefore(_currentWeekStart.add(const Duration(days: 7)));
    final fabTargetDate = isCurrentWeek ? todayStart : _currentWeekStart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Progress'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Text(
                  _formatWeekRange(_currentWeekStart),
                  style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Prev'),
                        onPressed: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text('Next'),
                        onPressed: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final weeklyTasks = _getWeeklyRepeatingTasks();

          final weeklyStats = _weeklyProductivityStats(weekDays);
          final selectedDashboardTheme = _selectedDashboardTheme();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _weekDayProgressMap(selectedDashboardTheme, weekDays, todayStart),
              const SizedBox(height: 12),
              _weeklyProductivitySection(weeklyStats),
              const SizedBox(height: 12),
              _weeklyTasksPanel(weeklyTasks),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showQuickAddTaskDialog(context, fabTargetDate, widget.hiveService);
        },
        tooltip: isCurrentWeek ? 'Add task for today' : 'Add task for week',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WeeklyProductivityStats {
  static const int maximumWeeklyPoints = 11200;

  final DateTime weekStart;
  final List<ProductivitySnapshot> snapshots;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;

  const _WeeklyProductivityStats({
    required this.weekStart,
    required this.snapshots,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
  });

  int get totalPoints => snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints);
  double get bothHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.bothHours);
  double get importantHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.importantHours);
  double get urgentHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.urgentHours);
  double get neitherHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.neitherHours);
  double get totalHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.totalHours);
  double get productivityScore => (totalPoints / maximumWeeklyPoints * 100).clamp(0.0, 100.0).toDouble();
  double get averageDailyScore => snapshots.isEmpty ? 0 : snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.productivityScore) / snapshots.length;

  int get bestDayIndex {
    if (snapshots.isEmpty) return 0;
    var index = 0;
    for (var i = 1; i < snapshots.length; i++) {
      if (snapshots[i].productivityScore > snapshots[index].productivityScore) index = i;
    }
    return index;
  }

  int get lowestDayIndex {
    if (snapshots.isEmpty) return 0;
    var index = 0;
    for (var i = 1; i < snapshots.length; i++) {
      if (snapshots[i].productivityScore < snapshots[index].productivityScore) index = i;
    }
    return index;
  }

  String bestDayLabel(List<String> labels) {
    if (snapshots.isEmpty) return 'N/A';
    final index = bestDayIndex;
    return '${labels[index]} ${snapshots[index].productivityScore.round()}%';
  }

  String lowestDayLabel(List<String> labels) {
    if (snapshots.isEmpty) return 'N/A';
    final index = lowestDayIndex;
    return '${labels[index]} ${snapshots[index].productivityScore.round()}%';
  }
}

class _WeekMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WeekMetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final String rating;

  const _ScoreBadge({required this.score, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.taskCompleted.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.taskCompleted.withOpacity(0.36)),
      ),
      child: Text('${score.round()}% • $rating', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
    );
  }
}

class _WeeklyScoreLinePainter extends CustomPainter {
  final List<double> scores;

  const _WeeklyScoreLinePainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.black.withOpacity(0.16)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = AppColors.primaryDark;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint);
    }

    if (scores.isEmpty) return;
    final points = <Offset>[];
    for (var i = 0; i < scores.length; i++) {
      final x = scores.length == 1 ? size.width / 2 : size.width * i / (scores.length - 1);
      final clampedScore = scores[i].clamp(0.0, 100.0).toDouble();
      final y = size.height - (clampedScore / 100 * size.height);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyScoreLinePainter oldDelegate) {
    if (oldDelegate.scores.length != scores.length) return true;
    for (var i = 0; i < scores.length; i++) {
      if (oldDelegate.scores[i] != scores[i]) return true;
    }
    return false;
  }
}
