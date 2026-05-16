import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/journal_entry.dart';
import '../models/rank_profile.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/rank_profile_card.dart';
import 'journal_view.dart';

class StreakView extends StatelessWidget {
  final HiveService hiveService;

  const StreakView({super.key, required this.hiveService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Streak Journey'),
        actions: [
          IconButton(
            tooltip: 'Add task for today',
            icon: const Icon(Icons.add_task),
            onPressed: () async {
              final now = DateTime.now();
              await showQuickAddTaskDialog(
                context,
                DateTime(now.year, now.month, now.day),
                hiveService,
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final allTasksByDate = hiveService.getAllTasksByDate();
          final journalEntries = hiveService.getAllJournalEntries();
          final stats = _JourneyStats.fromTasks(
            allTasksByDate,
            journalEntries: journalEntries,
          );
          final rankProfile = RankProfile.calculate(
            username: hiveService.getUsername(),
            allTasksByDate: allTasksByDate,
            journalEntries: journalEntries,
          );
          final habits = _HabitTracker.buildHabits(allTasksByDate, stats.today);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroStreakCard(stats: stats),
                const SizedBox(height: 14),
                RankProfileCard(
                  profile: rankProfile,
                  onUsernameChanged: hiveService.setUsername,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => JournalView(hiveService: hiveService),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TodayWeeklyPanel(stats: stats),
                const SizedBox(height: 14),
                _WeeklyDateIndicator(today: stats.today),
                const SizedBox(height: 14),
                _RecurringTaskListView(habits: habits, today: stats.today),
                const SizedBox(height: 14),
                _HabitTrackerSection(
                  hiveService: hiveService,
                  habits: habits,
                  today: stats.today,
                ),
                const SizedBox(height: 14),
                _YearProgressPanel(stats: stats),
                const SizedBox(height: 14),
                _ActivityHeatmap(stats: stats),
                const SizedBox(height: 14),
                _DailyTaskCards(tasks: stats.todayTasks),
                const SizedBox(height: 14),
                _PerformanceInsights(stats: stats),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _JourneyStats {
  final DateTime today;
  final int year;
  final int totalDaysInYear;
  final int dayOfYear;
  final int completedDays;
  final int activeDays;
  final int currentDailyStreak;
  final int currentWeeklyStreak;
  final int longestStreak;
  final int totalCompletedTasks;
  final int totalTasksThisYear;
  final int todayCompleted;
  final int todayTotal;
  final int weekCompleted;
  final int weekTotal;
  final String mostProductiveMonth;
  final String bestStreakPeriod;
  final String frequentlySkippedCategory;
  final double habitConsistencyScore;
  final List<Task> todayTasks;
  final Map<DateTime, _DayActivity> activityByDate;

  const _JourneyStats({
    required this.today,
    required this.year,
    required this.totalDaysInYear,
    required this.dayOfYear,
    required this.completedDays,
    required this.activeDays,
    required this.currentDailyStreak,
    required this.currentWeeklyStreak,
    required this.longestStreak,
    required this.totalCompletedTasks,
    required this.totalTasksThisYear,
    required this.todayCompleted,
    required this.todayTotal,
    required this.weekCompleted,
    required this.weekTotal,
    required this.mostProductiveMonth,
    required this.bestStreakPeriod,
    required this.frequentlySkippedCategory,
    required this.habitConsistencyScore,
    required this.todayTasks,
    required this.activityByDate,
  });

  double get yearCompletionRatio => totalDaysInYear == 0 ? 0 : completedDays / totalDaysInYear;
  double get yearCalendarRatio => totalDaysInYear == 0 ? 0 : dayOfYear / totalDaysInYear;
  double get productivityRatio => totalTasksThisYear == 0 ? 0 : totalCompletedTasks / totalTasksThisYear;
  double get todayRatio => todayTotal == 0 ? 0 : todayCompleted / todayTotal;
  double get weeklyRatio => weekTotal == 0 ? 0 : weekCompleted / weekTotal;

  factory _JourneyStats.fromTasks(
    Map<DateTime, List<Task>> allTasksByDate, {
    List<JournalEntry> journalEntries = const <JournalEntry>[],
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yearStart = DateTime(today.year, 1, 1);
    final nextYear = DateTime(today.year + 1, 1, 1);
    final totalDaysInYear = nextYear.difference(yearStart).inDays;
    final dayOfYear = today.difference(yearStart).inDays + 1;
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final nextWeek = weekStart.add(const Duration(days: 7));

    final activityByDate = <DateTime, _DayActivity>{};
    final monthCompleted = List<int>.filled(12, 0);
    final skippedByCategory = <String, int>{};
    var totalCompletedTasks = 0;
    var totalTasksThisYear = 0;
    var weekCompleted = 0;
    var weekTotal = 0;

    for (final entry in allTasksByDate.entries) {
      final date = _dateOnly(entry.key);
      if (date.year != today.year) continue;

      final tasks = entry.value;
      final eligibleTasks = tasks.where((task) => task.status != 'Cancelled').toList();
      final completedTasks = eligibleTasks.where(_isCompletedTask).toList();
      final activeTasks = tasks.where((task) => _isCompletedTask(task) || task.status == 'Cancelled').toList();

      totalTasksThisYear += eligibleTasks.length;
      totalCompletedTasks += completedTasks.length;
      monthCompleted[date.month - 1] += completedTasks.length;

      if (!date.isBefore(weekStart) && date.isBefore(nextWeek)) {
        weekCompleted += completedTasks.length;
        weekTotal += eligibleTasks.length;
      }

      for (final task in eligibleTasks.where((task) => !_isCompletedTask(task) && date.isBefore(today))) {
        skippedByCategory.update(task.category, (value) => value + 1, ifAbsent: () => 1);
      }

      activityByDate[date] = _DayActivity(
        total: eligibleTasks.length,
        completed: completedTasks.length,
        activityCount: activeTasks.length,
        journaled: activityByDate[date]?.journaled ?? false,
      );
    }

    for (final entry in journalEntries) {
      final date = _dateOnly(entry.date);
      if (date.year != today.year) continue;
      final current = activityByDate[date] ?? const _DayActivity.empty();
      activityByDate[date] = current.copyWith(journaled: true);
    }

    final todayActivity = activityByDate[today] ?? const _DayActivity.empty();
    final completedDays = activityByDate.values.where((activity) => activity.isGoalComplete).length;
    final activeDays = activityByDate.values.where((activity) => activity.hasMeaningfulActivity).length;
    final dailyStreak = _calculateDailyStreak(today, activityByDate);
    final streakInfo = _calculateLongestStreak(yearStart, totalDaysInYear, activityByDate);
    final weeklyStreak = _calculateWeeklyStreak(today, activityByDate);

    final mostProductiveMonthIndex = monthCompleted.indexOf(monthCompleted.reduce(math.max));
    final mostProductiveMonth = monthCompleted[mostProductiveMonthIndex] == 0
        ? 'No completed month yet'
        : '${_monthNames[mostProductiveMonthIndex]} (${monthCompleted[mostProductiveMonthIndex]} tasks)';

    final skippedCategory = skippedByCategory.isEmpty
        ? 'No skipped pattern yet'
        : skippedByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final recurringTasks = allTasksByDate.values
        .expand((tasks) => tasks)
        .where((task) => task.repeatTask && task.dueDate.year == today.year)
        .toList();
    final recurringCompleted = recurringTasks.where(_isCompletedTask).length;
    final habitConsistencyScore = recurringTasks.isEmpty ? 0.0 : recurringCompleted / recurringTasks.length;

    return _JourneyStats(
      today: today,
      year: today.year,
      totalDaysInYear: totalDaysInYear,
      dayOfYear: dayOfYear,
      completedDays: completedDays,
      activeDays: activeDays,
      currentDailyStreak: dailyStreak,
      currentWeeklyStreak: weeklyStreak,
      longestStreak: streakInfo.length,
      totalCompletedTasks: totalCompletedTasks,
      totalTasksThisYear: totalTasksThisYear,
      todayCompleted: todayActivity.completed,
      todayTotal: todayActivity.total,
      weekCompleted: weekCompleted,
      weekTotal: weekTotal,
      mostProductiveMonth: mostProductiveMonth,
      bestStreakPeriod: streakInfo.label,
      frequentlySkippedCategory: skippedCategory,
      habitConsistencyScore: habitConsistencyScore,
      todayTasks: (allTasksByDate[today] ?? const <Task>[])
          .where(_isAllowedRecurringTask)
          .toList(),
      activityByDate: activityByDate,
    );
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static bool _isCompletedTask(Task task) => task.done || task.status.trim().toLowerCase() == 'completed';

  static bool _isAllowedRecurringTask(Task task) {
    final frequency = _normalizedRepeatFrequency(task.repeatFrequency);
    return task.repeatTask && (frequency == 'daily' || frequency == 'weekly');
  }

  static String _normalizedRepeatFrequency(String? repeatFrequency) => (repeatFrequency ?? '').trim().toLowerCase();

  static int _calculateDailyStreak(DateTime today, Map<DateTime, _DayActivity> activityByDate) {
    var cursor = today;
    var streak = 0;

    if (!(activityByDate[cursor]?.isGoalComplete ?? false)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (activityByDate[cursor]?.isGoalComplete ?? false) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static _StreakInfo _calculateLongestStreak(
    DateTime yearStart,
    int totalDaysInYear,
    Map<DateTime, _DayActivity> activityByDate,
  ) {
    var bestLength = 0;
    DateTime? bestStart;
    var currentLength = 0;
    DateTime? currentStart;

    for (var i = 0; i < totalDaysInYear; i++) {
      final date = yearStart.add(Duration(days: i));
      final complete = activityByDate[date]?.isGoalComplete ?? false;
      if (complete) {
        currentStart ??= date;
        currentLength++;
        if (currentLength > bestLength) {
          bestLength = currentLength;
          bestStart = currentStart;
        }
      } else {
        currentLength = 0;
        currentStart = null;
      }
    }

    if (bestLength == 0 || bestStart == null) {
      return const _StreakInfo(length: 0, label: 'Build your first streak');
    }

    final bestEnd = bestStart.add(Duration(days: bestLength - 1));
    return _StreakInfo(
      length: bestLength,
      label: '${_shortDate(bestStart)} – ${_shortDate(bestEnd)}',
    );
  }

  static int _calculateWeeklyStreak(DateTime today, Map<DateTime, _DayActivity> activityByDate) {
    var weekStart = today.subtract(Duration(days: today.weekday - 1));
    var streak = 0;

    while (_weekHasGoalCompletion(weekStart, activityByDate)) {
      streak++;
      weekStart = weekStart.subtract(const Duration(days: 7));
    }

    return streak;
  }

  static bool _weekHasGoalCompletion(DateTime weekStart, Map<DateTime, _DayActivity> activityByDate) {
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (activityByDate[date]?.isGoalComplete ?? false) return true;
    }
    return false;
  }

  static String _shortDate(DateTime date) => '${date.month}/${date.day}';
}

class _DayActivity {
  final int total;
  final int completed;
  final int activityCount;

  final bool journaled;

  const _DayActivity({required this.total, required this.completed, required this.activityCount, this.journaled = false});
  const _DayActivity.empty() : total = 0, completed = 0, activityCount = 0, journaled = false;

  _DayActivity copyWith({bool? journaled}) {
    return _DayActivity(
      total: total,
      completed: completed,
      activityCount: activityCount,
      journaled: journaled ?? this.journaled,
    );
  }

  bool get isGoalComplete => (total > 0 && completed == total) || (total == 0 && journaled);
  bool get hasMeaningfulActivity => completed > 0 || activityCount > 0 || journaled;
  double get ratio => total == 0 ? 0 : completed / total;
}

class _StreakInfo {
  final int length;
  final String label;

  const _StreakInfo({required this.length, required this.label});
}

class _HeroStreakCard extends StatelessWidget {
  final _JourneyStats stats;

  const _HeroStreakCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A00), Color(0xFFE52E71), Color(0xFF7E57C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE52E71).withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your consistency journey',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${stats.currentDailyStreak}',
            style: const TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.w900, height: 0.95),
          ),
          const Text('day active streak', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroMetric(label: 'Weekly streak', value: '${stats.currentWeeklyStreak} wk')),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Longest', value: '${stats.longestStreak} days')),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Productivity', value: '${(stats.productivityRatio * 100).round()}%')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 11)),
        ],
      ),
    );
  }
}

class _TodayWeeklyPanel extends StatelessWidget {
  final _JourneyStats stats;

  const _TodayWeeklyPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProgressTile(
            icon: Icons.today,
            title: "Today's progress",
            value: '${stats.todayCompleted}/${stats.todayTotal}',
            ratio: stats.todayRatio,
            color: AppColors.taskCompleted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProgressTile(
            icon: Icons.calendar_view_week,
            title: 'Weekly target',
            value: '${stats.weekCompleted}/${stats.weekTotal}',
            ratio: stats.weeklyRatio,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _ProgressTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double ratio;
  final Color color;

  const _ProgressTile({required this.icon, required this.title, required this.value, required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            color: color,
            backgroundColor: color.withOpacity(0.16),
          ),
        ],
      ),
    );
  }
}

class _YearProgressPanel extends StatelessWidget {
  final _JourneyStats stats;

  const _YearProgressPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stats.year} Year Progress Overview',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Text('${(stats.yearCalendarRatio * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: stats.yearCalendarRatio.clamp(0.0, 1.0).toDouble(),
            minHeight: 12,
            borderRadius: BorderRadius.circular(99),
            color: AppColors.primary,
            backgroundColor: AppColors.primary.withOpacity(0.14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatPill(label: 'Active days', value: '${stats.activeDays}/${stats.totalDaysInYear}'),
              _StatPill(label: 'Completed days', value: '${stats.completedDays}'),
              _StatPill(label: 'Consistency', value: '${(stats.yearCompletionRatio * 100).round()}%'),
              _StatPill(label: 'Completed tasks', value: '${stats.totalCompletedTasks}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActivityHeatmap extends StatelessWidget {
  final _JourneyStats stats;

  const _ActivityHeatmap({required this.stats});

  @override
  Widget build(BuildContext context) {
    final yearStart = DateTime(stats.year, 1, 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('365-Day Activity Heatmap', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Darker green days mean stronger task completion.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.totalDaysInYear,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 28,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final date = yearStart.add(Duration(days: index));
              final activity = stats.activityByDate[date] ?? const _DayActivity.empty();
              final color = _heatColor(activity);
              final isToday = date == stats.today;

              return Tooltip(
                message: '${date.month}/${date.day}: ${activity.completed}/${activity.total} complete',
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: isToday ? Border.all(color: AppColors.accent, width: 2) : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _heatColor(_DayActivity activity) {
    if (activity.total == 0 && !activity.hasMeaningfulActivity) return const Color(0xFFE5EAF0);
    if (activity.ratio >= 1) return const Color(0xFF1B5E20);
    if (activity.ratio >= 0.66) return const Color(0xFF43A047);
    if (activity.ratio >= 0.33) return const Color(0xFF9CCC65);
    if (activity.hasMeaningfulActivity) return const Color(0xFFFFC107);
    return const Color(0xFFE5EAF0);
  }
}


class _WeeklyDateIndicator extends StatelessWidget {
  final DateTime today;

  const _WeeklyDateIndicator({required this.today});

  @override
  Widget build(BuildContext context) {
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This Week', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final isToday = _isSameDate(date, today);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.accent : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isToday ? AppColors.accent : Colors.black12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        labels[index],
                        style: TextStyle(
                          color: isToday ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isToday ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}


class _RecurringTaskListView extends StatelessWidget {
  final List<_HabitTracker> habits;
  final DateTime today;

  const _RecurringTaskListView({required this.habits, required this.today});

  @override
  Widget build(BuildContext context) {
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recurring Task List View', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Daily and weekly routines only. Completed days use the selected task color; cancelled and missed days stay red.',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (habits.isEmpty)
            const _EmptyState(message: 'No daily or weekly recurring tasks to list yet.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecurringListHeader(weekStart: weekStart, today: today),
                  const SizedBox(height: 8),
                  ...habits.map((habit) => _RecurringListRow(habit: habit, weekStart: weekStart, today: today)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecurringListHeader extends StatelessWidget {
  final DateTime weekStart;
  final DateTime today;

  const _RecurringListHeader({required this.weekStart, required this.today});

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        const SizedBox(width: 190, child: Text('Task', style: TextStyle(fontWeight: FontWeight.w800))),
        ...List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          final isToday = _isSameDate(date, today);
          return Container(
            width: 34,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: isToday ? AppColors.accent.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(labels[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                Text('${date.day}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isToday ? AppColors.accent : Colors.black54)),
              ],
            ),
          );
        }),
        const SizedBox(width: 90, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }
}

class _RecurringListRow extends StatelessWidget {
  final _HabitTracker habit;
  final DateTime weekStart;
  final DateTime today;

  const _RecurringListRow({required this.habit, required this.weekStart, required this.today});

  @override
  Widget build(BuildContext context) {
    final taskColor = Color(habit.template.colorValue);
    final todayStatus = habit.statusFor(today);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: _softTaskDecoration(taskColor, radius: 16),
      child: Row(
        children: [
          SizedBox(
            width: 190,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: taskColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text("${habit.currentStreak} ${habit.repeatFrequency == 'Weekly' ? 'wk' : 'day'} streak", style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(7, (index) {
            final date = weekStart.add(Duration(days: index));
            final status = habit.statusFor(date);
            return Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _statusBlockColor(status, taskColor),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _isSameDate(date, today) ? taskColor : Colors.transparent, width: 2),
              ),
              child: Icon(_statusIcon(status), size: 15, color: status == _HabitDayStatus.none ? Colors.white30 : Colors.white),
            );
          }),
          SizedBox(width: 90, child: Center(child: _StatusBadge(status: todayStatus, taskColor: taskColor))),
        ],
      ),
    );
  }
}

class _HabitTrackerSection extends StatelessWidget {
  final HiveService hiveService;
  final List<_HabitTracker> habits;
  final DateTime today;

  const _HabitTrackerSection({
    required this.hiveService,
    required this.habits,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, color: AppColors.taskCompleted),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Habit & Routine Tracker', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Text('${habits.length} habits', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Consistency is built one completed day at a time.',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (habits.isEmpty)
            const _EmptyState(
              message: 'No habits found yet. Turn Repeat Task ON and choose Daily or Weekly to track routines like Go To Gym, Skincare, Study Daily, or Reading Habit.',
            )
          else
            ...habits.map(
              (habit) => _HabitCard(
                hiveService: hiveService,
                habit: habit,
                today: today,
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HiveService hiveService;
  final _HabitTracker habit;
  final DateTime today;

  const _HabitCard({required this.hiveService, required this.habit, required this.today});

  @override
  Widget build(BuildContext context) {
    final todayStatus = habit.statusFor(today);
    final taskColor = Color(habit.template.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: _softTaskDecoration(taskColor, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor(todayStatus, taskColor).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.repeat, color: taskColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: taskColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(habit.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Streak: ${habit.currentStreak} ${habit.repeatFrequency == 'Weekly' ? 'Weeks' : 'Days'} • ${habit.repeatFrequency} • ${habit.category}",
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: todayStatus, taskColor: taskColor),
            ],
          ),
          const SizedBox(height: 12),
          _HabitActivityGrid(habit: habit, today: today),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HabitStatusButton(
                  label: 'Completed',
                  icon: Icons.check_circle,
                  color: taskColor,
                  selected: todayStatus == _HabitDayStatus.completed,
                  onPressed: () => _setTodayStatus(_HabitDayStatus.completed),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HabitStatusButton(
                  label: 'Cancelled',
                  icon: Icons.cancel,
                  color: Colors.redAccent,
                  selected: todayStatus == _HabitDayStatus.cancelled,
                  onPressed: () => _setTodayStatus(_HabitDayStatus.cancelled),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HabitStatusButton(
                  label: 'Missed',
                  icon: Icons.remove_circle,
                  color: Colors.redAccent,
                  selected: todayStatus == _HabitDayStatus.missed,
                  onPressed: () => _setTodayStatus(_HabitDayStatus.missed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setTodayStatus(_HabitDayStatus status) async {
    final existing = habit.taskFor(today);
    final updated = (existing ?? habit.template).copyWith(
      dueDate: today,
      done: status == _HabitDayStatus.completed,
      status: switch (status) {
        _HabitDayStatus.completed => 'Completed',
        _HabitDayStatus.cancelled => 'Cancelled',
        _HabitDayStatus.missed => 'Missed',
        _HabitDayStatus.none => 'Not Started',
      },
      repeatTask: true,
      repeatFrequency: habit.repeatFrequency,
    );

    if (existing == null) {
      await hiveService.addTask(today, updated);
    } else {
      await hiveService.updateTaskByReference(existing, updated);
    }
  }

  Color _statusColor(_HabitDayStatus status, Color taskColor) {
    switch (status) {
      case _HabitDayStatus.completed:
        return taskColor;
      case _HabitDayStatus.cancelled:
        return Colors.redAccent;
      case _HabitDayStatus.missed:
        return Colors.redAccent;
      case _HabitDayStatus.none:
        return AppColors.taskNone;
    }
  }
}

class _HabitActivityGrid extends StatelessWidget {
  final _HabitTracker habit;
  final DateTime today;

  const _HabitActivityGrid({required this.habit, required this.today});

  @override
  Widget build(BuildContext context) {
    final startDate = today.subtract(const Duration(days: 27));
    final taskColor = Color(habit.template.colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('28-day activity', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 28,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 14,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final date = startDate.add(Duration(days: index));
            final status = habit.statusFor(date);
            final isToday = _isSameDate(date, today);
            return Tooltip(
              message: '${date.month}/${date.day}: ${_statusLabel(status)}',
              child: Container(
                decoration: BoxDecoration(
                  color: _gridColor(status, taskColor),
                  borderRadius: BorderRadius.circular(5),
                  border: isToday ? Border.all(color: AppColors.accent, width: 2) : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _gridColor(_HabitDayStatus status, Color taskColor) {
    switch (status) {
      case _HabitDayStatus.completed:
        return taskColor;
      case _HabitDayStatus.cancelled:
        return Colors.redAccent;
      case _HabitDayStatus.missed:
        return Colors.redAccent;
      case _HabitDayStatus.none:
        return const Color(0xFF263238);
    }
  }
}

class _HabitStatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  const _HabitStatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : color,
        backgroundColor: selected ? color : Colors.white,
        side: BorderSide(color: color.withOpacity(0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _HabitDayStatus status;
  final Color? taskColor;

  const _StatusBadge({required this.status, this.taskColor});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _HabitDayStatus.completed => taskColor ?? AppColors.taskCompleted,
      _HabitDayStatus.cancelled => Colors.redAccent,
      _HabitDayStatus.missed => Colors.redAccent,
      _HabitDayStatus.none => AppColors.taskNone,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(99)),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class _HabitTracker {
  final String title;
  final String category;
  final String repeatFrequency;
  final DateTime firstTrackedDate;
  final Task template;
  final Map<DateTime, Task> tasksByDate;
  final int currentStreak;

  const _HabitTracker({
    required this.title,
    required this.category,
    required this.repeatFrequency,
    required this.firstTrackedDate,
    required this.template,
    required this.tasksByDate,
    required this.currentStreak,
  });

  Task? taskFor(DateTime date) => tasksByDate[_dateOnly(date)];

  _HabitDayStatus statusFor(DateTime date) {
    final day = _dateOnly(date);
    final today = _dateOnly(DateTime.now());
    final task = tasksByDate[day];

    if (task == null) {
      if (_normalizedRepeatFrequency(repeatFrequency) == 'daily' && !day.isBefore(firstTrackedDate) && !day.isAfter(today)) {
        return _HabitDayStatus.missed;
      }
      return _HabitDayStatus.none;
    }

    if (_isTaskCompleted(task)) return _HabitDayStatus.completed;
    if (_isTaskCancelled(task) || _isTaskMissed(task)) return _HabitDayStatus.missed;
    if (_normalizedRepeatFrequency(repeatFrequency) == 'daily' && !day.isAfter(today)) return _HabitDayStatus.missed;
    if (day.isBefore(today)) return _HabitDayStatus.missed;
    return _HabitDayStatus.none;
  }

  static List<_HabitTracker> buildHabits(Map<DateTime, List<Task>> allTasksByDate, DateTime today) {
    final grouped = <String, List<MapEntry<DateTime, Task>>>{};

    for (final entry in allTasksByDate.entries) {
      final date = _dateOnly(entry.key);
      for (final task in entry.value) {
        if (!_isHabitTask(task)) continue;
        final key = task.task.trim().toLowerCase();
        if (key.isEmpty) continue;
        grouped.putIfAbsent(key, () => <MapEntry<DateTime, Task>>[]).add(MapEntry(date, task));
      }
    }

    final habits = grouped.entries.map((entry) {
      final records = entry.value..sort((a, b) => b.key.compareTo(a.key));
      final byDate = <DateTime, Task>{};
      for (final record in records) {
        final existing = byDate[record.key];
        if (existing == null || _statusPriority(record.value) > _statusPriority(existing)) {
          byDate[record.key] = record.value;
        }
      }
      final template = records.first.value;
      return _HabitTracker(
        title: template.task,
        category: template.category,
        repeatFrequency: template.repeatFrequency ?? 'Daily',
        firstTrackedDate: records.map((record) => record.key).reduce((a, b) => a.isBefore(b) ? a : b),
        template: template,
        tasksByDate: byDate,
        currentStreak: _calculateHabitStreak(byDate, today, template.repeatFrequency ?? 'Daily'),
      );
    }).toList()
      ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    return habits;
  }

  static bool _isHabitTask(Task task) {
    final frequency = _normalizedRepeatFrequency(task.repeatFrequency);
    return task.repeatTask && (frequency == 'daily' || frequency == 'weekly');
  }

  static String _normalizedRepeatFrequency(String? repeatFrequency) => (repeatFrequency ?? '').trim().toLowerCase();

  static int _calculateHabitStreak(Map<DateTime, Task> tasksByDate, DateTime today, String repeatFrequency) {
    return _normalizedRepeatFrequency(repeatFrequency) == 'weekly'
        ? _calculateWeeklyHabitStreak(tasksByDate, today)
        : _calculateDailyHabitStreak(tasksByDate, today);
  }

  static int _calculateDailyHabitStreak(Map<DateTime, Task> tasksByDate, DateTime today) {
    var cursor = _dateOnly(today);
    var streak = 0;

    if (!_isTaskCompleted(tasksByDate[cursor])) return 0;

    while (_isTaskCompleted(tasksByDate[cursor])) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static int _calculateWeeklyHabitStreak(Map<DateTime, Task> tasksByDate, DateTime today) {
    var weekStart = _dateOnly(today).subtract(Duration(days: today.weekday - 1));
    var streak = 0;

    if (!_weekHasCompletedTask(tasksByDate, weekStart)) {
      weekStart = weekStart.subtract(const Duration(days: 7));
    }

    while (_weekHasCompletedTask(tasksByDate, weekStart)) {
      streak++;
      weekStart = weekStart.subtract(const Duration(days: 7));
    }

    return streak;
  }

  static bool _weekHasCompletedTask(Map<DateTime, Task> tasksByDate, DateTime weekStart) {
    for (var index = 0; index < 7; index++) {
      if (_isTaskCompleted(tasksByDate[weekStart.add(Duration(days: index))])) return true;
    }
    return false;
  }

  static bool _isTaskCompleted(Task? task) => task != null && (task.done || _normalizedStatus(task) == 'completed');

  static bool _isTaskCancelled(Task task) => _normalizedStatus(task) == 'cancelled';

  static bool _isTaskMissed(Task task) {
    final status = _normalizedStatus(task);
    return status == 'missed' || status == 'overdue';
  }

  static int _statusPriority(Task task) {
    if (_isTaskCompleted(task)) return 3;
    if (_isTaskCancelled(task) || _isTaskMissed(task)) return 2;
    return 1;
  }

  static String _normalizedStatus(Task task) => task.status.trim().toLowerCase();
}

Color _statusBlockColor(_HabitDayStatus status, Color taskColor) {
  switch (status) {
    case _HabitDayStatus.completed:
      return taskColor;
    case _HabitDayStatus.cancelled:
    case _HabitDayStatus.missed:
      return Colors.redAccent;
    case _HabitDayStatus.none:
      return const Color(0xFF263238);
  }
}

IconData _statusIcon(_HabitDayStatus status) {
  switch (status) {
    case _HabitDayStatus.completed:
      return Icons.check;
    case _HabitDayStatus.cancelled:
    case _HabitDayStatus.missed:
      return Icons.close;
    case _HabitDayStatus.none:
      return Icons.remove;
  }
}

enum _HabitDayStatus { completed, cancelled, missed, none }

String _statusLabel(_HabitDayStatus status) {
  switch (status) {
    case _HabitDayStatus.completed:
      return 'Completed';
    case _HabitDayStatus.cancelled:
      return 'Cancelled';
    case _HabitDayStatus.missed:
      return 'Missed';
    case _HabitDayStatus.none:
      return 'Not set';
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _DailyTaskCards extends StatelessWidget {
  final List<Task> tasks;

  const _DailyTaskCards({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recurring Task Cards', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const _EmptyState(message: 'No daily or weekly recurring tasks scheduled today. Add a repeating habit to start building a streak.')
          else
            ...tasks.map((task) => _TaskJourneyCard(task: task)),
        ],
      ),
    );
  }
}

class _TaskJourneyCard extends StatelessWidget {
  final Task task;

  const _TaskJourneyCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.done || task.status == 'Completed';
    final taskColor = Color(task.colorValue);
    final progress = isCompleted ? 1.0 : task.status == 'In Progress' ? 0.5 : 0.12;
    final difficulty = _difficultyLabel(task);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _softTaskDecoration(taskColor, radius: 20, borderOpacity: isCompleted ? 0.65 : 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: taskColor),
              const SizedBox(width: 8),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: taskColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(task.task, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text('${task.estimatedMinutes}m', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          if (task.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(task.description, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            color: isCompleted ? taskColor : taskColor.withOpacity(0.55),
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: task.category, icon: Icons.category, color: taskColor),
              _Tag(label: task.priority, icon: Icons.flag, color: taskColor),
              _Tag(label: difficulty, icon: Icons.speed, color: taskColor),
              if (task.repeatTask) _Tag(label: '${task.repeatFrequency ?? 'Recurring'} habit', icon: Icons.repeat, color: taskColor),
            ],
          ),
        ],
      ),
    );
  }

  String _difficultyLabel(Task task) {
    if (task.urgent && task.important) return 'High focus';
    if (task.estimatedMinutes >= 90) return 'Deep work';
    if (task.estimatedMinutes <= 20) return 'Quick win';
    return 'Balanced';
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _Tag({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PerformanceInsights extends StatelessWidget {
  final _JourneyStats stats;

  const _PerformanceInsights({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Insights', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _InsightRow(icon: Icons.calendar_month, title: 'Most productive month', value: stats.mostProductiveMonth),
          _InsightRow(icon: Icons.emoji_events, title: 'Best streak period', value: stats.bestStreakPeriod),
          _InsightRow(icon: Icons.warning_amber, title: 'Frequently skipped tasks', value: stats.frequentlySkippedCategory),
          _InsightRow(icon: Icons.repeat, title: 'Habit consistency score', value: '${(stats.habitConsistencyScore * 100).round()}%'),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InsightRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(value, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


BoxDecoration _softTaskDecoration(Color taskColor, {required double radius, double borderOpacity = 0.24}) {
  return BoxDecoration(
    color: taskColor.withOpacity(0.10),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: taskColor.withOpacity(borderOpacity)),
    boxShadow: [
      BoxShadow(
        color: taskColor.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

const _monthNames = [
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
  'December',
];
