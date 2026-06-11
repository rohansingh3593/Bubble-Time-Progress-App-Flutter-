import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/productivity_snapshot.dart';
import '../models/rank_profile.dart';
import '../services/hive_service.dart';

class ProductivityTimelineView extends StatefulWidget {
  final HiveService hiveService;

  const ProductivityTimelineView({super.key, required this.hiveService});

  @override
  State<ProductivityTimelineView> createState() => _ProductivityTimelineViewState();
}

class _ProductivityTimelineViewState extends State<ProductivityTimelineView> {
  String _range = 'Last 30 Days';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Productivity Timeline', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final snapshots = widget.hiveService.getProductivitySnapshots();
          final stats = widget.hiveService.getLifetimeProductivityStats();
          final username = widget.hiveService.getUsername();
          final filtered = _filterSnapshots(snapshots, _range);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _LifetimePerformanceCard(username: username, stats: stats),
              const SizedBox(height: 16),
              _PointsTotalsCard(snapshots: snapshots, stats: stats),
              const SizedBox(height: 16),
              _PointsAnalyticsCard(snapshots: snapshots),
              const SizedBox(height: 16),
              _OverviewCards(stats: stats),
              const SizedBox(height: 16),
              _TrendCard(
                snapshots: filtered,
                selectedRange: _range,
                onRangeChanged: (value) => setState(() => _range = value),
              ),
              const SizedBox(height: 16),
              _HeatMapCard(
                snapshots: snapshots,
                onTapSnapshot: _showSnapshotDetails,
              ),
              const SizedBox(height: 16),
              _ReportsCard(snapshots: snapshots),
              const SizedBox(height: 16),
              _HistoryList(snapshots: snapshots.reversed.toList(), onTapSnapshot: _showSnapshotDetails),
            ],
          );
        },
      ),
    );
  }

  List<ProductivitySnapshot> _filterSnapshots(List<ProductivitySnapshot> snapshots, String range) {
    if (range == 'All Time') return snapshots;
    final now = DateTime.now();
    final days = switch (range) {
      'Last 7 Days' => 7,
      'Last 90 Days' => 90,
      'Last Year' => 365,
      _ => 30,
    };
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    return snapshots.where((snapshot) => !snapshot.date.isBefore(cutoff)).toList();
  }

  void _showSnapshotDetails(ProductivitySnapshot snapshot) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_formatDate(snapshot.date)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailLine('Total Hours', _formatHours(snapshot.totalHours)),
              _detailLine('Both', _formatHours(snapshot.bothHours)),
              _detailLine('Important', _formatHours(snapshot.importantHours)),
              _detailLine('Urgent', _formatHours(snapshot.urgentHours)),
              _detailLine('Neither', _formatHours(snapshot.neitherHours)),
              _detailLine('Base Points', '+${snapshot.basePoints}'),
              _detailLine('Streak Bonus', '+${snapshot.streakBonusPoints}'),
              _detailLine('Total Points', '${snapshot.totalPoints} / ${ProductivitySnapshot.maximumPoints.round()}'),
              _detailLine('Productivity', '${snapshot.productivityScore.toStringAsFixed(1)}%'),
              _detailLine('Rating', snapshot.rating),
              const SizedBox(height: 12),
              const Text('Points history', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              if (snapshot.pointEvents.isEmpty)
                const Text('No point events recorded for this day.')
              else
                ...snapshot.pointEvents.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• ${event.title}: base +${event.basePoints}, bonus +${event.streakBonusPoints}, total +${event.totalPoints}${event.reason.isEmpty ? '' : ' (${event.reason})'}'),
                    )),
              const SizedBox(height: 12),
              const Text('Completed work', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              if (snapshot.completedTaskNames.isEmpty)
                const Text('No completed tasks recorded for this day.')
              else
                ...snapshot.completedTaskNames.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $task'),
                    )),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(value),
        ],
      ),
    );
  }
}


class _LifetimePerformanceCard extends StatelessWidget {
  final String username;
  final LifetimeProductivityStats stats;

  const _LifetimePerformanceCard({required this.username, required this.stats});

  @override
  Widget build(BuildContext context) {
    final rank = RankTier.forLevel(stats.level);
    final currentAchievement = _achievementForPoints(stats.totalPoints);
    final nextAchievement = _nextAchievementForPoints(stats.totalPoints);
    final milestone = nextAchievement?.points ?? currentAchievement.points;
    final progress = milestone == 0 ? 1.0 : (stats.totalPoints / milestone).clamp(0.0, 1.0).toDouble();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    ProductivitySnapshot? todaySnapshot;
    for (final snapshot in stats.snapshots) {
      final snapshotDate = DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day);
      if (snapshotDate == todayDate) {
        todaySnapshot = snapshot;
        break;
      }
    }

    return _TimelineSection(
      title: '👤 Lifetime Performance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(rank.colorValue).withOpacity(0.16),
                child: Text(rank.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('🏆 Rank: ${rank.name}  •  ⭐ Level: ${stats.level}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatTile(label: '💎 Lifetime Points', value: _formatInt(stats.totalPoints)),
              _StatTile(label: '⭐ Today’s Points', value: '+${_formatInt(todaySnapshot?.totalPoints ?? 0)}'),
              _StatTile(label: '🔥 Today’s Bonus', value: '+${_formatInt(todaySnapshot?.streakBonusPoints ?? 0)}'),
              _StatTile(label: '⚡ Lifetime XP', value: _formatInt(stats.xp)),
              _StatTile(label: '🔥 Current Streak', value: '${stats.currentStreak} days'),
              _StatTile(label: '🏅 Best Streak', value: '${stats.bestStreak} days'),
              _StatTile(label: '📊 Avg Productivity', value: '${stats.averageDailyScore.toStringAsFixed(1)}%'),
              _StatTile(label: '⏱ Focus Hours', value: _formatHours(stats.totalFocusHours)),
              _StatTile(label: '✅ Tasks Completed', value: _formatInt(stats.totalCompletedTasks)),
              _StatTile(label: '📚 Phases Completed', value: _formatInt(stats.projectPhasesCompleted)),
              _StatTile(label: '🎁 Total Bonus Earned', value: '+${_formatInt(stats.totalBonusEarned)}'),
              _StatTile(label: '🏆 Highest Streak Bonus', value: '+${_formatInt(stats.highestStreakBonus)}'),
              _StatTile(label: '📅 Active Days', value: _formatInt(stats.activeDays)),
              _StatTile(label: '🏅 Achievement', value: '${currentAchievement.emoji} ${currentAchievement.name}'),
            ].map((tile) => SizedBox(width: 168, child: tile)).toList(),
          ),
          const SizedBox(height: 16),
          Text('Lifetime Points Milestone', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              color: AppColors.primary,
              backgroundColor: Colors.black12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nextAchievement == null
                ? '${_formatInt(stats.totalPoints)} lifetime points • All milestones unlocked'
                : '${_formatInt(stats.totalPoints)} / ${_formatInt(nextAchievement.points)} (${(progress * 100).round()}%) • Next: ${nextAchievement.emoji} ${nextAchievement.name}',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pointAchievements.map((achievement) {
              final unlocked = stats.totalPoints >= achievement.points;
              return Chip(
                avatar: Text(achievement.emoji),
                label: Text('${achievement.name} (${_formatInt(achievement.points)})'),
                backgroundColor: unlocked ? AppColors.primary.withOpacity(0.14) : Colors.grey.shade200,
                labelStyle: TextStyle(fontWeight: FontWeight.w800, color: unlocked ? AppColors.textPrimary : Colors.black45),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PointsTotalsCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final LifetimeProductivityStats stats;

  const _PointsTotalsCard({required this.snapshots, required this.stats});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);
    final yearStart = DateTime(today.year, 1, 1);
    return _TimelineSection(
      title: '📉 Cumulative Points',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatTile(label: 'This Week', value: '${_formatInt(_pointsSince(snapshots, weekStart))} pts'),
          _StatTile(label: 'This Month', value: '${_formatInt(_pointsSince(snapshots, monthStart))} pts'),
          _StatTile(label: 'This Year', value: '${_formatInt(_pointsSince(snapshots, yearStart))} pts'),
          _StatTile(label: 'Streak Bonus', value: '+${_formatInt(stats.totalBonusEarned)} pts'),
          _StatTile(label: 'Lifetime', value: '${_formatInt(stats.totalPoints)} pts'),
        ].map((tile) => SizedBox(width: 168, child: tile)).toList(),
      ),
    );
  }
}

class _PointsAnalyticsCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;

  const _PointsAnalyticsCard({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final recent = snapshots.length <= 14 ? snapshots : snapshots.sublist(snapshots.length - 14);
    final maxPoints = recent.fold<int>(1, (max, snapshot) => math.max(max, snapshot.totalPoints));
    var cumulative = 0;
    return _TimelineSection(
      title: '📈 Points Analytics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isEmpty)
            const Text('Complete tasks to build daily points charts.')
          else
            ...recent.map((snapshot) {
              cumulative += snapshot.totalPoints;
              final value = snapshot.totalPoints / maxPoints;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 54, child: Text('${snapshot.date.month}/${snapshot.date.day}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: value, minHeight: 10, color: _heatColor(snapshot.productivityScore), backgroundColor: Colors.black12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 92, child: Text('${_formatInt(snapshot.totalPoints)} pts', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ],
                ),
              );
            }),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Lifetime growth in this view: ${_formatInt(cumulative)} points', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final LifetimeProductivityStats stats;

  const _OverviewCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Lifetime Productivity', '${stats.lifetimeProductivity.toStringAsFixed(1)}%'),
      ('Total Points Earned', '${stats.totalPoints}'),
      ('Total Focus Hours', _formatHours(stats.totalFocusHours)),
      ('Total Completed Tasks', '${stats.totalCompletedTasks}'),
      ('Current Streak', '${stats.currentStreak} days'),
      ('Best Streak', '${stats.bestStreak} days'),
      ('Active Days', '${stats.activeDays}'),
      ('Average Daily Score', '${stats.averageDailyScore.toStringAsFixed(1)}%'),
      ('Highest Score', stats.highestDay == null ? '0%' : '${stats.highestDay!.productivityScore.toStringAsFixed(1)}%'),
      ('Lowest Score', stats.lowestDay == null ? '0%' : '${stats.lowestDay!.productivityScore.toStringAsFixed(1)}%'),
      ('Routine Completions', '${stats.routineCompletions}'),
      ('Project Phases Done', '${stats.projectPhasesCompleted}'),
      ('XP / Level', '${stats.xp} XP • Lv ${stats.level}'),
      ('Median Score', '${stats.medianProductivity.toStringAsFixed(1)}%'),
    ];

    return _TimelineSection(
      title: 'Lifetime Overview',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map((card) => SizedBox(
                  width: 168,
                  child: _StatTile(label: card.$1, value: card.$2),
                ))
            .toList(),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _TrendCard({required this.snapshots, required this.selectedRange, required this.onRangeChanged});

  @override
  Widget build(BuildContext context) {
    const ranges = ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last Year', 'All Time'];
    return _TimelineSection(
      title: 'Productivity Trend Graph',
      trailing: DropdownButton<String>(
        value: selectedRange,
        underline: const SizedBox.shrink(),
        items: ranges.map((range) => DropdownMenuItem(value: range, child: Text(range))).toList(),
        onChanged: (value) {
          if (value != null) onRangeChanged(value);
        },
      ),
      child: SizedBox(
        height: 210,
        child: snapshots.isEmpty
            ? const Center(child: Text('Complete tasks to build your trend line.'))
            : CustomPaint(
                painter: _TrendPainter(snapshots),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class _HeatMapCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final ValueChanged<ProductivitySnapshot> onTapSnapshot;

  const _HeatMapCard({required this.snapshots, required this.onTapSnapshot});

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final snapshot in snapshots) _dateKey(snapshot.date): snapshot};
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 364));
    return _TimelineSection(
      title: 'Calendar Heat Map',
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(365, (index) {
          final date = start.add(Duration(days: index));
          final snapshot = byKey[_dateKey(date)];
          final color = _heatColor(snapshot?.productivityScore ?? -1);
          return Tooltip(
            message: snapshot == null ? '${_formatDate(date)}: no score' : '${_formatDate(date)}: ${snapshot.productivityScore.toStringAsFixed(1)}%',
            child: InkWell(
              onTap: snapshot == null ? null : () => onTapSnapshot(snapshot),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ReportsCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;

  const _ReportsCard({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final monthly = _groupAverage(snapshots, (date) => '${_monthName(date.month)} ${date.year}');
    final yearly = _groupAverage(snapshots, (date) => '${date.year}');
    return _TimelineSection(
      title: 'Monthly & Yearly Reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (monthly.isEmpty) const Text('No monthly reports yet.'),
          ...monthly.take(4).map((entry) => _ReportRow(label: entry.key, report: entry.value)),
          const SizedBox(height: 12),
          const Text('Yearly', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (yearly.isEmpty) const Text('No yearly reports yet.'),
          ...yearly.take(4).map((entry) => _ReportRow(label: entry.key, report: entry.value)),
        ],
      ),
    );
  }

  List<MapEntry<String, _ProductivityReport>> _groupAverage(List<ProductivitySnapshot> snapshots, String Function(DateTime date) labelFor) {
    final groups = <String, List<ProductivitySnapshot>>{};
    for (final snapshot in snapshots) {
      groups.putIfAbsent(labelFor(snapshot.date), () => <ProductivitySnapshot>[]).add(snapshot);
    }
    final entries = groups.entries.map((entry) => MapEntry(entry.key, _ProductivityReport.fromSnapshots(entry.value))).toList();
    entries.sort((a, b) => b.value.latestDate.compareTo(a.value.latestDate));
    return entries;
  }
}

class _HistoryList extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final ValueChanged<ProductivitySnapshot> onTapSnapshot;

  const _HistoryList({required this.snapshots, required this.onTapSnapshot});

  @override
  Widget build(BuildContext context) {
    return _TimelineSection(
      title: 'Daily Productivity Journal',
      child: Column(
        children: snapshots.isEmpty
            ? [const Text('Daily records will appear here automatically after tasks are completed.')]
            : [
                const _DailyHistoryHeader(),
                ...snapshots.take(30).map((snapshot) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: _heatColor(snapshot.productivityScore), child: Text('${snapshot.productivityScore.round()}%', style: const TextStyle(fontSize: 11, color: Colors.white))),
                      title: Text(_formatDate(snapshot.date), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Points: ${_formatInt(snapshot.totalPoints)} (bonus +${_formatInt(snapshot.streakBonusPoints)}) • Productivity: ${snapshot.productivityScore.toStringAsFixed(1)}% • ${snapshot.rating}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onTapSnapshot(snapshot),
                    )),
              ],
      ),
    );
  }
}


class _DailyHistoryHeader extends StatelessWidget {
  const _DailyHistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: const Row(
        children: [
          SizedBox(width: 48, child: Text('Score', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54))),
          Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54))),
          Expanded(flex: 3, child: Text('Points • Productivity • Rating', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54))),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _TimelineSection({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final _ProductivityReport report;

  const _ReportRow({required this.label, required this.report});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label • Avg ${report.average.toStringAsFixed(1)}% • High ${report.highest.toStringAsFixed(1)}% • Low ${report.lowest.toStringAsFixed(1)}% • ${report.totalPoints} pts • ${_formatHours(report.focusHours)} • ${report.completedTasks} tasks'),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<ProductivitySnapshot> snapshots;

  _TrendPainter(this.snapshots);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final chart = Rect.fromLTWH(34, 8, size.width - 44, size.height - 34);

    for (final pct in [0, 25, 50, 75, 100]) {
      final y = chart.bottom - (pct / 100 * chart.height);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), axisPaint);
      textPainter.text = TextSpan(text: '$pct', style: const TextStyle(fontSize: 10, color: Colors.black45));
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - 6));
    }

    if (snapshots.length == 1) {
      final y = chart.bottom - (snapshots.first.productivityScore / 100 * chart.height);
      canvas.drawCircle(Offset(chart.center.dx, y), 5, Paint()..color = AppColors.primary);
      return;
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < snapshots.length; i++) {
      final x = chart.left + (i / math.max(1, snapshots.length - 1)) * chart.width;
      final y = chart.bottom - (snapshots[i].productivityScore / 100 * chart.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chart.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(chart.right, chart.bottom);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.snapshots != snapshots;
}

class _ProductivityReport {
  final DateTime latestDate;
  final double average;
  final double highest;
  final double lowest;
  final int totalPoints;
  final double focusHours;
  final int completedTasks;

  const _ProductivityReport({required this.latestDate, required this.average, required this.highest, required this.lowest, required this.totalPoints, required this.focusHours, required this.completedTasks});

  factory _ProductivityReport.fromSnapshots(List<ProductivitySnapshot> snapshots) {
    final sorted = snapshots.toList()..sort((a, b) => a.date.compareTo(b.date));
    return _ProductivityReport(
      latestDate: sorted.last.date,
      average: sorted.fold<double>(0, (sum, snapshot) => sum + snapshot.productivityScore) / sorted.length,
      highest: sorted.map((snapshot) => snapshot.productivityScore).reduce(math.max),
      lowest: sorted.map((snapshot) => snapshot.productivityScore).reduce(math.min),
      totalPoints: sorted.fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints),
      focusHours: sorted.fold<double>(0, (sum, snapshot) => sum + snapshot.focusedHours),
      completedTasks: sorted.fold<int>(0, (sum, snapshot) => sum + snapshot.completedTasks),
    );
  }
}


class _PointAchievement {
  final int points;
  final String emoji;
  final String name;

  const _PointAchievement(this.points, this.emoji, this.name);
}

const _pointAchievements = [
  _PointAchievement(1000, '🌱', 'Beginner'),
  _PointAchievement(5000, '🎯', 'Focused'),
  _PointAchievement(10000, '💪', 'Consistent'),
  _PointAchievement(25000, '🚀', 'Achiever'),
  _PointAchievement(50000, '🔥', 'Momentum Master'),
  _PointAchievement(100000, '👑', 'Legend'),
  _PointAchievement(250000, '💎', 'Grandmaster'),
  _PointAchievement(500000, '🌟', 'Productivity Titan'),
];

_PointAchievement _achievementForPoints(int points) {
  var current = _pointAchievements.first;
  for (final achievement in _pointAchievements) {
    if (points >= achievement.points) current = achievement;
  }
  return current;
}

_PointAchievement? _nextAchievementForPoints(int points) {
  for (final achievement in _pointAchievements) {
    if (points < achievement.points) return achievement;
  }
  return null;
}

int _pointsSince(List<ProductivitySnapshot> snapshots, DateTime start) {
  final startDay = DateTime(start.year, start.month, start.day);
  return snapshots
      .where((snapshot) => !DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day).isBefore(startDay))
      .fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints);
}

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

Color _heatColor(double score) {
  if (score < 0) return Colors.grey.shade200;
  if (score >= 90) return const Color(0xFF1B5E20);
  if (score >= 80) return const Color(0xFF43A047);
  if (score >= 60) return const Color(0xFFFDD835);
  if (score >= 40) return const Color(0xFFFF9800);
  return const Color(0xFFE53935);
}

String _dateKey(DateTime date) => date.toIso8601String().split('T').first;

String _formatDate(DateTime date) => '${date.day} ${_monthName(date.month)} ${date.year}';

String _formatHours(double hours) {
  if (hours == 0) return '0 hrs';
  final whole = hours.floor();
  final minutes = ((hours - whole) * 60).round();
  if (whole == 0) return '$minutes min';
  if (minutes == 0) return '$whole hrs';
  return '$whole hrs $minutes min';
}

String _monthName(int month) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[(month - 1).clamp(0, 11)];
}
