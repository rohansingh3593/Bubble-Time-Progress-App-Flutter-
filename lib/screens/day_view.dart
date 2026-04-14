import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../services/hive_service.dart';
import '../models/task_model.dart';
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
  bool _showTodayTasks = true;

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
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final todayTasks = widget.hiveService.getTasksForDate(_currentDay);

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
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
                const SizedBox(height: 10),
                _todayTasksPanel(todayTasks),
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

  Widget _todayTasksPanel(List<Task> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            onTap: () {
              setState(() {
                _showTodayTasks = !_showTodayTasks;
              });
            },
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFAED9AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "TODAY'S TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_showTodayTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showTodayTasks) ...[
            Container(
              width: double.infinity,
              color: const Color(0xFFE8C1A0),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                'TASK',
                textAlign: TextAlign.center,
                style: TextStyle(letterSpacing: 3),
              ),
            ),
            SizedBox(
              height: 170,
              child: tasks.isEmpty
                  ? const Center(child: Text('Nothing for Today, Great Job !'))
                  : ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          dense: true,
                          title: Text(task.task),
                          subtitle: Text('${task.priority} • ${task.status}'),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
