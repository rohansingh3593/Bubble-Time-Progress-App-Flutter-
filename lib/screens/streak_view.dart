import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/dashboard_themes.dart';
import '../models/instruction.dart';
import '../models/journal_entry.dart';
import '../models/journey_entry.dart';
import '../models/rank_profile.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/rank_profile_card.dart';
import 'journal_view.dart';
import 'journey_timeline_view.dart';

class StreakView extends StatelessWidget {
  final HiveService hiveService;
  final VoidCallback? onGoToDashboard;

  const StreakView({super.key, required this.hiveService, this.onGoToDashboard});

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
          final style = _streakThemeStyle(hiveService);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroStreakCard(stats: stats, style: style),
                const SizedBox(height: 14),
                RankProfileCard(
                  profile: rankProfile,
                  onUsernameChanged: hiveService.setUsername,
                  onTap: () => Navigator.of(context).push(
                    JournalView.route(hiveService: hiveService, onGoToDashboard: onGoToDashboard),
                  ),
                  userProfile: hiveService.getUserProfile(),
                  onJourneyTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => JourneyTimelineView(hiveService: hiveService),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TodayWeeklyPanel(stats: stats),
                const SizedBox(height: 14),
                _WeeklyDateIndicator(today: stats.today),
                const SizedBox(height: 14),
                _RecurringTaskListView(hiveService: hiveService, habits: habits, today: stats.today),
                const SizedBox(height: 14),
                _InstructionStreakPanel(hiveService: hiveService, today: stats.today),
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
                _DailyTaskCards(hiveService: hiveService, tasks: stats.todayTasks, today: stats.today),
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


class _InstructionStreakPanel extends StatelessWidget {
  final HiveService hiveService;
  final DateTime today;

  const _InstructionStreakPanel({required this.hiveService, required this.today});

  @override
  Widget build(BuildContext context) {
    final instructions = hiveService.getStandaloneInstructions().where((instruction) => instruction.enabled).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📘 Instruction Streaks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          if (instructions.isEmpty)
            const Text('No active standalone instructions yet.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))
          else
            ...instructions.map((instruction) {
              final entry = hiveService.instructionEntryForDate(instruction, today);
              final color = entry?.followed == true
                  ? Colors.green
                  : entry?.missed == true
                      ? Colors.red
                      : Color(instruction.colorValue);
              final bubbleDates = _instructionBubbleDates(today);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rule_folder_outlined, color: color),
                        const SizedBox(width: 10),
                        Expanded(child: Text(instruction.name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
                        Text('${hiveService.instructionCurrentStreak(instruction, today)} streak', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: bubbleDates.map((date) {
                          final dateEntry = hiveService.instructionEntryForDate(instruction, date);
                          return _InstructionDateBubble(date: date, entry: dateEntry, instruction: instruction, today: today);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}


List<DateTime> _instructionBubbleDates(DateTime today) {
  final normalizedToday = DateTime(today.year, today.month, today.day);
  return List<DateTime>.generate(14, (index) => normalizedToday.subtract(Duration(days: 13 - index)));
}

class _InstructionDateBubble extends StatelessWidget {
  final DateTime date;
  final InstructionHistoryEntry? entry;
  final InstructionRule instruction;
  final DateTime today;

  const _InstructionDateBubble({required this.date, required this.entry, required this.instruction, required this.today});

  @override
  Widget build(BuildContext context) {
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    final levelIndex = entry?.hasLevel == true ? instruction.levels.indexWhere((level) => level.id == entry!.levelId) : -1;
    final optionIndex = entry?.hasOption == true ? instruction.options.indexWhere((option) => option.id == entry!.optionId) : -1;
    final repeatedMisses = instruction.history.where((item) => item.missed && !item.date.isAfter(date)).length;
    final emoji = isFuture
        ? '➖'
        : (entry?.hasLevel == true || entry?.hasOption == true)
            ? (entry?.hasOption == true ? (optionIndex >= 2 ? '🤩' : optionIndex == 1 ? '😊' : '🙂') : (levelIndex >= 2 ? '🤩' : levelIndex == 1 ? '😊' : '🙂'))
            : entry?.followed == true
                ? '🙂'
                : entry?.missed == true
                    ? (repeatedMisses >= 5 ? '😵' : repeatedMisses >= 3 ? '😫' : repeatedMisses >= 2 ? '😠' : '😞')
                    : '➖';
    final theme = context.dashboardTheme;
    final color = entry?.followed == true
        ? theme.success
        : entry?.missed == true
            ? theme.danger
            : theme.muted;
    final label = (entry?.hasLevel == true || entry?.hasOption == true) ? entry!.selectionSummary : entry?.status ?? 'Future / Pending';
    return Tooltip(
      message: '${date.day}/${date.month}/${date.year} • $label',
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.16),
          border: Border.all(color: color.withOpacity(0.55), width: 1.2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
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
      final eligibleTasks = tasks.where((task) => task.status.trim().toLowerCase() != 'cancelled').toList();
      final completedTasks = eligibleTasks.where(_isCompletedTask).toList();
      final activeTasks = tasks.where((task) {
        final status = task.status.trim().toLowerCase();
        return _isCompletedTask(task) || status == 'cancelled' || status == 'missed' || status == 'overdue';
      }).toList();
      final completedColorValue = completedTasks.isEmpty ? null : completedTasks.first.colorValue;

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
        completedColorValue: completedColorValue,
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
        .where((task) => task.repeatTask && task.routineEnabled && task.dueDate.year == today.year)
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

  static bool _isCompletedTask(Task task) {
    final status = task.status.trim().toLowerCase();
    return task.done || status == 'completed' || status == 'complete';
  }

  static bool _isAllowedRecurringTask(Task task) {
    final frequency = _normalizedRepeatFrequency(task.repeatFrequency);
    return task.repeatTask && task.routineEnabled && (frequency == 'daily' || frequency == 'weekly');
  }

  static String _normalizedRepeatFrequency(String? repeatFrequency) {
    final normalized = (repeatFrequency ?? '').trim().toLowerCase();
    return normalized.isEmpty ? 'daily' : normalized;
  }

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
  final int? completedColorValue;

  final bool journaled;

  const _DayActivity({
    required this.total,
    required this.completed,
    required this.activityCount,
    this.completedColorValue,
    this.journaled = false,
  });
  const _DayActivity.empty() : total = 0, completed = 0, activityCount = 0, completedColorValue = null, journaled = false;

  _DayActivity copyWith({bool? journaled}) {
    return _DayActivity(
      total: total,
      completed: completed,
      activityCount: activityCount,
      completedColorValue: completedColorValue,
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
  final DashboardThemeStyle style;

  const _HeroStreakCard({required this.stats, required this.style});

  @override
  Widget build(BuildContext context) {
    final gradientColors = style.heroGradient.isNotEmpty ? style.heroGradient : [style.primary, style.secondary, style.accent];
    final contentColor = AppThemeColors.readableTextOn(gradientColors.first, style);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: style.primary.withOpacity(0.24),
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
                decoration: BoxDecoration(color: contentColor.withOpacity(0.20), shape: BoxShape.circle),
                child: Icon(Icons.local_fire_department, color: contentColor, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your consistency journey',
                  style: TextStyle(color: contentColor, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${stats.currentDailyStreak}',
            style: TextStyle(color: contentColor, fontSize: 58, fontWeight: FontWeight.w900, height: 0.95),
          ),
          Text('day active streak', style: TextStyle(color: contentColor, fontSize: 16)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroMetric(label: 'Weekly streak', value: '${stats.currentWeeklyStreak} wk', contentColor: contentColor)),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Longest', value: '${stats.longestStreak} days', contentColor: contentColor)),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Productivity', value: '${(stats.productivityRatio * 100).round()}%', contentColor: contentColor)),
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
  final Color contentColor;

  const _HeroMetric({required this.label, required this.value, required this.contentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: contentColor.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: contentColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: contentColor, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: contentColor.withOpacity(0.82), fontSize: 11)),
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
    final style = _streakThemeStyle(HiveService.instance);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: style.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stats.year} Year Progress Overview',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: style.textPrimary),
                ),
              ),
              Text('${(stats.yearCalendarRatio * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w900, color: style.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: stats.yearCalendarRatio.clamp(0.0, 1.0).toDouble(),
            minHeight: 12,
            borderRadius: BorderRadius.circular(99),
            color: style.primary,
            backgroundColor: style.primary.withOpacity(0.14),
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
          const Text('Completed days use the selected task color; missed days stay red.', style: TextStyle(color: Colors.black54)),
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
                    border: isToday ? Border.all(color: color, width: 2) : null,
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
    if (activity.completed > 0) return Color(activity.completedColorValue ?? AppColors.taskCompleted.value);
    if (activity.activityCount > 0) return Colors.redAccent;
    if (activity.journaled) return AppColors.accent.withOpacity(0.65);
    return const Color(0xFF263238);
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


class _StreakEmojiLegend extends StatelessWidget {
  const _StreakEmojiLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('🤩', 'Perfect'),
      ('😊', 'Completed'),
      ('😞', 'Missed'),
      ('😠', 'Repeated'),
      ('➖', 'Future'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.black12)),
          child: Text('${item.$1} ${item.$2}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        );
      }).toList(),
    );
  }
}

class _RecurringTaskListView extends StatelessWidget {
  final HiveService hiveService;
  final List<_HabitTracker> habits;
  final DateTime today;

  const _RecurringTaskListView({required this.hiveService, required this.habits, required this.today});

  @override
  Widget build(BuildContext context) {
    final boardHabits = habits.where(_isStreakBoardHabit).toList();
    final boardDates = _buildStreakBoardDates(boardHabits, today);
    final projectItems = _ProjectProgressItem.buildFromMap(hiveService.getAllTasksByDate());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Streak Board', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'A living emoji habit map. Completed days use the selected task color, missed days stay red, and future/unset days stay neutral.',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const _StreakEmojiLegend(),
          const SizedBox(height: 14),
          if (boardHabits.isEmpty)
            const _EmptyState(message: 'No active daily or weekly recurring habits yet. Add a repeating task to build a streak board.')
          else
            _DailyStreakBoard(
              hiveService: hiveService,
              habits: boardHabits,
              dates: boardDates,
              today: today,
            ),
          const SizedBox(height: 18),
          _ProjectProgressSection(items: projectItems),
        ],
      ),
    );
  }
}

class _ProjectProgressSection extends StatelessWidget {
  final List<_ProjectProgressItem> items;

  const _ProjectProgressSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Project Progress (Non-Routine)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Non-repeating tasks are tracked as project milestones and phases, not habit streak blocks.',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyState(message: 'No non-routine project tasks found yet. Add a non-repeating task with phases to track progress.')
        else
          ...items.map((item) => _ProjectProgressCard(item: item)),
      ],
    );
  }
}

class _ProjectProgressCard extends StatelessWidget {
  final _ProjectProgressItem item;
  const _ProjectProgressCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final progress = item.totalPhases == 0 ? 0.0 : item.completedPhases / item.totalPhases;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.projectTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(99)),
          const SizedBox(height: 6),
          Text('${item.completedPhases} / ${item.totalPhases} phases completed • ${(progress * 100).round()}% progress', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...item.phases.map((phase) {
            final icon = switch (phase.status.toLowerCase()) {
              'completed' => '✅',
              'in progress' => '🔄',
              'cancelled' => '⛔',
              _ => '⏳',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('$icon ${phase.title}${phase.description.isEmpty ? '' : ' — ${phase.description}'}'),
            );
          }),
        ],
      ),
    );
  }
}

class _ProjectProgressItem {
  final String projectTitle;
  final List<_ProjectPhaseItem> phases;
  const _ProjectProgressItem({required this.projectTitle, required this.phases});

  int get totalPhases => phases.length;
  int get completedPhases => phases.where((p) => p.status.toLowerCase() == 'completed').length;

  static List<_ProjectProgressItem> buildFromMap(Map<DateTime, List<Task>> allTasksByDate) {
    final tasks = allTasksByDate.values.expand((entries) => entries).where((task) => !task.repeatTask).toList();
    final grouped = <String, List<_ProjectPhaseItem>>{};
    final phaseTaskPattern = RegExp(r'^(.*?)\s*[-:|]\s*phase\s*(\d+)\s*[-:|]?\s*(.*)$', caseSensitive: false);

    for (final task in tasks) {
      final title = task.task.trim();
      final phaseRowsFromDescription = _parsePhasesFromDescription(task.description);
      if (phaseRowsFromDescription.isNotEmpty) {
        grouped.putIfAbsent(title, () => <_ProjectPhaseItem>[]).addAll(phaseRowsFromDescription);
        continue;
      }
      final match = phaseTaskPattern.firstMatch(title);
      final status = task.status.trim();
      if (match != null) {
        final baseTitle = match.group(1)!.trim();
        final phaseNumber = match.group(2)!.trim();
        final phaseNameSuffix = (match.group(3) ?? '').trim();
        final phaseTitle = phaseNameSuffix.isEmpty ? 'Phase $phaseNumber' : 'Phase $phaseNumber: $phaseNameSuffix';
        grouped.putIfAbsent(baseTitle, () => <_ProjectPhaseItem>[]).add(
          _ProjectPhaseItem(title: phaseTitle, description: task.description.trim(), status: status, phaseOrder: int.tryParse(phaseNumber) ?? 999),
        );
      } else {
        grouped.putIfAbsent(title, () => <_ProjectPhaseItem>[]).add(
          _ProjectPhaseItem(title: 'Phase 1', description: task.description.trim(), status: status, phaseOrder: 1),
        );
      }
    }

    final items = grouped.entries.map((entry) {
      final phases = [...entry.value]..sort((a, b) => a.phaseOrder.compareTo(b.phaseOrder));
      return _ProjectProgressItem(projectTitle: entry.key, phases: phases);
    }).toList();
    items.sort((a, b) => a.projectTitle.toLowerCase().compareTo(b.projectTitle.toLowerCase()));
    return items;
  }

  static List<_ProjectPhaseItem> _parsePhasesFromDescription(String description) {
    const marker = '---PHASES---';
    final markerIndex = description.indexOf(marker);
    if (markerIndex == -1) return const <_ProjectPhaseItem>[];
    final phaseChunk = description.substring(markerIndex + marker.length).trim();
    final lines = phaseChunk.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final phases = <_ProjectPhaseItem>[];
    for (var index = 0; index < lines.length; index++) {
      final parts = lines[index].split('|');
      if (parts.length < 3) continue;
      final phaseName = parts[0].trim().isEmpty ? 'Phase ${index + 1}' : parts[0].trim();
      final phaseDescription = parts[1].trim();
      final phaseStatus = parts[2].trim().isEmpty ? 'Not Started' : parts[2].trim();
      phases.add(_ProjectPhaseItem(title: phaseName, description: phaseDescription, status: phaseStatus, phaseOrder: index + 1));
    }
    return phases;
  }
}

class _ProjectPhaseItem {
  final String title;
  final String description;
  final String status;
  final int phaseOrder;
  const _ProjectPhaseItem({required this.title, required this.description, required this.status, required this.phaseOrder});
}

class _DailyStreakBoard extends StatefulWidget {
  final HiveService hiveService;
  final List<_HabitTracker> habits;
  final List<DateTime> dates;
  final DateTime today;

  const _DailyStreakBoard({required this.hiveService, required this.habits, required this.dates, required this.today});

  @override
  State<_DailyStreakBoard> createState() => _DailyStreakBoardState();
}

class _DailyStreakBoardState extends State<_DailyStreakBoard> {
  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToTodayAfterLayout();
  }

  @override
  void didUpdateWidget(covariant _DailyStreakBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dates.length != widget.dates.length || !_isSameDate(oldWidget.today, widget.today)) {
      _scrollToTodayAfterLayout();
    }
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width - 32;
        final layout = _StreakBoardLayout.fromWidth(availableWidth, widget.habits.length);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: layout.taskColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StreakBoardTaskHeader(color: AppColors.accent, layout: layout),
                  SizedBox(height: layout.rowSpacing),
                  ...widget.habits.map((habit) => _StreakBoardTaskNameCell(hiveService: widget.hiveService, habit: habit, today: widget.today, layout: layout)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _dateScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StreakBoardDateHeader(dates: widget.dates, today: widget.today, layout: layout),
                    SizedBox(height: layout.rowSpacing),
                    ...widget.habits.asMap().entries.map((entry) => _StreakBoardActivityRow(
                          hiveService: widget.hiveService,
                          habit: entry.value,
                          rowIndex: entry.key,
                          dates: widget.dates,
                          today: widget.today,
                          layout: layout,
                        )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _scrollToTodayAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dateScrollController.hasClients) return;
      _dateScrollController.jumpTo(_dateScrollController.position.maxScrollExtent);
    });
  }
}

class _StreakBoardLayout {
  final double taskColumnWidth;
  final double blockSize;
  final double rowHeight;
  final double headerHeight;
  final double dateCellWidth;
  final double cellSpacing;
  final double rowSpacing;
  final double horizontalPadding;
  final double titleFontSize;
  final double streakFontSize;
  final double dateFontSize;
  final double dayFontSize;
  final double iconSize;
  final double radius;

  const _StreakBoardLayout({
    required this.taskColumnWidth,
    required this.blockSize,
    required this.rowHeight,
    required this.headerHeight,
    required this.dateCellWidth,
    required this.cellSpacing,
    required this.rowSpacing,
    required this.horizontalPadding,
    required this.titleFontSize,
    required this.streakFontSize,
    required this.dateFontSize,
    required this.dayFontSize,
    required this.iconSize,
    required this.radius,
  });

  factory _StreakBoardLayout.fromWidth(double width, int habitCount) {
    final isTiny = width < 340;
    final isSmall = width < 430;
    final isLarge = width >= 720;
    final taskColumnWidth = _clampDouble(width * (isLarge ? 0.28 : 0.36), isTiny ? 104 : 118, isLarge ? 210 : 165);
    final gridWidth = math.max(132, width - taskColumnWidth);
    final targetVisibleDates = isLarge ? 12.0 : isSmall ? 5.0 : 7.0;
    final cellSpacing = isTiny ? 2.0 : isSmall ? 2.5 : isLarge ? 4.0 : 3.0;
    final blockSize = _clampDouble((gridWidth / targetVisibleDates) - (cellSpacing * 2), isTiny ? 28 : 32, isLarge ? 48 : 42);
    final rowSpacing = habitCount > 8 || isTiny ? 8.0 : 12.0;

    return _StreakBoardLayout(
      taskColumnWidth: taskColumnWidth,
      blockSize: blockSize,
      rowHeight: math.max(54, blockSize + 12),
      headerHeight: blockSize + (isTiny ? 18 : 22),
      dateCellWidth: blockSize,
      cellSpacing: cellSpacing,
      rowSpacing: rowSpacing,
      horizontalPadding: isTiny ? 6 : 8,
      titleFontSize: isTiny ? 10.5 : isSmall ? 11.5 : 12.5,
      streakFontSize: isTiny ? 9 : 10,
      dateFontSize: isTiny ? 9.5 : 11,
      dayFontSize: isTiny ? 11.5 : 13,
      iconSize: _clampDouble(blockSize * 0.48, 14, 20),
      radius: _clampDouble(blockSize * 0.30, 9, 14),
    );
  }
}

class _StreakBoardTaskHeader extends StatelessWidget {
  final Color color;
  final _StreakBoardLayout layout;

  const _StreakBoardTaskHeader({required this.color, required this.layout});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: layout.headerHeight,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: layout.horizontalPadding / 2),
      child: Text('Habit', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: layout.titleFontSize + 1)),
    );
  }
}

class _StreakBoardDateHeader extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime today;
  final _StreakBoardLayout layout;

  const _StreakBoardDateHeader({required this.dates, required this.today, required this.layout});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: dates.map((date) {
        final isToday = _isSameDate(date, today);
        return Container(
          width: layout.dateCellWidth,
          height: layout.headerHeight,
          margin: EdgeInsets.symmetric(horizontal: layout.cellSpacing),
          padding: EdgeInsets.symmetric(vertical: layout.cellSpacing),
          decoration: BoxDecoration(
            color: isToday ? AppColors.accent.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(layout.radius),
            border: Border.all(color: isToday ? AppColors.accent : Colors.transparent, width: 1.4),
            boxShadow: isToday
                ? [BoxShadow(color: AppColors.accent.withOpacity(0.24), blurRadius: 14, spreadRadius: 1)]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_weekdayLabel(date), style: TextStyle(fontSize: layout.dateFontSize, color: isToday ? AppColors.accent : Colors.black54, fontWeight: FontWeight.w800)),
                SizedBox(height: layout.cellSpacing / 2),
                Text('${date.day}', style: TextStyle(fontSize: layout.dayFontSize, color: isToday ? AppColors.accent : Colors.black87, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StreakBoardTaskNameCell extends StatelessWidget {
  final HiveService hiveService;
  final _HabitTracker habit;
  final DateTime today;
  final _StreakBoardLayout layout;

  const _StreakBoardTaskNameCell({required this.hiveService, required this.habit, required this.today, required this.layout});

  @override
  Widget build(BuildContext context) {
    final taskColor = _themeDerivedTaskColor(hiveService, habit.template.colorValue);
    return InkWell(
      borderRadius: BorderRadius.circular(layout.radius),
      onTap: () => _openTaskPerformanceDetail(context, hiveService, habit, today),
      child: Container(
        height: layout.rowHeight,
        margin: EdgeInsets.only(bottom: layout.rowSpacing, right: layout.cellSpacing * 2),
        padding: EdgeInsets.symmetric(horizontal: layout.horizontalPadding),
        decoration: BoxDecoration(
          color: taskColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(layout.radius + 6),
          border: Border.all(color: taskColor.withOpacity(0.18)),
          boxShadow: [BoxShadow(color: taskColor.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(width: layout.iconSize * 0.7, height: layout.iconSize * 0.7, decoration: BoxDecoration(color: taskColor, shape: BoxShape.circle)),
            SizedBox(width: layout.cellSpacing * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(habit.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: layout.titleFontSize)),
                  Text('${habit.repeatFrequency} • ${habit.currentStreak} ${habit.repeatFrequency == 'Weekly' ? 'wk' : 'day'} streak', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: layout.streakFontSize)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBoardActivityRow extends StatelessWidget {
  final HiveService hiveService;
  final _HabitTracker habit;
  final int rowIndex;
  final List<DateTime> dates;
  final DateTime today;
  final _StreakBoardLayout layout;

  const _StreakBoardActivityRow({required this.hiveService, required this.habit, required this.rowIndex, required this.dates, required this.today, required this.layout});

  @override
  Widget build(BuildContext context) {
    final taskColor = _themeDerivedTaskColor(hiveService, habit.template.colorValue);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 420 + (rowIndex * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(offset: Offset(0, 10 * (1 - progress)), child: child),
      ),
      child: SizedBox(
        height: layout.rowHeight + layout.rowSpacing,
        child: Row(
          children: dates.map((date) {
          final status = _boardStatusFor(habit, date, today);
          final blockColor = _habitActivityBlockColor(habit, date, status, taskColor);
          final emoji = _habitMoodEmojiForDate(hiveService, habit, date, today, status);
          final isToday = _isSameDate(date, today);
          return Tooltip(
            message: '${habit.title} • ${_formatBoardDate(date)} • ${_statusLabel(status)} • $emoji',
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.86, end: 1.0),
              duration: Duration(milliseconds: 220 + (dates.indexOf(date) * 12)),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: isToday ? scale * 1.04 : scale, child: child),
              child: Container(
                width: layout.blockSize,
                height: layout.blockSize,
                margin: EdgeInsets.symmetric(horizontal: layout.cellSpacing),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(layout.radius + 4),
                  border: Border.all(color: isToday ? const Color(0xFFFFA726) : Colors.white.withOpacity(0.16), width: isToday ? 2.4 : 1),
                  boxShadow: [
                    if (isToday) BoxShadow(color: const Color(0xFF8E24AA).withOpacity(0.36), blurRadius: 16, spreadRadius: 1),
                    if (status == _HabitDayStatus.completed) BoxShadow(color: blockColor.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(emoji, style: TextStyle(fontSize: layout.iconSize + 2)),
              ),
            ),
          );
          }).toList(),
        ),
      ),
    );
  }
}

double _clampDouble(double value, double min, double max) => value < min ? min : value > max ? max : value;

bool _isStreakBoardHabit(_HabitTracker habit) {
  final frequency = _HabitTracker._normalizedRepeatFrequency(habit.repeatFrequency);
  return frequency == 'daily' || frequency == 'weekly';
}

List<DateTime> _buildStreakBoardDates(List<_HabitTracker> habits, DateTime today) {
  if (habits.isEmpty) return const <DateTime>[];
  final endDate = _dateOnly(today);
  final firstDate = habits.map((habit) => _dateOnly(habit.firstTrackedDate)).reduce((a, b) => a.isBefore(b) ? a : b);
  final dates = <DateTime>[];
  var cursor = firstDate;
  while (!cursor.isAfter(endDate)) {
    dates.add(cursor);
    cursor = cursor.add(const Duration(days: 1));
  }
  return dates;
}

_HabitDayStatus _boardStatusFor(_HabitTracker habit, DateTime date, DateTime today) {
  final day = _dateOnly(date);
  if (day.isAfter(_dateOnly(today)) || day.isBefore(_dateOnly(habit.firstTrackedDate))) return _HabitDayStatus.none;
  return habit.statusFor(day);
}

String _habitMoodEmojiForDate(HiveService hiveService, _HabitTracker habit, DateTime date, DateTime today, _HabitDayStatus status) {
  final day = _dateOnly(date);
  if (status == _HabitDayStatus.none || day.isAfter(_dateOnly(today))) return '➖';
  if (status == _HabitDayStatus.completed) {
    final linkedInstructions = hiveService
        .getTaskLinkedInstructions()
        .where((instruction) => instruction.enabled && instruction.isLinkedToTask(habit.title))
        .toList();
    if (linkedInstructions.isEmpty) return '🙂';
    final followed = linkedInstructions.where((instruction) {
      return hiveService.instructionEntryForDate(instruction, day)?.followed ?? false;
    }).length;
    if (followed == linkedInstructions.length) return '🤩';
    if (followed / linkedInstructions.length >= 0.75) return '😊';
    return '😐';
  }
  final missedCount = _habitMissedRunEndingAt(habit, day);
  if (missedCount >= 7) return '😵';
  if (missedCount >= 4) return '😫';
  if (missedCount >= 2) return '😠';
  return '😞';
}

int _habitMissedRunEndingAt(_HabitTracker habit, DateTime date) {
  var cursor = _dateOnly(date);
  var count = 0;
  while (!cursor.isBefore(_dateOnly(habit.firstTrackedDate))) {
    final status = habit.statusFor(cursor);
    if (status == _HabitDayStatus.missed || status == _HabitDayStatus.cancelled) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
      continue;
    }
    break;
  }
  return count;
}

String _weekdayLabel(DateTime date) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

String _formatBoardDate(DateTime date) => '${_weekdayLabel(date)} ${date.day} ${_monthNames[date.month - 1]} ${date.year}';

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
    final style = _streakThemeStyle(hiveService);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, color: habits.isEmpty ? _themeAccent(hiveService) : _themeDerivedTaskColor(hiveService, habits.first.template.colorValue)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Habit & Routine Tracker', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: style.textPrimary)),
              ),
              Text('${habits.length} habits', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Consistency is built one completed day at a time.',
            style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (habits.isEmpty)
            const _EmptyState(
              message: 'No habits found yet. Turn Repeat Task ON and choose Daily or Weekly to track routines like Go To Gym, Skincare, Study Daily, or Reading Habit.',
            )
          else
            ...habits.asMap().entries.map(
              (entry) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 380 + (entry.key * 120)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - value)),
                    child: child,
                  ),
                ),
                child: _HabitCard(
                  hiveService: hiveService,
                  habit: entry.value,
                  today: today,
                ),
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
    final style = _streakThemeStyle(hiveService);
    final todayStatus = habit.statusFor(today);
    final taskColor = _themeDerivedTaskColor(hiveService, habit.template.colorValue);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openTaskPerformanceDetail(context, hiveService, habit, today),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.97, end: 1.0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: _softTaskDecoration(taskColor, radius: 22, style: _streakThemeStyle(hiveService)),
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
                        Expanded(child: Text(habit.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: style.textPrimary))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Streak: ${habit.currentStreak} ${habit.repeatFrequency == 'Weekly' ? 'Weeks' : 'Days'} • ${habit.repeatFrequency} • ${habit.category}",
                      style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: todayStatus, taskColor: taskColor, style: style),
            ],
          ),
          const SizedBox(height: 14),
          _HabitActivityGrid(hiveService: hiveService, habit: habit, today: today),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final buttonSpacing = compact ? 6.0 : 8.0;
              final buttonFontSize = compact ? 15.0 : 16.0;
              final horizontalPadding = compact ? 8.0 : 10.0;
              return Row(
                children: [
                  Expanded(
                    child: _HabitStatusButton(
                      label: 'Completed',
                      icon: Icons.check_circle,
                      color: taskColor,
                      selected: todayStatus == _HabitDayStatus.completed,
                      fontSize: buttonFontSize,
                      horizontalPadding: horizontalPadding,
                      style: style,
                      onPressed: () => _setTodayStatus(context, _HabitDayStatus.completed),
                    ),
                  ),
                  SizedBox(width: buttonSpacing),
                  Expanded(
                    child: _HabitStatusButton(
                      label: 'Missed',
                      icon: Icons.remove_circle,
                      color: style.accent,
                      selected: todayStatus == _HabitDayStatus.missed,
                      fontSize: buttonFontSize,
                      horizontalPadding: horizontalPadding,
                      style: style,
                      onPressed: () => _setTodayStatus(context, _HabitDayStatus.missed),
                    ),
                  ),
                ],
              );
            },
          ),
          ],
        ),
      ),
      ),
    );
  }

  bool _isOccurrenceLocked(Task task) {
    final status = task.status.trim().toLowerCase();
    return task.done || status == 'completed' || status == 'cancelled' || status == 'missed' || status == 'overdue';
  }

  String _occurrenceLabel() {
    final normalized = habit.repeatFrequency.trim().toLowerCase();
    switch (normalized) {
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

  void _showLockedMessage(BuildContext context, Task existing) {
    final normalized = existing.status.trim().toLowerCase();
    final statusLabel = existing.done || normalized == 'completed' ? 'completed' : existing.status.toLowerCase();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task already $statusLabel for ${_occurrenceLabel()}. It unlocks in the next occurrence.')),
    );
  }

  Future<void> _setTodayStatus(BuildContext context, _HabitDayStatus status) async {
    final existing = habit.taskFor(today);
    if (existing != null && _isOccurrenceLocked(existing)) {
      _showLockedMessage(context, existing);
      return;
    }
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
      routineEnabled: habit.template.routineEnabled,
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
  final HiveService hiveService;
  final _HabitTracker habit;
  final DateTime today;

  const _HabitActivityGrid({required this.hiveService, required this.habit, required this.today});

  @override
  Widget build(BuildContext context) {
    final startDate = today.subtract(const Duration(days: 27));
    final taskColor = _themeDerivedTaskColor(hiveService, habit.template.colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('28-day activity', style: TextStyle(fontWeight: FontWeight.w800, color: _streakThemeStyle(hiveService).textMuted)),
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
            final blockColor = _habitActivityBlockColor(habit, date, status, taskColor);
            return Tooltip(
              message: '${date.month}/${date.day}: ${_statusLabel(status)}',
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: Duration(milliseconds: 250 + (index * 14)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.scale(
                  scale: isToday ? value * 1.03 : value,
                  child: child,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: taskColor.withOpacity(0.30),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                    border: isToday ? Border.all(color: taskColor, width: 2) : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HabitStatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final double fontSize;
  final double horizontalPadding;
  final DashboardThemeStyle style;
  final VoidCallback onPressed;

  const _HabitStatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.fontSize,
    required this.horizontalPadding,
    required this.style,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? _readableThemeOn(color, style) : color,
        backgroundColor: selected ? color : style.surface,
        side: BorderSide(color: color.withOpacity(0.7)),
        minimumSize: const Size.fromHeight(50),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _HabitDayStatus status;
  final Color? taskColor;
  final DashboardThemeStyle? style;

  const _StatusBadge({required this.status, this.taskColor, this.style});

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? DashboardThemeStyle.of(DashboardThemeType.light);
    final theme = AppThemeColors.fromDashboardStyle(resolvedStyle);
    final color = switch (status) {
      _HabitDayStatus.completed => taskColor ?? theme.success,
      _HabitDayStatus.cancelled => theme.danger,
      _HabitDayStatus.missed => theme.danger,
      _HabitDayStatus.none => theme.surfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(99)),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: AppThemeColors.readableTextOn(color.withOpacity(0.14), resolvedStyle), fontWeight: FontWeight.w900, fontSize: 11),
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

    final isDaily = _normalizedRepeatFrequency(repeatFrequency) == 'daily';

    if (task == null) {
      if (isDaily && !day.isBefore(firstTrackedDate) && day.isBefore(today)) {
        return _HabitDayStatus.missed;
      }
      return _HabitDayStatus.none;
    }

    if (_isTaskCompleted(task)) return _HabitDayStatus.completed;
    if (_isTaskCancelled(task)) return _HabitDayStatus.cancelled;
    if (_isTaskMissed(task)) return _HabitDayStatus.missed;
    if (isDaily && day.isBefore(today)) return _HabitDayStatus.missed;
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
    return task.repeatTask && task.routineEnabled && (frequency == 'daily' || frequency == 'weekly');
  }

  static String _normalizedRepeatFrequency(String? repeatFrequency) {
    final normalized = (repeatFrequency ?? '').trim().toLowerCase();
    return normalized.isEmpty ? 'daily' : normalized;
  }

  static int _calculateHabitStreak(Map<DateTime, Task> tasksByDate, DateTime today, String repeatFrequency) {
    return _normalizedRepeatFrequency(repeatFrequency) == 'weekly'
        ? _calculateWeeklyHabitStreak(tasksByDate, today)
        : _calculateDailyHabitStreak(tasksByDate, today);
  }

  static int _calculateDailyHabitStreak(Map<DateTime, Task> tasksByDate, DateTime today) {
    var cursor = _dateOnly(today);
    var streak = 0;
    final todayTask = tasksByDate[cursor];

    if (!_isTaskCompleted(todayTask)) {
      if (todayTask != null && (_isTaskCancelled(todayTask) || _isTaskMissed(todayTask))) {
        return 0;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

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

  static bool _isTaskCompleted(Task? task) => task != null && isTaskCompletedForGrid(task);

  static bool isTaskCompletedForGrid(Task task) {
    final status = _normalizedStatus(task);
    return task.done || status == 'completed' || status == 'complete';
  }

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


Color _habitActivityBlockColor(_HabitTracker habit, DateTime date, _HabitDayStatus status, Color fallbackTaskColor) {
  final task = habit.taskFor(date);
  if (task != null && _HabitTracker.isTaskCompletedForGrid(task)) {
    return Color(task.colorValue);
  }

  switch (status) {
    case _HabitDayStatus.completed:
      return task == null ? fallbackTaskColor : Color(task.colorValue);
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
  final HiveService hiveService;
  final List<Task> tasks;
  final DateTime today;

  const _DailyTaskCards({required this.hiveService, required this.tasks, required this.today});

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
            ...tasks.map((task) => _TaskJourneyCard(hiveService: hiveService, task: task, today: today)),
        ],
      ),
    );
  }
}

class _TaskJourneyCard extends StatelessWidget {
  final HiveService hiveService;
  final Task task;
  final DateTime today;

  const _TaskJourneyCard({required this.hiveService, required this.task, required this.today});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.done || task.status == 'Completed';
    final taskColor = _themeDerivedTaskColor(hiveService, task.colorValue);
    final progress = isCompleted ? 1.0 : task.status == 'In Progress' ? 0.5 : 0.12;
    final difficulty = _difficultyLabel(task);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        final habit = _habitForTask(hiveService, task, today);
        _openTaskPerformanceDetail(context, hiveService, habit, today);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: _softTaskDecoration(taskColor, radius: 20, borderOpacity: isCompleted ? 0.65 : 0.28, style: _streakThemeStyle(hiveService)),
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


void _openTaskPerformanceDetail(BuildContext context, HiveService hiveService, _HabitTracker habit, DateTime today) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => _TaskPerformanceDetailView(
        hiveService: hiveService,
        initialHabit: habit,
        today: today,
      ),
    ),
  );
}

_HabitTracker _habitForTask(HiveService hiveService, Task task, DateTime today) {
  final habits = _HabitTracker.buildHabits(hiveService.getAllTasksByDate(), today);
  for (final habit in habits) {
    if (habit.title.trim().toLowerCase() == task.task.trim().toLowerCase()) return habit;
  }

  return _HabitTracker(
    title: task.task,
    category: task.category,
    repeatFrequency: task.repeatFrequency ?? 'Daily',
    firstTrackedDate: _dateOnly(task.dueDate),
    template: task,
    tasksByDate: <DateTime, Task>{_dateOnly(task.dueDate): task},
    currentStreak: _HabitTracker.isTaskCompletedForGrid(task) ? 1 : 0,
  );
}

class _TaskPerformanceDetailView extends StatelessWidget {
  final HiveService hiveService;
  final _HabitTracker initialHabit;
  final DateTime today;

  const _TaskPerformanceDetailView({
    required this.hiveService,
    required this.initialHabit,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final habit = _currentHabit();
        final taskColor = _themeDerivedTaskColor(hiveService, habit.template.colorValue);
        final todayStatus = habit.statusFor(today);
        final metrics = _TaskPerformanceMetrics.fromHabit(habit, today);
        final notes = hiveService
            .getAllJourneyEntries()
            .where((entry) => entry.relatedTaskName?.trim().toLowerCase() == habit.title.trim().toLowerCase())
            .toList();

        return Scaffold(
          appBar: AppBar(title: Text(habit.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              _TaskPerformanceHero(
                habit: habit,
                status: todayStatus,
                metrics: metrics,
                color: taskColor,
              ),
              const SizedBox(height: 14),
              _TaskStartInfoCard(metrics: metrics, color: taskColor),
              const SizedBox(height: 14),
              _TaskPerformanceBreakdown(metrics: metrics, color: taskColor),
              const SizedBox(height: 14),
              _TaskStreakAnalytics(metrics: metrics, color: taskColor),
              const SizedBox(height: 14),
              _TaskHabitCalendar(metrics: metrics, notes: notes, color: taskColor),
              const SizedBox(height: 14),
              _TaskPerformanceActions(
                color: taskColor,
                onDone: () => _markTodayDone(context, habit),
                onAddNote: () => _addNote(context, habit),
                onAddPicture: () => _addPicture(context, habit),
              ),
              const SizedBox(height: 14),
              _TaskHistoryTimeline(metrics: metrics, notes: notes, color: taskColor),
            ],
          ),
        );
      },
    );
  }

  _HabitTracker _currentHabit() {
    final habits = _HabitTracker.buildHabits(hiveService.getAllTasksByDate(), today);
    for (final habit in habits) {
      if (habit.title.trim().toLowerCase() == initialHabit.title.trim().toLowerCase()) return habit;
    }
    return initialHabit;
  }

  bool _isOccurrenceLocked(Task task) {
    final status = task.status.trim().toLowerCase();
    return task.done || status == 'completed' || status == 'cancelled' || status == 'missed' || status == 'overdue';
  }

  String _occurrenceLabel(_HabitTracker habit) {
    final normalized = habit.repeatFrequency.trim().toLowerCase();
    switch (normalized) {
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

  void _showLockedMessage(BuildContext context, Task existing, _HabitTracker habit) {
    final normalized = existing.status.trim().toLowerCase();
    final statusLabel = existing.done || normalized == 'completed' ? 'completed' : existing.status.toLowerCase();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task already $statusLabel for ${_occurrenceLabel(habit)}. It unlocks in the next occurrence.')),
    );
  }

  Future<void> _markTodayDone(BuildContext context, _HabitTracker habit) async {
    final existing = habit.taskFor(today);
    if (existing != null && _isOccurrenceLocked(existing)) {
      _showLockedMessage(context, existing, habit);
      return;
    }
    final updated = (existing ?? habit.template).copyWith(
      dueDate: today,
      done: true,
      status: 'Completed',
      repeatTask: true,
      repeatFrequency: habit.repeatFrequency,
      routineEnabled: habit.template.routineEnabled,
    );

    if (existing == null) {
      await hiveService.addTask(today, updated);
    } else {
      await hiveService.updateTaskByReference(existing, updated);
    }
  }

  Future<void> _addNote(BuildContext context, _HabitTracker habit) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add note for ${habit.title}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'What did you notice about this habit today?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();

    if (note == null || note.isEmpty) return;
    await hiveService.saveJourneyEntry(
      JourneyEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: today,
        type: 'Routine update',
        title: '${habit.title} note',
        description: note,
        relatedTaskName: habit.title,
        colorValue: habit.template.colorValue,
      ),
    );
  }

  Future<void> _addPicture(BuildContext context, _HabitTracker habit) async {
    final controller = TextEditingController();
    final image = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add picture for ${habit.title}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Image URL or path',
            hintText: 'Progress photo, setup screenshot, personal moment...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();

    if (image == null || image.isEmpty) return;
    await hiveService.saveJourneyEntry(
      JourneyEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: today,
        type: 'Habit progress',
        title: '${habit.title} progress photo',
        description: 'Added a progress image for this habit.',
        relatedTaskName: habit.title,
        colorValue: habit.template.colorValue,
        imageUrl: image,
      ),
    );
  }
}

class _TaskPerformanceHero extends StatelessWidget {
  final _HabitTracker habit;
  final _HabitDayStatus status;
  final _TaskPerformanceMetrics metrics;
  final Color color;

  const _TaskPerformanceHero({required this.habit, required this.status, required this.metrics, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _softTaskDecoration(color, radius: 26, borderOpacity: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: color.withOpacity(0.20), borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.analytics, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${habit.repeatFrequency} • ${habit.category}', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Complete journey from ${_formatFullDate(metrics.startDate)}', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _StatusBadge(status: status, taskColor: color),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PerformanceMetricChip(label: 'Current streak', value: '${metrics.currentStreak}', icon: Icons.local_fire_department, color: color),
              _PerformanceMetricChip(label: 'Best streak', value: '${metrics.bestStreak}', icon: Icons.emoji_events, color: color),
              _PerformanceMetricChip(label: 'Completion', value: '${metrics.completionPercent}%', icon: Icons.pie_chart, color: color),
              _PerformanceMetricChip(label: 'Efficiency', value: '${metrics.efficiencyPercent}%', icon: Icons.trending_up, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskStartInfoCard extends StatelessWidget {
  final _TaskPerformanceMetrics metrics;
  final Color color;

  const _TaskStartInfoCard({required this.metrics, required this.color});

  @override
  Widget build(BuildContext context) {
    return _TaskPerformancePanel(
      title: 'Task Start Information',
      icon: Icons.event_available,
      color: color,
      children: [
        _TaskInfoRow(label: 'Started On', value: _formatFullDate(metrics.startDate), icon: Icons.flag_circle, color: color),
        _TaskInfoRow(label: 'Active Days', value: '${metrics.activeDays} ${_dayWord(metrics.activeDays)}', icon: Icons.bolt, color: color),
        _TaskInfoRow(label: 'Tracking For', value: '${metrics.trackingDays} ${_dayWord(metrics.trackingDays)}', icon: Icons.date_range, color: color),
      ],
    );
  }
}

class _TaskPerformanceBreakdown extends StatelessWidget {
  final _TaskPerformanceMetrics metrics;
  final Color color;

  const _TaskPerformanceBreakdown({required this.metrics, required this.color});

  @override
  Widget build(BuildContext context) {
    return _TaskPerformancePanel(
      title: 'Complete Performance Details',
      icon: Icons.insights,
      color: color,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _PerformanceSummaryTile(label: 'Completed', value: '${metrics.completedCount}', icon: Icons.check_circle, color: color),
            _PerformanceSummaryTile(label: 'Missed', value: '${metrics.missedCount}', icon: Icons.cancel, color: Colors.redAccent),
            _PerformanceSummaryTile(label: 'Cancelled', value: '${metrics.cancelledCount}', icon: Icons.do_not_disturb_on, color: Colors.deepOrange),
            _PerformanceSummaryTile(label: 'Tracked Days', value: '${metrics.totalTracked}', icon: Icons.timeline, color: color),
            _PerformanceSummaryTile(label: 'Completion %', value: '${metrics.completionPercent}%', icon: Icons.percent, color: color),
            _PerformanceSummaryTile(label: 'Efficiency', value: '${metrics.efficiencyPercent}%', icon: Icons.speed, color: color),
          ],
        ),
      ],
    );
  }
}

class _TaskStreakAnalytics extends StatelessWidget {
  final _TaskPerformanceMetrics metrics;
  final Color color;

  const _TaskStreakAnalytics({required this.metrics, required this.color});

  @override
  Widget build(BuildContext context) {
    return _TaskPerformancePanel(
      title: 'Streak Analytics',
      icon: Icons.local_fire_department,
      color: color,
      children: [
        _TaskInfoRow(label: 'Current Streak', value: '${metrics.currentStreak} consecutive completion ${_dayWord(metrics.currentStreak)}', icon: Icons.whatshot, color: color),
        _TaskInfoRow(label: 'Current Consecutive Completion Days', value: '${metrics.currentConsecutiveCompletionDays} ${_dayWord(metrics.currentConsecutiveCompletionDays)}', icon: Icons.done_all, color: color),
        _TaskInfoRow(label: 'Best Streak', value: '${metrics.bestStreak} ${_dayWord(metrics.bestStreak)}', icon: Icons.emoji_events, color: color),
        _TaskInfoRow(label: 'Longest Missed Period', value: '${metrics.longestMissedPeriod} ${_dayWord(metrics.longestMissedPeriod)}', icon: Icons.trending_down, color: Colors.redAccent),
      ],
    );
  }
}

class _TaskHabitCalendar extends StatefulWidget {
  final _TaskPerformanceMetrics metrics;
  final List<JourneyEntry> notes;
  final Color color;

  const _TaskHabitCalendar({required this.metrics, required this.notes, required this.color});

  @override
  State<_TaskHabitCalendar> createState() => _TaskHabitCalendarState();
}

class _TaskHabitCalendarState extends State<_TaskHabitCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    final currentMonth = DateTime(today.year, today.month);
    final earliestMonth = DateTime(widget.metrics.startDate.year, widget.metrics.startDate.month);
    _visibleMonth = currentMonth.isBefore(earliestMonth) ? earliestMonth : currentMonth;
  }

  @override
  void didUpdateWidget(covariant _TaskHabitCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final earliest = DateTime(widget.metrics.startDate.year, widget.metrics.startDate.month);
    final latest = _latestAllowedMonth;
    if (_visibleMonth.isBefore(earliest)) _visibleMonth = earliest;
    if (_visibleMonth.isAfter(latest)) _visibleMonth = latest;
  }

  DateTime get _latestAllowedMonth {
    final today = _dateOnly(DateTime.now());
    return DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final earliestMonth = DateTime(widget.metrics.startDate.year, widget.metrics.startDate.month);
    final canGoBack = _visibleMonth.isAfter(earliestMonth);
    final canGoForward = _visibleMonth.isBefore(_latestAllowedMonth);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: widget.color),
              const SizedBox(width: 8),
              const Expanded(child: Text('Calendar View', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Task-specific monthly activity history. Tap any day to view completion details, notes, photos, and reflections.',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: canGoBack ? () => _changeMonth(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: canGoForward ? () => _changeMonth(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CalendarLegend(color: widget.color),
          const SizedBox(height: 12),
          _CalendarWeekHeader(color: widget.color),
          const SizedBox(height: 8),
          _buildMonthGrid(),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Widget _buildMonthGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlankDays = firstDay.weekday % 7;
    final cellCount = ((leadingBlankDays + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - leadingBlankDays + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();
        final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
        final row = _rowForDate(date);
        final notes = _notesForDate(date);
        final status = _calendarStatusFor(date, row);
        final isToday = _isSameDate(date, DateTime.now());
        final colors = _CalendarDayColors.fromStatus(status, row, widget.color, isToday: isToday);

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDayDetails(context, date, row, notes, status),
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border, width: isToday ? 2 : 1),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w900),
                  ),
                ),
                if (notes.isNotEmpty)
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: colors.foreground, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  _TaskTimelineRow? _rowForDate(DateTime date) {
    final day = _dateOnly(date);
    for (final row in widget.metrics.historyRows) {
      if (_isSameDate(row.date, day)) return row;
    }
    return null;
  }

  List<JourneyEntry> _notesForDate(DateTime date) {
    final day = _dateOnly(date);
    return widget.notes.where((entry) => _isSameDate(entry.date, day)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  _HabitDayStatus _calendarStatusFor(DateTime date, _TaskTimelineRow? row) {
    final day = _dateOnly(date);
    final today = _dateOnly(DateTime.now());
    if (day.isAfter(today) || day.isBefore(widget.metrics.startDate)) return _HabitDayStatus.none;
    return row?.status ?? _HabitDayStatus.none;
  }

  void _showDayDetails(BuildContext context, DateTime date, _TaskTimelineRow? row, List<JourneyEntry> notes, _HabitDayStatus status) {
    final statusColor = _CalendarDayColors.statusColor(status, row, widget.color);
    final task = row?.task;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(width: 16, height: 16, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(5))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_relativeDateLabel(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  _StatusBadge(status: status, taskColor: widget.color),
                ],
              ),
              const SizedBox(height: 12),
              _TaskInfoRow(label: 'Completion Details', value: _statusLabel(status), icon: _statusIcon(status), color: statusColor),
              if (task != null) ...[
                _TaskInfoRow(label: 'Task', value: task.task, icon: Icons.task_alt, color: widget.color),
                _TaskInfoRow(label: 'Category', value: task.category, icon: Icons.category, color: widget.color),
              ],
              const SizedBox(height: 8),
              Text('Notes, Photos & Reflections', style: TextStyle(color: widget.color, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (notes.isEmpty)
                const _EmptyState(message: 'No notes, photos, mood, or reflection updates for this date yet.')
              else
                ...notes.map((entry) => _TaskNoteTile(entry: entry, color: widget.color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarWeekHeader extends StatelessWidget {
  final Color color;

  const _CalendarWeekHeader({required this.color});

  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final Color color;

  const _CalendarLegend({required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CalendarLegendItem(label: 'Completed', color: color),
        const _CalendarLegendItem(label: 'Missed / Cancelled', color: Colors.redAccent),
        const _CalendarLegendItem(label: 'No activity / Future', color: Color(0xFF263238)),
      ],
    );
  }
}

class _CalendarLegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _CalendarLegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withOpacity(0.18))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CalendarDayColors {
  final Color background;
  final Color foreground;
  final Color border;

  const _CalendarDayColors({required this.background, required this.foreground, required this.border});

  factory _CalendarDayColors.fromStatus(_HabitDayStatus status, _TaskTimelineRow? row, Color taskColor, {required bool isToday}) {
    final color = statusColor(status, row, taskColor);
    final isNeutral = status == _HabitDayStatus.none;
    return _CalendarDayColors(
      background: isNeutral ? color.withOpacity(0.08) : color.withOpacity(0.18),
      foreground: isNeutral ? color.withOpacity(0.72) : color,
      border: isToday ? taskColor : color.withOpacity(isNeutral ? 0.12 : 0.30),
    );
  }

  static Color statusColor(_HabitDayStatus status, _TaskTimelineRow? row, Color taskColor) {
    switch (status) {
      case _HabitDayStatus.completed:
        final task = row?.task;
        return task == null ? taskColor : Color(task.colorValue);
      case _HabitDayStatus.cancelled:
      case _HabitDayStatus.missed:
        return Colors.redAccent;
      case _HabitDayStatus.none:
        return const Color(0xFF263238);
    }
  }
}

class _TaskPerformancePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _TaskPerformancePanel({required this.title, required this.icon, required this.color, required this.children});

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
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TaskInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TaskInfoRow({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PerformanceSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PerformanceSummaryTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PerformanceMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PerformanceMetricChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TaskPerformanceActions extends StatelessWidget {
  final Color color;
  final VoidCallback onDone;
  final VoidCallback onAddNote;
  final VoidCallback onAddPicture;

  const _TaskPerformanceActions({required this.color, required this.onDone, required this.onAddNote, required this.onAddPicture});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onDone,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onAddNote,
            icon: Icon(Icons.note_add, color: color),
            label: const Text('Add Note'),
            style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withOpacity(0.55))),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onAddPicture,
            icon: Icon(Icons.add_a_photo, color: color),
            label: const Text('Add Picture'),
            style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withOpacity(0.55))),
          ),
        ),
      ],
    );
  }
}

class _TaskHistoryTimeline extends StatelessWidget {
  final _TaskPerformanceMetrics metrics;
  final List<JourneyEntry> notes;
  final Color color;

  const _TaskHistoryTimeline({required this.metrics, required this.notes, required this.color});

  @override
  Widget build(BuildContext context) {
    final rows = _mergeNoteOnlyRows(metrics.historyRows, notes);
    rows.sort((a, b) => b.date.compareTo(a.date));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Timeline View', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            'Today, yesterday, weekly history, monthly history, and the full task journey from ${_formatFullDate(metrics.startDate)}.',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const _EmptyState(message: 'No performance history yet. Mark today done or add a note to start tracking this habit.')
          else
            ..._groupRowsByMonth(rows, notes, color),
        ],
      ),
    );
  }
}

List<_TaskTimelineRow> _mergeNoteOnlyRows(List<_TaskTimelineRow> rows, List<JourneyEntry> notes) {
  final merged = rows.toList();
  for (final note in notes) {
    final noteDate = _dateOnly(note.date);
    if (merged.any((row) => _isSameDate(row.date, noteDate))) continue;
    merged.add(_TaskTimelineRow(date: noteDate, status: _HabitDayStatus.none, task: null));
  }
  return merged;
}

List<Widget> _groupRowsByMonth(List<_TaskTimelineRow> rows, List<JourneyEntry> notes, Color color) {
  final widgets = <Widget>[];
  String? activeMonth;
  for (final row in rows) {
    final label = '${_monthNames[row.date.month - 1]} ${row.date.year}';
    if (label != activeMonth) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ),
      );
      activeMonth = label;
    }
    final dayNotes = notes.where((entry) => _isSameDate(entry.date, row.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    widgets.add(_TaskTimelineTile(row: row, notes: dayNotes, color: color));
  }
  return widgets;
}

class _TaskTimelineRow {
  final DateTime date;
  final _HabitDayStatus status;
  final Task? task;

  const _TaskTimelineRow({required this.date, required this.status, required this.task});
}

class _TaskTimelineTile extends StatelessWidget {
  final _TaskTimelineRow row;
  final List<JourneyEntry> notes;
  final Color color;

  const _TaskTimelineTile({required this.row, required this.notes, required this.color});

  @override
  Widget build(BuildContext context) {
    final blockColor = row.status == _HabitDayStatus.completed
        ? (row.task == null ? color : Color(row.task!.colorValue))
        : row.status == _HabitDayStatus.none
            ? const Color(0xFF263238)
            : Colors.redAccent;
    final hasTaskActivity = row.status != _HabitDayStatus.none;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blockColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blockColor.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 16, height: 16, decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(5))),
              const SizedBox(width: 10),
              Expanded(child: Text(_relativeDateLabel(row.date), style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(_statusLabel(row.status), style: TextStyle(color: blockColor, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasTaskActivity ? _dayActivityText(row) : 'Notes, photos, or reflections were added for this task.',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...notes.map((entry) => _TaskNoteTile(entry: entry, color: color)),
          ],
        ],
      ),
    );
  }

  String _dayActivityText(_TaskTimelineRow row) {
    switch (row.status) {
      case _HabitDayStatus.completed:
        return 'Completed ${row.task?.task ?? 'task'}';
      case _HabitDayStatus.cancelled:
        return 'Cancelled ${row.task?.task ?? 'task'}';
      case _HabitDayStatus.missed:
        return 'Missed ${row.task?.task ?? 'task'}';
      case _HabitDayStatus.none:
        return 'No task status recorded.';
    }
  }
}

class _TaskNoteTile extends StatelessWidget {
  final JourneyEntry entry;
  final Color color;

  const _TaskNoteTile({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.72), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.16))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(entry.hasImage ? Icons.image : Icons.note, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(entry.hasImage ? 'Photo' : 'Note', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          if (entry.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.description, style: const TextStyle(color: Colors.black87)),
          ],
          if (entry.hasImage) ...[
            const SizedBox(height: 6),
            Text(entry.imageUrl!, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _TaskPerformanceMetrics {
  final DateTime startDate;
  final int trackingDays;
  final int activeDays;
  final int currentStreak;
  final int currentConsecutiveCompletionDays;
  final int bestStreak;
  final int longestMissedPeriod;
  final int completedCount;
  final int missedCount;
  final int cancelledCount;
  final int totalTracked;
  final int completionPercent;
  final int efficiencyPercent;
  final List<_TaskTimelineRow> historyRows;

  const _TaskPerformanceMetrics({
    required this.startDate,
    required this.trackingDays,
    required this.activeDays,
    required this.currentStreak,
    required this.currentConsecutiveCompletionDays,
    required this.bestStreak,
    required this.longestMissedPeriod,
    required this.completedCount,
    required this.missedCount,
    required this.cancelledCount,
    required this.totalTracked,
    required this.completionPercent,
    required this.efficiencyPercent,
    required this.historyRows,
  });

  factory _TaskPerformanceMetrics.fromHabit(_HabitTracker habit, DateTime today) {
    final startDate = _dateOnly(habit.firstTrackedDate);
    final endDate = _dateOnly(today);
    final historyRows = _buildHistoryRows(habit, endDate);
    final completed = historyRows.where((row) => row.status == _HabitDayStatus.completed).length;
    final missed = historyRows.where((row) => row.status == _HabitDayStatus.missed).length;
    final cancelled = historyRows.where((row) => row.status == _HabitDayStatus.cancelled).length;
    final tracked = completed + missed + cancelled;
    final trackingDays = math.max(1, endDate.difference(startDate).inDays + 1);
    final activeDays = habit.tasksByDate.keys.where((date) => !date.isBefore(startDate) && !date.isAfter(endDate)).length;
    final completionPercent = trackingDays == 0 ? 0 : ((completed / trackingDays) * 100).round();
    final efficiency = tracked == 0 ? 0 : ((completed / tracked) * 100).round();

    return _TaskPerformanceMetrics(
      startDate: startDate,
      trackingDays: trackingDays,
      activeDays: activeDays,
      currentStreak: habit.currentStreak,
      currentConsecutiveCompletionDays: _currentCompletionStreak(historyRows),
      bestStreak: _bestStreak(historyRows),
      longestMissedPeriod: _longestMissedPeriod(historyRows),
      completedCount: completed,
      missedCount: missed,
      cancelledCount: cancelled,
      totalTracked: tracked,
      completionPercent: _boundedPercent(completionPercent),
      efficiencyPercent: _boundedPercent(efficiency),
      historyRows: historyRows,
    );
  }

  static List<_TaskTimelineRow> _buildHistoryRows(_HabitTracker habit, DateTime today) {
    final rows = <_TaskTimelineRow>[];
    final startDate = _dateOnly(habit.firstTrackedDate);
    final isDaily = _HabitTracker._normalizedRepeatFrequency(habit.repeatFrequency) == 'daily';

    if (isDaily) {
      var cursor = startDate;
      while (!cursor.isAfter(today)) {
        rows.add(_TaskTimelineRow(date: cursor, status: habit.statusFor(cursor), task: habit.taskFor(cursor)));
        cursor = cursor.add(const Duration(days: 1));
      }
    } else {
      for (final entry in habit.tasksByDate.entries) {
        final day = _dateOnly(entry.key);
        if (day.isBefore(startDate) || day.isAfter(today)) continue;
        rows.add(_TaskTimelineRow(date: day, status: habit.statusFor(day), task: entry.value));
      }
      if (!rows.any((row) => _isSameDate(row.date, today))) {
        rows.add(_TaskTimelineRow(date: today, status: habit.statusFor(today), task: habit.taskFor(today)));
      }
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  static int _currentCompletionStreak(List<_TaskTimelineRow> rows) {
    final ascendingRows = rows.toList()..sort((a, b) => b.date.compareTo(a.date));
    var streak = 0;
    for (final row in ascendingRows) {
      if (row.status == _HabitDayStatus.none) continue;
      if (row.status != _HabitDayStatus.completed) break;
      streak++;
    }
    return streak;
  }

  static int _bestStreak(List<_TaskTimelineRow> rows) {
    final ascendingRows = rows.toList()..sort((a, b) => a.date.compareTo(b.date));
    var best = 0;
    var current = 0;
    for (final row in ascendingRows) {
      if (row.status == _HabitDayStatus.none) continue;
      if (row.status == _HabitDayStatus.completed) {
        current++;
      } else {
        current = 0;
      }
      if (current > best) best = current;
    }
    return best;
  }

  static int _longestMissedPeriod(List<_TaskTimelineRow> rows) {
    final ascendingRows = rows.toList()..sort((a, b) => a.date.compareTo(b.date));
    var longest = 0;
    var current = 0;
    for (final row in ascendingRows) {
      if (row.status == _HabitDayStatus.none) continue;
      if (row.status == _HabitDayStatus.missed) {
        current++;
      } else {
        current = 0;
      }
      if (current > longest) longest = current;
    }
    return longest;
  }
}

int _boundedPercent(int value) => value < 0 ? 0 : value > 100 ? 100 : value;

String _formatFullDate(DateTime date) => '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

String _relativeDateLabel(DateTime date) {
  final today = _dateOnly(DateTime.now());
  final day = _dateOnly(date);
  if (_isSameDate(day, today)) return 'Today • ${_formatFullDate(day)}';
  if (_isSameDate(day, today.subtract(const Duration(days: 1)))) return 'Yesterday • ${_formatFullDate(day)}';
  return _formatFullDate(day);
}

String _dayWord(int count) => count == 1 ? 'Day' : 'Days';

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


Color _readableThemeOn(Color color, DashboardThemeStyle style) => AppThemeColors.readableTextOn(color, style);

DashboardThemeStyle _streakThemeStyle(HiveService hiveService) {
  return DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
}

AppThemeColors _streakThemeColors(HiveService hiveService) => AppThemeColors.fromDashboardStyle(_streakThemeStyle(hiveService));

Color _themeAccent(HiveService hiveService) => _streakThemeStyle(hiveService).accent;

Color _themeDerivedTaskColor(HiveService hiveService, int storedColorValue) {
  final style = _streakThemeStyle(hiveService);
  final colors = <Color>[
    style.primary,
    style.secondary,
    style.accent,
    style.heroGradient.isNotEmpty ? style.heroGradient.last : style.accent,
    Color.lerp(style.primary, style.accent, 0.35) ?? style.primary,
    Color.lerp(style.secondary, style.accent, 0.42) ?? style.secondary,
    Color.lerp(style.accent, style.primary, 0.62) ?? style.accent,
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


BoxDecoration _softTaskDecoration(Color taskColor, {required double radius, double borderOpacity = 0.24, DashboardThemeStyle? style}) {
  final theme = style == null ? null : AppThemeColors.fromDashboardStyle(style);
  final fill = theme == null
      ? taskColor.withOpacity(0.10)
      : style!.dark
          ? theme.cardDark
          : Color.lerp(theme.card, taskColor, 0.06) ?? theme.card;
  final borderColor = theme == null ? taskColor.withOpacity(borderOpacity) : Color.lerp(theme.border, taskColor, 0.42)!.withOpacity(borderOpacity + 0.10);
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor),
    boxShadow: [
      BoxShadow(
        color: theme?.shadow ?? taskColor.withOpacity(0.06),
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
