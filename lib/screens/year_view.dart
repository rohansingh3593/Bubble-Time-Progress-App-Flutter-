import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../utils/grid_utils.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import '../models/task_model.dart';
import 'task_screen.dart';

class YearView extends StatefulWidget {
  final HiveService hiveService;

  const YearView({super.key, required this.hiveService});

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  late DateTime _currentYear;
  bool _showYearlyTasks = true;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now();
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


  List<Task> _getYearlyRepeatingTasks() {
    final allTasksByDate = widget.hiveService.getAllTasksByDate();
    final yearStart = DateTime(_currentYear.year, 1, 1);
    final yearEnd = DateTime(_currentYear.year, 12, 31);

    return allTasksByDate.values
        .expand((tasks) => tasks)
        .where((task) {
          final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          return task.repeatTask &&
              task.repeatFrequency == 'Yearly' &&
              !dueDate.isBefore(yearStart) &&
              !dueDate.isAfter(yearEnd);
        })
        .toList();
  }

  Widget _yearlyTasksPanel(List<Task> tasks) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECE8E6),
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showYearlyTasks = !_showYearlyTasks),
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
                      "YEARLY TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_showYearlyTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showYearlyTasks)
            SizedBox(
              height: 140,
              child: tasks.isEmpty
                  ? const Center(child: Text('Nothing for this year, Great Job !'))
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
    final isCurrentYear = _currentYear.year == now.year;
    final daysInYear = DateTime(_currentYear.year + 1, 1, 1)
        .difference(DateTime(_currentYear.year, 1, 1))
        .inDays;
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentYear.year} Progress'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Prev Year'),
                    onPressed: () {
                      setState(() {
                        _currentYear = DateTime(_currentYear.year - 1);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('Next Year'),
                    onPressed: () {
                      setState(() {
                        _currentYear = DateTime(_currentYear.year + 1);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final yearlyTasks = _getYearlyRepeatingTasks();
          return Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gridDims = calculateGridDimensions(
                      daysInYear,
                      constraints.maxWidth,
                      constraints.maxHeight,
                      viewType: 'year',
                    );

                    return GridView.builder(
                      padding: const EdgeInsets.all(16.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridDims['columns'],
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
                      ),
                      itemCount: daysInYear,
                      itemBuilder: (context, index) {
                        final date = DateTime(_currentYear.year, 1, index + 1);
                        final tasksForDate = widget.hiveService.getTasksForDate(date);
                        final isToday = isCurrentYear && date.day == now.day && date.month == now.month;

                        return BubbleWidget(
                          color: _getBubbleColor(date, tasksForDate, todayStart),
                          isHighlighted: isToday,
                          onTap: () => _showTaskScreen(date),
                        );
                      },
                    );
                  },
                ),
              ),
              _yearlyTasksPanel(yearlyTasks),
            ],
          );
        },
      ),
      floatingActionButton: isCurrentYear
          ? FloatingActionButton(
              onPressed: () async {
                await showQuickAddTaskDialog(context, todayStart, widget.hiveService);
              },
              tooltip: 'Add task for today',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}