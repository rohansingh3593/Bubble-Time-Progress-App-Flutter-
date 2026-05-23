import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../services/hive_service.dart';
import '../models/task_model.dart';
import '../constants/colors.dart';

class DayView extends StatefulWidget {
  final HiveService hiveService;

  const DayView({super.key, required this.hiveService});

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late DateTime _currentDay;
  bool _showTodayTasks = true;
  bool? _happyWithDay;
  final TextEditingController _reflectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentDay = DateTime.now();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Color _getBubbleColor(int hour, bool isToday, bool isPastDay, List<Task> tasksInHour, int currentHour) {
    if (isToday && hour == currentHour) return Colors.orange;
    if (isPastDay || (isToday && hour < currentHour)) return AppColors.passed;

    final completed = tasksInHour.where((task) => task.status == 'Completed').length;
    if (tasksInHour.isNotEmpty && completed == tasksInHour.length) return AppColors.taskCompleted;
    if (tasksInHour.isNotEmpty) return AppColors.taskPending;
    return AppColors.taskNone;
  }


  Future<void> _openHourTaskDialog(int hour) async {
    final task = await showTaskFormDialog(
      context,
      date: _currentDay,
      initialHourSlot: hour,
      title: 'Add Task for ${_formatHour(hour)}',
      actionLabel: 'Save Task',
    );

    if (task != null) {
      await widget.hiveService.addTask(_currentDay, task);
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
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

  Future<void> _editTask(Task task, {int? index}) async {
    final updated = _isRecurringTask(task)
        ? await _showRecurringStatusUpdateDialog(task)
        : await showTaskFormDialog(
            context,
            date: _currentDay,
            initialTask: task,
            title: 'Update Task',
            actionLabel: 'Save Task',
          );

    if (updated == null) return;
    if (index != null) {
      await widget.hiveService.updateTask(_currentDay, index, updated);
    } else {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  Map<String, double> _calculateMatrix(List<Task> tasks) {
    final totalMinutes = tasks.fold<int>(0, (sum, task) => sum + task.estimatedMinutes);
    if (totalMinutes == 0) {
      return {'uu': 0, 'ui': 0, 'nu': 0, 'ni': 0, 'totalHours': 0};
    }

    int uu = 0, ui = 0, nu = 0, ni = 0;
    for (final task in tasks) {
      if (task.urgent && task.important) {
        ui += task.estimatedMinutes;
      } else if (task.urgent && !task.important) {
        uu += task.estimatedMinutes;
      } else if (!task.urgent && task.important) {
        ni += task.estimatedMinutes;
      } else {
        nu += task.estimatedMinutes;
      }
    }

    return {
      'uu': uu / totalMinutes * 100,
      'ui': ui / totalMinutes * 100,
      'nu': nu / totalMinutes * 100,
      'ni': ni / totalMinutes * 100,
      'totalHours': totalMinutes / 60,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final isToday = _currentDay.year == now.year && _currentDay.month == now.month && _currentDay.day == now.day;
    final isPastDay = _currentDay.isBefore(todayStart);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _currentDay = _currentDay.subtract(const Duration(days: 1)));
              },
            ),
            Text('${_currentDay.month}/${_currentDay.day}/${_currentDay.year}'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() => _currentDay = _currentDay.add(const Duration(days: 1)));
              },
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final todayTasks = widget.hiveService.getTasksForDate(_currentDay);
          final matrix = _calculateMatrix(todayTasks);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: 24,
                  itemBuilder: (context, index) {
                    final hour = index;
                    final isCurrentHour = isToday && hour == now.hour;
                    final tasksInHour = todayTasks.where((task) => task.hourSlot == hour).toList();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: BubbleWidget(
                            color: _getBubbleColor(hour, isToday, isPastDay, tasksInHour, now.hour),
                            isHighlighted: isCurrentHour,
                            onTap: () => _openHourTaskDialog(hour),
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
                const SizedBox(height: 10),
                _metricsPanel(matrix),
                const SizedBox(height: 10),
                _todayTasksPanel(todayTasks),
                const SizedBox(height: 10),
                _reflectionPanel(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: SafeArea(
        child: FloatingActionButton(
          onPressed: () async {
            await showQuickAddTaskDialog(context, _currentDay, widget.hiveService);
          },
          tooltip: 'Add task',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _metricsPanel(Map<String, double> matrix) {
    Widget cell(String value) => Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: Colors.black54)),
          child: Text('${value}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.black45), borderRadius: BorderRadius.circular(12), color: Colors.white),
      child: Column(
        children: [
          Text('Total hours recorded: ${matrix['totalHours']!.toStringAsFixed(1)}'),
          const SizedBox(height: 6),
          const Text('Daily Productivity Matrix (by time %)'),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: Row(
              children: [
                const RotatedBox(quarterTurns: 3, child: Text('Urgent')),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [Expanded(child: cell(matrix['uu']!.toStringAsFixed(0))), Expanded(child: cell(matrix['ui']!.toStringAsFixed(0)))],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [Expanded(child: cell(matrix['nu']!.toStringAsFixed(0))), Expanded(child: cell(matrix['ni']!.toStringAsFixed(0)))],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text('Not Important'), Text('Important')]),
        ],
      ),
    );
  }

  Widget _todayTasksPanel(List<Task> tasks) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFECE8E6), border: Border.all(color: Colors.black38), borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            onTap: () => setState(() => _showTodayTasks = !_showTodayTasks),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFFAED9AE), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Expanded(child: Text("TODAY'S TASKS", textAlign: TextAlign.center, style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600))),
                  Icon(_showTodayTasks ? Icons.expand_more : Icons.chevron_right, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          if (_showTodayTasks) ...[
            Container(width: double.infinity, color: const Color(0xFFE8C1A0), padding: const EdgeInsets.symmetric(vertical: 4), child: const Text('TASK', textAlign: TextAlign.center, style: TextStyle(letterSpacing: 3))),
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
                          onTap: () => _editTask(task, index: index),
                          title: Text(task.task),
                          subtitle: Text('${task.priority} • ${task.status} • ${task.estimatedMinutes} min'),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reflectionPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.black38), borderRadius: BorderRadius.circular(12), color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Do I feel happy with my day?', style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(child: RadioListTile<bool>(value: true, groupValue: _happyWithDay, title: const Text('Yes'), dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => _happyWithDay = v))),
              Expanded(child: RadioListTile<bool>(value: false, groupValue: _happyWithDay, title: const Text('No'), dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => _happyWithDay = v))),
            ],
          ),
          TextField(
            controller: _reflectionController,
            decoration: const InputDecoration(labelText: 'Why do you feel this way? (Optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 6),
          Text(
            _happyWithDay == true
                ? 'Advice: Keep this momentum and continue important work.'
                : _happyWithDay == false
                    ? 'Advice: Reduce time waste and plan focused time blocks.'
                    : 'Advice: Reflect at end of day for better insights.',
          ),
          const SizedBox(height: 4),
          Text(
            'Tip: You can log waste reasons (e.g., YouTube) and waste hours in future enhancement.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
