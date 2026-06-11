import 'dart:math' as math;

import 'journal_entry.dart';
import 'productivity_snapshot.dart';
import 'task_model.dart';

class RankProfile {
  final String username;
  final RankTier currentRank;
  final RankTier? nextRank;
  final int level;
  final int xp;
  final int currentLevelXp;
  final int xpForNextLevel;
  final int activeStreak;
  final int longestStreak;
  final int totalTasksCompleted;
  final int importantTasksCompleted;
  final int recurringTasksCompleted;
  final int totalActiveDays;
  final int completedGoalDays;
  final int journalEntries;
  final int reflectiveDays;
  final int productivityScore;
  final double completionRate;

  const RankProfile({
    required this.username,
    required this.currentRank,
    required this.nextRank,
    required this.level,
    required this.xp,
    required this.currentLevelXp,
    required this.xpForNextLevel,
    required this.activeStreak,
    required this.longestStreak,
    required this.totalTasksCompleted,
    required this.importantTasksCompleted,
    required this.recurringTasksCompleted,
    required this.totalActiveDays,
    required this.completedGoalDays,
    required this.journalEntries,
    required this.reflectiveDays,
    required this.productivityScore,
    required this.completionRate,
  });

  double get levelProgress => xpForNextLevel == 0 ? 1 : currentLevelXp / xpForNextLevel;
  double get nextRankProgress {
    if (nextRank == null) return 1;
    final currentThreshold = currentRank.minimumLevel;
    final nextThreshold = nextRank!.minimumLevel;
    final rankSpan = math.max(1, nextThreshold - currentThreshold);
    return ((level - currentThreshold) / rankSpan).clamp(0.0, 1.0).toDouble();
  }

  factory RankProfile.calculate({
    required String username,
    required Map<DateTime, List<Task>> allTasksByDate,
    List<JournalEntry> journalEntries = const <JournalEntry>[],
    LifetimeProductivityStats? lifetimeStats,
    DateTime? now,
  }) {
    final todayValue = now ?? DateTime.now();
    final today = DateTime(todayValue.year, todayValue.month, todayValue.day);
    final dayActivity = <DateTime, _RankDayActivity>{};
    var totalTasks = 0;
    var completedTasks = 0;
    var importantCompleted = 0;
    var recurringCompleted = 0;
    var completedGoalDays = 0;

    for (final entry in allTasksByDate.entries) {
      final date = DateTime(entry.key.year, entry.key.month, entry.key.day);
      final tasks = entry.value.where((task) => task.status != 'Cancelled').toList();
      if (tasks.isEmpty) continue;

      final completed = tasks.where(_isCompleted).toList();
      totalTasks += tasks.length;
      completedTasks += completed.length;
      importantCompleted += completed.where((task) => task.important || task.priority == 'High' || task.priority == 'Very High' || task.priority == 'Urgent (Now)').length;
      recurringCompleted += completed.where((task) => task.repeatTask).length;

      final goalComplete = completed.length == tasks.length;
      if (goalComplete) completedGoalDays++;

      dayActivity[date] = _RankDayActivity(
        completed: completed.length,
        goalComplete: goalComplete,
      );
    }

    for (final entry in journalEntries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final current = dayActivity[date];
      dayActivity[date] = _RankDayActivity(
        completed: current?.completed ?? 0,
        goalComplete: current?.goalComplete ?? true,
      );
    }

    final activeDays = dayActivity.values.where((activity) => activity.completed > 0 || activity.goalComplete).length;
    final activeStreak = _calculateActiveStreak(today, dayActivity);
    final longestStreak = _calculateLongestStreak(dayActivity);
    final journalCount = journalEntries.length;
    final reflectiveDays = journalEntries.where((entry) => entry.hasReflection).length;
    final completionRate = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final consistencyScore = activeDays * 4 + completedGoalDays * 8;
    final streakScore = activeStreak * 14 + longestStreak * 6;
    final taskScore = completedTasks * 10 + importantCompleted * 8 + recurringCompleted * 6;
    final journalScore = journalCount * 8 + reflectiveDays * 4;
    final productivityScore = lifetimeStats == null ? (completionRate * 100).round() : lifetimeStats.averageDailyScore.round();
    final lifetimeXp = lifetimeStats?.xp ?? 0;
    final xp = taskScore + consistencyScore + streakScore + journalScore + productivityScore + lifetimeXp;
    final level = math.max(1, (xp ~/ 120) + 1);
    final currentRank = RankTier.forLevel(level);
    final nextRank = RankTier.nextAfter(currentRank);

    return RankProfile(
      username: username.trim().isEmpty ? 'Productivity Hero' : username.trim(),
      currentRank: currentRank,
      nextRank: nextRank,
      level: level,
      xp: xp,
      currentLevelXp: xp % 120,
      xpForNextLevel: 120,
      activeStreak: activeStreak,
      longestStreak: longestStreak,
      totalTasksCompleted: completedTasks,
      importantTasksCompleted: importantCompleted,
      recurringTasksCompleted: recurringCompleted,
      totalActiveDays: activeDays,
      completedGoalDays: completedGoalDays,
      journalEntries: journalCount,
      reflectiveDays: reflectiveDays,
      productivityScore: productivityScore,
      completionRate: completionRate,
    );
  }

  static bool _isCompleted(Task task) => task.done || task.status == 'Completed';

  static int _calculateActiveStreak(DateTime today, Map<DateTime, _RankDayActivity> activityByDate) {
    var cursor = today;
    var streak = 0;

    if (!(activityByDate[cursor]?.goalComplete ?? false)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (activityByDate[cursor]?.goalComplete ?? false) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static int _calculateLongestStreak(Map<DateTime, _RankDayActivity> activityByDate) {
    if (activityByDate.isEmpty) return 0;
    final dates = activityByDate.keys.toList()..sort();
    var cursor = dates.first;
    final end = dates.last;
    var current = 0;
    var longest = 0;

    while (!cursor.isAfter(end)) {
      if (activityByDate[cursor]?.goalComplete ?? false) {
        current++;
        longest = math.max(longest, current);
      } else {
        current = 0;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return longest;
  }
}

class RankTier {
  final String name;
  final String emoji;
  final int minimumLevel;
  final int colorValue;

  const RankTier({
    required this.name,
    required this.emoji,
    required this.minimumLevel,
    required this.colorValue,
  });

  static const tiers = [
    RankTier(name: 'Fragmented', emoji: '⚪', minimumLevel: 1, colorValue: 0xFF78909C),
    RankTier(name: 'Fogged', emoji: '🌫️', minimumLevel: 3, colorValue: 0xFF90A4AE),
    RankTier(name: 'Blocked', emoji: '🧱', minimumLevel: 5, colorValue: 0xFF8D6E63),
    RankTier(name: 'Writer', emoji: '📝', minimumLevel: 8, colorValue: 0xFF42A5F5),
    RankTier(name: 'Reflector', emoji: '🪞', minimumLevel: 11, colorValue: 0xFF5C6BC0),
    RankTier(name: 'Explorer', emoji: '🔵', minimumLevel: 14, colorValue: 0xFF1E88E5),
    RankTier(name: 'Clearhead', emoji: '💎', minimumLevel: 18, colorValue: 0xFF26A69A),
    RankTier(name: 'Deepened', emoji: '🔥', minimumLevel: 23, colorValue: 0xFFFF8F00),
    RankTier(name: 'Selfmaster', emoji: '👑', minimumLevel: 30, colorValue: 0xFF7E57C2),
  ];

  static RankTier forLevel(int level) {
    RankTier selected = tiers.first;
    for (final tier in tiers) {
      if (level >= tier.minimumLevel) selected = tier;
    }
    return selected;
  }

  static RankTier? nextAfter(RankTier current) {
    final index = tiers.indexWhere((tier) => tier.name == current.name);
    if (index == -1 || index == tiers.length - 1) return null;
    return tiers[index + 1];
  }
}

class _RankDayActivity {
  final int completed;
  final bool goalComplete;

  const _RankDayActivity({required this.completed, required this.goalComplete});
}
