import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';

class WeekView extends StatefulWidget {
  final HiveService hiveService;

  const WeekView({super.key, required this.hiveService});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  late DateTime _currentWeekStart;

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

  Color _getBubbleColor(DateTime date, Map<String, int> summary, DateTime today) {
    if (date.isBefore(today)) {
      return AppColors.passed;
    }

    if (summary['completed']! > 0 && summary['pending']! == 0) {
      return AppColors.taskCompleted;
    } else if (summary['pending']! > 0) {
      return AppColors.taskPending;
    } else {
      return AppColors.taskNone;
    }
  }

  Future<void> _openQuickAddForDate(DateTime date) async {
    final selectedDate = DateTime(date.year, date.month, date.day);
    final task = await showTaskFormDialog(
      context,
      date: selectedDate,
      title: 'Add Task',
      actionLabel: 'Save Task',
    );

    if (task != null) {
      await widget.hiveService.addTask(selectedDate, task);
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
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Week bubbles in a row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (index) {
                    final date = weekDays[index];
                    final summary = widget.hiveService.getTaskSummaryForDate(date);
                    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BubbleWidget(
                            color: _getBubbleColor(date, summary, todayStart),
                            isHighlighted: isToday,
                            onTap: () => _openQuickAddForDate(date),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            _getDayLabels()[index],
                            style: const TextStyle(fontSize: 12.0),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
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