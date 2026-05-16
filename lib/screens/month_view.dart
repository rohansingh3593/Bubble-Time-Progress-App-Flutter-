import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import '../models/task_model.dart';

class MonthView extends StatefulWidget {
  final HiveService hiveService;

  const MonthView({super.key, required this.hiveService});

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _currentMonth;
  bool _showMonthlyTasks = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  Color _getBubbleColor(DateTime date, List<Task> tasks, DateTime today) {
    final selectedTaskColor = _selectedTaskColor(tasks);
    if (selectedTaskColor != null) return selectedTaskColor;
    if (date.isBefore(today)) return AppColors.passed;
    return AppColors.taskNone;
  }

  Color? _selectedTaskColor(List<Task> tasks) {
    final activeTasks = tasks.where((task) => task.status != 'Cancelled').toList();
    if (activeTasks.isEmpty) return null;

    for (final task in activeTasks) {
      if (task.done || task.status == 'Completed') return Color(task.colorValue);
    }

    return Color(activeTasks.first.colorValue);
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


  Future<void> _editTask(Task task) async {
    final updated = await showTaskFormDialog(
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


  List<Task> _getMonthlyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    return allTasksByDate.values
        .expand((tasks) => tasks)
        .where((task) {
          final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          return task.repeatTask &&
              task.repeatFrequency == 'Monthly' &&
              !dueDate.isBefore(monthStart) &&
              !dueDate.isAfter(monthEnd);
        })
        .toList();
  }

  Widget _monthlyTasksPanel(List<Task> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showMonthlyTasks = !_showMonthlyTasks),
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
                      "MONTHLY TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_showMonthlyTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showMonthlyTasks)
            SizedBox(
              height: 140,
              child: tasks.isEmpty
                  ? const Center(child: Text('Nothing for this month, Great Job !'))
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
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final monthlyTasks = _getMonthlyRepeatingTasks();
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
                    final tasksForDate = widget.hiveService.getTasksForDate(date);
                    final isToday = isCurrentMonth && day == now.day;
                    final todayStart = DateTime(now.year, now.month, now.day);

                    return BubbleWidget(
                      color: _getBubbleColor(date, tasksForDate, todayStart),
                      isHighlighted: isToday,
                      onTap: () => _openQuickAddForDate(date),
                      label: day.toString(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _monthlyTasksPanel(monthlyTasks),
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