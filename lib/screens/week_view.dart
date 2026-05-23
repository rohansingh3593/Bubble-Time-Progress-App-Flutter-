import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import '../models/task_model.dart';

class WeekView extends StatefulWidget {
  final HiveService hiveService;

  const WeekView({super.key, required this.hiveService});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  late DateTime _currentWeekStart;
  bool _showWeeklyTasks = true;

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



  String _normalizedRepeatFrequency(Task task) {
    final normalized = task.repeatFrequency?.trim().toLowerCase();
    switch (normalized) {
      case 'daily':
      case 'weekly':
      case 'monthly':
      case 'yearly':
        return normalized!;
      default:
        return '';
    }
  }

  bool _isRecurringTask(Task task) => task.repeatTask && _normalizedRepeatFrequency(task).isNotEmpty;

  Future<Task?> _showRecurringStatusUpdateDialog(Task task) {
    return showDialog<Task>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${task.task} status'),
        content: const Text('Recurring tasks keep their details fixed. Update only this occurrence status.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(task.copyWith(done: false, status: 'Missed')),
            child: const Text('Mark Missed'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(task.copyWith(done: true, status: 'Completed')),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTask(Task task) async {
    final updated = _isRecurringTask(task)
        ? await _showRecurringStatusUpdateDialog(task)
        : await showTaskFormDialog(
            context,
            date: task.dueDate,
            initialTask: task,
            title: 'Update Task',
            actionLabel: 'Save Task',
          );

    if (updated != null) {
      await widget.hiveService.updateTaskByReference(task, updated);
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

  Map<String, int> _getCompletedSummaryForDate(DateTime date) {
    final completedTasks = widget.hiveService
        .getTasksForDate(date)
        .where((task) => task.status == 'Completed')
        .toList();

    return {
      'completed': completedTasks.length,
      'pending': 0,
    };
  }

  List<Task> _getWeeklyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final weekStart = DateTime(_currentWeekStart.year, _currentWeekStart.month, _currentWeekStart.day);
    final weekEnd = weekStart.add(const Duration(days: 6));

    return allTasksByDate.values
        .expand((tasks) => tasks)
        .where((task) {
          final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          return task.repeatTask &&
              task.repeatFrequency == 'Weekly' &&
              !dueDate.isBefore(weekStart) &&
              !dueDate.isAfter(weekEnd);
        })
        .toList();
  }

  Widget _weeklyTasksPanel(List<Task> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showWeeklyTasks = !_showWeeklyTasks),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFAED9AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "WEEKLY TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_showWeeklyTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showWeeklyTasks)
            SizedBox(
              height: 140,
              child: tasks.isEmpty
                  ? const Center(child: Text('Nothing for this week, Great Job !'))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          dense: true,
                          onTap: () => _editTask(task),
                          title: Text(task.task),
                          subtitle: Text('${task.priority} • ${task.status}'),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
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
          final weeklyTasks = _getWeeklyRepeatingTasks();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (index) {
                      final date = weekDays[index];
                      final summary = _getCompletedSummaryForDate(date);
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
                ),
                const SizedBox(height: 8),
                _weeklyTasksPanel(weeklyTasks),
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
