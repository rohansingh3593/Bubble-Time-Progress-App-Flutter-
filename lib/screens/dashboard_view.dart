import 'package:flutter/material.dart';
import '../services/hive_service.dart';

class DashboardView extends StatefulWidget {
  final HiveService hiveService;

  const DashboardView({super.key, required this.hiveService});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _calculateStats() {
    final now = DateTime.now();
    final thisYear = DateTime(now.year, 1, 1);
    final nextYear = DateTime(now.year + 1, 1, 1);
    final totalDaysInYear = nextYear.difference(thisYear).inDays;
    final daysPassed = now.difference(thisYear).inDays + 1;
    final daysRemaining = totalDaysInYear - daysPassed;

    int totalTasks = 0;
    int completedTasks = 0;
    int todayTasks = 0;
    int todayCompleted = 0;

    for (int i = 0; i < daysPassed; i++) {
      final date = thisYear.add(Duration(days: i));
      final summary = widget.hiveService.getTaskSummaryForDate(date);
      totalTasks += summary['completed']! + summary['pending']!;
      completedTasks += summary['completed']!;

      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        todayTasks = summary['completed']! + summary['pending']!;
        todayCompleted = summary['completed']!;
      }
    }

    _stats = {
      'totalDaysInYear': totalDaysInYear,
      'daysPassed': daysPassed,
      'daysRemaining': daysRemaining,
      'yearProgress': (daysPassed / totalDaysInYear * 100).round(),
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0,
      'todayTasks': todayTasks,
      'todayCompleted': todayCompleted,
      'todayRate': todayTasks > 0 ? (todayCompleted / todayTasks * 100).round() : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateTime.now().year} Progress Overview',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Year Progress',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Days Passed: ${_stats['daysPassed']} / ${_stats['totalDaysInYear']}'),
                          Text('Remaining: ${_stats['daysRemaining']}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _stats['yearProgress'] / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                      ),
                      const SizedBox(height: 4),
                      Text('${_stats['yearProgress']}% of year completed'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Task Progress (This Year)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Tasks: ${_stats['totalTasks']}'),
                          Text('Completed: ${_stats['completedTasks']}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _stats['completionRate'] / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text('${_stats['completionRate']}% tasks completed'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tasks: ${_stats['todayTasks']}'),
                          Text('Completed: ${_stats['todayCompleted']}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _stats['todayRate'] / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      Text('${_stats['todayRate']}% Complete'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}