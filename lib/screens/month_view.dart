import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import 'task_screen.dart';

class MonthView extends StatefulWidget {
  final HiveService hiveService;

  const MonthView({super.key, required this.hiveService});

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
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

  List<String> _getDayHeaders() {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }

  int _getWeekdayOffset(DateTime month) {
    // Monday = 1, Sunday = 7
    final firstDay = DateTime(month.year, month.month, 1);
    return (firstDay.weekday - 1) % 7; // 0 for Monday
  }

  int _getDaysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final weekdayOffset = _getWeekdayOffset(_currentMonth);
    final totalCells = weekdayOffset + daysInMonth;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                });
              },
            ),
            Text('${_getMonthName(_currentMonth.month)} ${_currentMonth.year}'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                });
              },
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.listenable(),
        builder: (context, box, _) {
          return Column(
            children: [
              // Day headers
              Row(
                children: _getDayHeaders().map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8.0),
              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 4.0,
                    mainAxisSpacing: 4.0,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < weekdayOffset) {
                      return const SizedBox.shrink(); // Empty cells
                    }

                    final day = index - weekdayOffset + 1;
                    final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                    final summary = widget.hiveService.getTaskSummaryForDate(date);
                    final isToday = isCurrentMonth && day == now.day;
                    final todayStart = DateTime(now.year, now.month, now.day);

                    return BubbleWidget(
                      color: _getBubbleColor(date, summary, todayStart),
                      isHighlighted: isToday,
                      onTap: () => _showTaskScreen(date),
                      label: day.toString(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: isCurrentMonth
          ? FloatingActionButton(
              onPressed: () async {
                final today = DateTime(now.year, now.month, now.day);
                await showQuickAddTaskDialog(context, today, widget.hiveService);
              },
              tooltip: 'Add task for today',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}