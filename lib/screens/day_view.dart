import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import 'task_screen.dart';

class DayView extends StatefulWidget {
  final HiveService hiveService;

  const DayView({super.key, required this.hiveService});

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late DateTime _currentDay;

  @override
  void initState() {
    super.initState();
    _currentDay = DateTime.now();
  }

  Color _getBubbleColor(int hour, bool isToday, bool isPastDay, Map<String, int> summary, int currentHour) {
    if (isPastDay || (isToday && hour < currentHour)) {
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

  void _showTaskScreen(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: TaskScreen(
            date: date,
            hiveService: widget.hiveService,
          ),
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final isToday = _currentDay.year == now.year && _currentDay.month == now.month && _currentDay.day == now.day;
    final isPastDay = _currentDay.isBefore(todayStart);
    final summary = widget.hiveService.getTaskSummaryForDate(_currentDay);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _currentDay = _currentDay.subtract(const Duration(days: 1));
                });
              },
            ),
            Text('${_currentDay.month}/${_currentDay.day}/${_currentDay.year}'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _currentDay = _currentDay.add(const Duration(days: 1));
                });
              },
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.listenable(),
        builder: (context, box, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 24 hour bubbles in 6x4 grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6, // 6 columns
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: 24,
                    itemBuilder: (context, index) {
                      final hour = index;
                      final isCurrentHour = isToday && hour == now.hour;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: BubbleWidget(
                              color: _getBubbleColor(hour, isToday, isPastDay, summary, now.hour),
                              isHighlighted: isCurrentHour,
                              onTap: () => _showTaskScreen(_currentDay),
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            _formatHour(hour),
                            style: const TextStyle(fontSize: 10.0),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showQuickAddTaskDialog(context, _currentDay, widget.hiveService);
        },
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }
}