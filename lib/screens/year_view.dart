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


  String _normalizedStatus(Task task) => task.status.trim().toLowerCase();

  bool _isOccurrenceLocked(Task task) {
    final status = _normalizedStatus(task);
    return task.done || status == 'completed' || status == 'cancelled' || status == 'missed' || status == 'overdue';
  }

  String _occurrenceLabel(Task task) {
    switch (_normalizedRepeatFrequency(task)) {
      case 'daily':
        return 'today';
      case 'weekly':
        return 'this week';
      case 'monthly':
        return 'this month';
      case 'yearly':
        return 'this year';
      default:
        return 'this period';
    }
  }

  Future<Task?> _showRecurringStatusUpdateDialog(Task task) {
    Future<void> toggleRoutine(BuildContext dialogContext) async {
      await widget.hiveService.setRecurringTaskEnabledByReference(task, !task.routineEnabled);
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    }

    Widget toggleButton(BuildContext dialogContext) {
      return TextButton.icon(
        onPressed: () => toggleRoutine(dialogContext),
        icon: Icon(task.routineEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline),
        label: Text(task.routineEnabled ? 'Disable Routine' : 'Enable Routine'),
      );
    }

    if (_isOccurrenceLocked(task)) {
      final period = _occurrenceLabel(task);
      final statusLabel = task.done || _normalizedStatus(task) == 'completed' ? 'completed' : task.status.toLowerCase();
      return showDialog<Task>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already updated'),
          content: Text('This recurring task was already $statusLabel for $period. You can update it again in the next occurrence. You can still enable or disable this routine without deleting its history.'),
          actions: [
            toggleButton(context),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    }

    return showDialog<Task>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${task.task} status'),
        content: const Text('Recurring tasks keep their details fixed. Update this occurrence status, or disable the routine to stop active tracking while keeping history.'),
        actions: [
          toggleButton(context),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: task.routineEnabled
                ? () => Navigator.of(context).pop(task.copyWith(done: false, status: 'Missed'))
                : null,
            child: const Text('Mark Missed'),
          ),
          ElevatedButton(
            onPressed: task.routineEnabled
                ? () => Navigator.of(context).pop(task.copyWith(done: true, status: 'Completed'))
                : null,
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
            onDelete: () => widget.hiveService.deleteTaskByReference(task),
          );

    if (updated != null) {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  Color _getBubbleColor(DateTime date, Map<String, int> summary, DateTime today) {
    final isPassed = date.isBefore(today);
    if (isPassed) {
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
                        final summary = _getCompletedSummaryForDate(date);
                        final isToday = isCurrentYear && date.day == now.day && date.month == now.month;

                        return BubbleWidget(
                          color: _getBubbleColor(date, summary, todayStart),
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