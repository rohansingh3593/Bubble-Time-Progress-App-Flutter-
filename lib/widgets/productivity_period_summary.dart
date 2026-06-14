import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/productivity_snapshot.dart';

class ProductivityIntervalSummary {
  final String label;
  final int points;
  final double score;

  const ProductivityIntervalSummary({required this.label, required this.points, required this.score});
}

class PeriodProductivityStats {
  final String title;
  final String periodLabel;
  final List<ProductivitySnapshot> snapshots;
  final int maximumPoints;
  final int totalDays;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final List<ProductivityIntervalSummary> intervals;

  const PeriodProductivityStats({
    required this.title,
    required this.periodLabel,
    required this.snapshots,
    required this.maximumPoints,
    required this.totalDays,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    this.intervals = const <ProductivityIntervalSummary>[],
  });

  int get totalPoints => snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints);
  int get totalXp => totalPoints ~/ 10;
  int get streakBonusEarned => snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.streakBonusPoints);
  int get completedPhases => snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.projectPhasesCompleted);
  int get routineCompletions => snapshots.fold<int>(0, (sum, snapshot) => sum + snapshot.routineCompletions);
  int get activeDays => snapshots.where((snapshot) => snapshot.totalPoints > 0 || snapshot.totalHours > 0).length;
  double get bothHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.bothHours);
  double get importantHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.importantHours);
  double get urgentHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.urgentHours);
  double get neitherHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.neitherHours);
  double get totalHours => snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.totalHours);
  double get productivityScore => maximumPoints <= 0 ? 0 : (totalPoints / maximumPoints * 100).clamp(0.0, 100.0).toDouble();
  double get averageDailyScore => snapshots.isEmpty ? 0 : snapshots.fold<double>(0, (sum, snapshot) => sum + snapshot.productivityScore) / snapshots.length;
  double get routineCompletionRate => completedTasks + pendingTasks + overdueTasks == 0 ? 0 : routineCompletions / (completedTasks + pendingTasks + overdueTasks) * 100;
  String get rating => ProductivitySnapshot.ratingForScore(productivityScore);

  ProductivitySnapshot? get bestDay => _extremeSnapshot(highest: true);
  ProductivitySnapshot? get worstDay => _extremeSnapshot(highest: false);
  ProductivityIntervalSummary? get bestInterval => _extremeInterval(highest: true);
  ProductivityIntervalSummary? get worstInterval => _extremeInterval(highest: false);

  ProductivitySnapshot? _extremeSnapshot({required bool highest}) {
    final recorded = snapshots.where((snapshot) => snapshot.totalPoints > 0 || snapshot.productivityScore > 0).toList();
    if (recorded.isEmpty) return null;
    recorded.sort((a, b) => highest ? b.productivityScore.compareTo(a.productivityScore) : a.productivityScore.compareTo(b.productivityScore));
    return recorded.first;
  }

  ProductivityIntervalSummary? _extremeInterval({required bool highest}) {
    final recorded = intervals.where((interval) => interval.points > 0 || interval.score > 0).toList();
    if (recorded.isEmpty) return null;
    recorded.sort((a, b) => highest ? b.score.compareTo(a.score) : a.score.compareTo(b.score));
    return recorded.first;
  }
}

class ProductivityPeriodSummaryCard extends StatelessWidget {
  final PeriodProductivityStats stats;
  final bool showHeatMap;

  const ProductivityPeriodSummaryCard({super.key, required this.stats, this.showHeatMap = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${stats.title} • ${stats.periodLabel}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ),
              _ScoreBadge(score: stats.productivityScore, rating: stats.rating),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(label: 'Productivity', value: '${stats.productivityScore.round()}%', icon: Icons.insights_rounded),
              _MetricCard(label: 'Rating', value: stats.rating, icon: Icons.emoji_events_outlined),
              _MetricCard(label: 'Total Points', value: '${stats.totalPoints} / ${stats.maximumPoints}', icon: Icons.diamond_outlined),
              _MetricCard(label: 'Total XP', value: '${stats.totalXp}', icon: Icons.bolt_rounded),
              _MetricCard(label: 'Focus Hours', value: _formatHours(stats.totalHours), icon: Icons.timer_outlined),
              _MetricCard(label: 'Active Days', value: '${stats.activeDays} / ${stats.totalDays}', icon: Icons.calendar_today_outlined),
              _MetricCard(label: 'Average Daily Score', value: '${stats.averageDailyScore.round()}%', icon: Icons.show_chart_rounded),
              _MetricCard(label: 'Completed Tasks', value: '${stats.completedTasks}', icon: Icons.check_circle_outline),
              _MetricCard(label: 'Completed Phases', value: '${stats.completedPhases}', icon: Icons.layers_outlined),
              _MetricCard(label: 'Routine Completion', value: '${stats.routineCompletionRate.round()}%', icon: Icons.repeat_rounded),
              _MetricCard(label: 'Streak Bonus', value: '${stats.streakBonusEarned}', icon: Icons.local_fire_department_outlined),
              _MetricCard(label: 'Best Day', value: _dayLabel(stats.bestDay), icon: Icons.arrow_upward_rounded),
              _MetricCard(label: 'Worst Day', value: _dayLabel(stats.worstDay), icon: Icons.arrow_downward_rounded),
              if (stats.bestInterval != null) _MetricCard(label: stats.title.contains('Year') ? 'Best Month' : 'Best Week', value: _intervalLabel(stats.bestInterval!), icon: Icons.trending_up_rounded),
              if (stats.worstInterval != null) _MetricCard(label: stats.title.contains('Year') ? 'Worst Month' : 'Worst Week', value: _intervalLabel(stats.worstInterval!), icon: Icons.trending_down_rounded),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Important / Urgent Category Hours', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          _categoryBreakdown(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _trendBars()),
              const SizedBox(width: 12),
              SizedBox(width: 118, child: _completionDonut()),
            ],
          ),
          if (stats.intervals.isNotEmpty) ...[
            const SizedBox(height: 16),
            _intervalComparison(),
          ],
          if (showHeatMap) ...[
            const SizedBox(height: 16),
            _heatMap(),
          ],
        ],
      ),
    );
  }

  Widget _categoryBreakdown() {
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
                    Flexible(
                      flex: 5,
                      child: Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: LinearProgressIndicator(
                        value: stats.totalHours == 0 ? 0 : (item.$2 / stats.totalHours).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: item.$3,
                        backgroundColor: item.$3.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      child: Text(
                        _formatHours(item.$2),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _trendBars() {
    final visible = stats.snapshots.length > 31 ? stats.intervals : stats.snapshots.map((snapshot) => ProductivityIntervalSummary(label: '${snapshot.date.day}', points: snapshot.totalPoints, score: snapshot.productivityScore)).toList();
    return Container(
      height: 158,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F4EC), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📈 Productivity Trend', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visible.take(31).map((item) {
                final value = item.score.clamp(0.0, 100.0).toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: math.max(value / 100, 0.03),
                      child: Container(decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completionDonut() {
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
              CircularProgressIndicator(value: completedRatio, strokeWidth: 12, color: AppColors.taskCompleted, backgroundColor: AppColors.taskPending.withOpacity(0.25)),
              Text('${(completedRatio * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('Completed vs Pending', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _intervalComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📊 Period Comparison', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        ...stats.intervals.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  SizedBox(width: 72, child: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w900))),
                  Expanded(child: LinearProgressIndicator(value: (item.score / 100).clamp(0.0, 1.0), color: AppColors.primary, backgroundColor: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(999))),
                  const SizedBox(width: 8),
                  Text('${item.score.round()}% • ${item.points} pts', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _heatMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📅 Productivity Heat Map', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: stats.snapshots
              .map((snapshot) => Tooltip(
                    message: '${snapshot.date.toIso8601String().split('T').first}: ${snapshot.productivityScore.round()}% • ${snapshot.totalPoints} pts',
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: _heatColor(snapshot.productivityScore), borderRadius: BorderRadius.circular(3)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Color _heatColor(double score) {
    if (score >= 80) return AppColors.taskCompleted;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return Colors.orange;
    if (score > 0) return Colors.redAccent;
    return Colors.grey.withOpacity(0.24);
  }

  String _formatHours(double hours) {
    if (hours == 0) return '0 hrs';
    if (hours == hours.roundToDouble()) return '${hours.round()} hrs';
    return '${hours.toStringAsFixed(1)} hrs';
  }

  String _dayLabel(ProductivitySnapshot? snapshot) {
    if (snapshot == null) return 'N/A';
    return '${snapshot.date.day}/${snapshot.date.month} ${snapshot.productivityScore.round()}%';
  }

  String _intervalLabel(ProductivityIntervalSummary interval) => '${interval.label} ${interval.score.round()}%';
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F4EC), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.12))),
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
      decoration: BoxDecoration(color: AppColors.taskCompleted.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.taskCompleted.withOpacity(0.36))),
      child: Text('${score.round()}% • $rating', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
    );
  }
}
