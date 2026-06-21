import 'dart:math' as math;

class ProductivityPointEvent {
  final String title;
  final int basePoints;
  final int streakBonusPoints;
  final int timingBonusPoints;
  final int pointsBonus;
  final int totalPoints;
  final String reason;

  const ProductivityPointEvent({
    required this.title,
    required this.basePoints,
    required this.streakBonusPoints,
    this.timingBonusPoints = 0,
    this.pointsBonus = 0,
    required this.totalPoints,
    required this.reason,
  });

  List<dynamic> toStorageList() {
    return [
      title,
      basePoints,
      streakBonusPoints,
      totalPoints,
      reason,
      timingBonusPoints,
      pointsBonus,
    ];
  }

  factory ProductivityPointEvent.fromStorageList(List<dynamic> raw) {
    final base = _readInt(raw, 1);
    final bonus = _readInt(raw, 2);
    final timing = raw.length > 5 ? _readInt(raw, 5) : 0;
    return ProductivityPointEvent(
      title: raw.isNotEmpty ? '${raw[0]}' : 'Productivity points',
      basePoints: base,
      streakBonusPoints: bonus,
      timingBonusPoints: timing,
      pointsBonus: raw.length > 6 ? _readInt(raw, 6) : timing ~/ 4,
      totalPoints: raw.length > 3 ? _readInt(raw, 3) : base + bonus + timing,
      reason: raw.length > 4 ? '${raw[4]}' : '',
    );
  }

  static int _readInt(List<dynamic> raw, int index) {
    if (raw.length <= index) return 0;
    final value = raw[index];
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}

class ProductivitySnapshot {
  static const double maximumPoints = 1600;

  final DateTime date;
  final double bothHours;
  final double importantHours;
  final double urgentHours;
  final double neitherHours;
  final double totalHours;
  final int totalPoints;
  final int basePoints;
  final int streakBonusPoints;
  final int timingBonusPoints;
  final double productivityScore;
  final String rating;
  final int completedTasks;
  final int routineCompletions;
  final int projectPhasesCompleted;
  final List<String> completedTaskNames;
  final List<ProductivityPointEvent> pointEvents;

  const ProductivitySnapshot({
    required this.date,
    required this.bothHours,
    required this.importantHours,
    required this.urgentHours,
    required this.neitherHours,
    required this.totalHours,
    required this.totalPoints,
    required this.basePoints,
    required this.streakBonusPoints,
    this.timingBonusPoints = 0,
    required this.productivityScore,
    required this.rating,
    required this.completedTasks,
    required this.routineCompletions,
    required this.projectPhasesCompleted,
    required this.completedTaskNames,
    required this.pointEvents,
  });

  int get pointsEarned => totalPoints ~/ 10;
  double get focusedHours => bothHours + importantHours + urgentHours;
  double get distractionHours => neitherHours;

  List<dynamic> toStorageList() {
    return [
      date.toIso8601String().split('T').first,
      bothHours,
      importantHours,
      urgentHours,
      neitherHours,
      totalHours,
      totalPoints,
      productivityScore,
      rating,
      completedTasks,
      routineCompletions,
      projectPhasesCompleted,
      completedTaskNames,
      basePoints,
      streakBonusPoints,
      pointEvents.map((event) => event.toStorageList()).toList(),
      timingBonusPoints,
    ];
  }

  factory ProductivitySnapshot.fromStorageList(List<dynamic> raw) {
    final parsedDate = DateTime.tryParse(raw.isNotEmpty ? '${raw[0]}' : '') ?? DateTime.now();
    return ProductivitySnapshot(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      bothHours: _asDouble(raw, 1),
      importantHours: _asDouble(raw, 2),
      urgentHours: _asDouble(raw, 3),
      neitherHours: _asDouble(raw, 4),
      totalHours: _asDouble(raw, 5),
      totalPoints: _asInt(raw, 6),
      basePoints: raw.length > 13 ? _asInt(raw, 13) : _asInt(raw, 6),
      streakBonusPoints: raw.length > 14 ? _asInt(raw, 14) : 0,
      timingBonusPoints: raw.length > 16 ? _asInt(raw, 16) : 0,
      productivityScore: _asDouble(raw, 7),
      rating: raw.length > 8 ? '${raw[8]}' : ratingForScore(_asDouble(raw, 7)),
      completedTasks: _asInt(raw, 9),
      routineCompletions: _asInt(raw, 10),
      projectPhasesCompleted: _asInt(raw, 11),
      completedTaskNames: raw.length > 12 && raw[12] is List ? (raw[12] as List).map((item) => '$item').toList() : const <String>[],
      pointEvents: raw.length > 15 && raw[15] is List
          ? (raw[15] as List)
              .whereType<List>()
              .map((event) => ProductivityPointEvent.fromStorageList(event.cast<dynamic>()))
              .toList()
          : const <ProductivityPointEvent>[],
    );
  }

  factory ProductivitySnapshot.empty(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return ProductivitySnapshot(
      date: day,
      bothHours: 0,
      importantHours: 0,
      urgentHours: 0,
      neitherHours: 0,
      totalHours: 0,
      totalPoints: 0,
      basePoints: 0,
      streakBonusPoints: 0,
      timingBonusPoints: 0,
      productivityScore: 0,
      rating: ratingForScore(0),
      completedTasks: 0,
      routineCompletions: 0,
      projectPhasesCompleted: 0,
      completedTaskNames: const <String>[],
      pointEvents: const <ProductivityPointEvent>[],
    );
  }

  static String ratingForScore(double score) {
    if (score >= 90) return 'Elite 🌟';
    if (score >= 80) return 'Excellent 🏆';
    if (score >= 70) return 'Very Good 💪';
    if (score >= 60) return 'Good 👍';
    if (score >= 50) return 'Average 🙂';
    if (score >= 40) return 'Low ⚠️';
    return 'Poor ❌';
  }

  static double _asDouble(List<dynamic> raw, int index) {
    if (raw.length <= index) return 0;
    final value = raw[index];
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int _asInt(List<dynamic> raw, int index) {
    if (raw.length <= index) return 0;
    final value = raw[index];
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}

class LifetimeProductivityStats {
  final List<ProductivitySnapshot> snapshots;
  final double lifetimeProductivity;
  final int totalPoints;
  final int totalBonusEarned;
  final int highestStreakBonus;
  final double totalFocusHours;
  final int totalCompletedTasks;
  final int currentStreak;
  final int bestStreak;
  final int activeDays;
  final double averageDailyScore;
  final double medianProductivity;
  final ProductivitySnapshot? highestDay;
  final ProductivitySnapshot? lowestDay;
  final int routineCompletions;
  final int projectPhasesCompleted;
  final int xp;
  final int level;

  const LifetimeProductivityStats({
    required this.snapshots,
    required this.lifetimeProductivity,
    required this.totalPoints,
    required this.totalBonusEarned,
    required this.highestStreakBonus,
    required this.totalFocusHours,
    required this.totalCompletedTasks,
    required this.currentStreak,
    required this.bestStreak,
    required this.activeDays,
    required this.averageDailyScore,
    required this.medianProductivity,
    required this.highestDay,
    required this.lowestDay,
    required this.routineCompletions,
    required this.projectPhasesCompleted,
    required this.xp,
    required this.level,
  });

  int get points => xp;

  factory LifetimeProductivityStats.fromSnapshots(List<ProductivitySnapshot> input, {DateTime? now}) {
    final snapshots = input.toList()..sort((a, b) => a.date.compareTo(b.date));
    if (snapshots.isEmpty) {
      return const LifetimeProductivityStats(
        snapshots: <ProductivitySnapshot>[],
        lifetimeProductivity: 0,
        totalPoints: 0,
        totalBonusEarned: 0,
        highestStreakBonus: 0,
        totalFocusHours: 0,
        totalCompletedTasks: 0,
        currentStreak: 0,
        bestStreak: 0,
        activeDays: 0,
        averageDailyScore: 0,
        medianProductivity: 0,
        highestDay: null,
        lowestDay: null,
        routineCompletions: 0,
        projectPhasesCompleted: 0,
        xp: 0,
        level: 1,
      );
    }

    final totalPoints = snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints);
    final totalBonusEarned = snapshots.fold<int>(
      0,
      (sum, snapshot) => sum + snapshot.streakBonusPoints + snapshot.timingBonusPoints,
    );
    final highestStreakBonus = snapshots.fold<int>(0, (highest, snapshot) => math.max(highest, snapshot.streakBonusPoints));
    final totalFocusHours = snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.focusedHours);
    final totalCompletedTasks = snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.completedTasks);
    final averageScore = snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.productivityScore) / snapshots.length;
    final sortedScores = snapshots.map((snapshot) => snapshot.productivityScore).toList()..sort();
    final median = sortedScores.length.isOdd
        ? sortedScores[sortedScores.length ~/ 2]
        : (sortedScores[(sortedScores.length ~/ 2) - 1] + sortedScores[sortedScores.length ~/ 2]) / 2;
    final highest = snapshots.reduce((a, b) => a.productivityScore >= b.productivityScore ? a : b);
    final lowest = snapshots.reduce((a, b) => a.productivityScore <= b.productivityScore ? a : b);
    final xp = totalPoints ~/ 10;

    return LifetimeProductivityStats(
      snapshots: snapshots,
      lifetimeProductivity: averageScore,
      totalPoints: totalPoints,
      totalBonusEarned: totalBonusEarned,
      highestStreakBonus: highestStreakBonus,
      totalFocusHours: totalFocusHours,
      totalCompletedTasks: totalCompletedTasks,
      currentStreak: _currentStreak(snapshots, now ?? DateTime.now()),
      bestStreak: _bestStreak(snapshots),
      activeDays: snapshots.length,
      averageDailyScore: averageScore,
      medianProductivity: median,
      highestDay: highest,
      lowestDay: lowest,
      routineCompletions: snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.routineCompletions),
      projectPhasesCompleted: snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.projectPhasesCompleted),
      xp: xp,
      level: math.max(1, (xp ~/ 120) + 1),
    );
  }

  static int _currentStreak(List<ProductivitySnapshot> snapshots, DateTime now) {
    final activeDates = snapshots.where((snapshot) => snapshot.productivityScore > 0).map((snapshot) => DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day)).toSet();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!activeDates.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    var streak = 0;
    while (activeDates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int _bestStreak(List<ProductivitySnapshot> snapshots) {
    final dates = snapshots.where((snapshot) => snapshot.productivityScore > 0).map((snapshot) => DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day)).toList()..sort();
    if (dates.isEmpty) return 0;
    var best = 1;
    var current = 1;
    for (var i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      best = math.max(best, current);
    }
    return best;
  }
}
