import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../services/hive_service.dart';
import '../models/task_model.dart';
import '../constants/colors.dart';
import '../utils/task_time_utils.dart';

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


  Future<void> _editTask(Task task, {int? index}) async {
    if (isRoutineTask(task)) {
      final action = await showRoutineOccurrenceDialog(context: context, task: task);
      if (action == null || action == RoutineOccurrenceAction.close) return;

      switch (action) {
        case RoutineOccurrenceAction.disableRoutine:
          await widget.hiveService.setRecurringTaskEnabledByReference(task, false);
          return;
        case RoutineOccurrenceAction.editDetails:
          final edited = await showTaskFormDialog(
            context,
            date: task.dueDate,
            initialTask: task,
            title: 'Edit Routine Details',
            actionLabel: 'Save Routine',
          );
          if (edited != null) {
            await widget.hiveService.updateRecurringTaskSeriesByReference(task, edited.copyWith(repeatTask: true));
          }
          return;
        case RoutineOccurrenceAction.missOccurrence:
          final updated = task.copyWith(done: false, status: 'Missed');
          await widget.hiveService.updateTaskByReference(task, updated);
          return;
        case RoutineOccurrenceAction.completeOccurrence:
          final updated = task.copyWith(done: true, status: 'Completed');
          await widget.hiveService.updateTaskByReference(task, updated);
          return;
        case RoutineOccurrenceAction.close:
          return;
      }
    }

    final updated = await showTaskFormDialog(
      context,
      date: _currentDay,
      initialTask: task,
      title: 'Update Task',
      actionLabel: 'Save Task',
      onDelete: () async {
        if (index != null) {
          await widget.hiveService.deleteTask(_currentDay, index);
        } else {
          await widget.hiveService.deleteTaskByReference(task);
        }
      },
    );

    if (updated == null) return;
    if (index != null) {
      await widget.hiveService.updateTask(_currentDay, index, updated);
    } else {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  Map<String, double> _calculateMatrix(List<Task> tasks) {
    final visibleTasks = tasks.where((task) => !task.repeatTask || task.routineEnabled).toList();
    int bothMinutes = 0;
    int importantOnlyMinutes = 0;
    int urgentOnlyMinutes = 0;
    int neitherMinutes = 0;

    for (final task in visibleTasks) {
      final minutes = taskRecordedMinutesForDay(task);
      if (minutes == 0) continue;
      if (task.urgent && task.important) {
        bothMinutes += minutes;
      } else if (task.urgent && !task.important) {
        urgentOnlyMinutes += minutes;
      } else if (!task.urgent && task.important) {
        importantOnlyMinutes += minutes;
      } else {
        neitherMinutes += minutes;
      }
    }

    final totalMinutes = bothMinutes + importantOnlyMinutes + urgentOnlyMinutes + neitherMinutes;
    final totalHours = totalMinutes / 60;
    final bothHours = bothMinutes / 60;
    final importantOnlyHours = importantOnlyMinutes / 60;
    final urgentOnlyHours = urgentOnlyMinutes / 60;
    final neitherHours = neitherMinutes / 60;
    final bothPoints = bothHours * 100;
    final importantOnlyPoints = importantOnlyHours * 80;
    final urgentOnlyPoints = urgentOnlyHours * 50;
    final neitherPoints = neitherHours * 10;
    final totalPoints = bothPoints + importantOnlyPoints + urgentOnlyPoints + neitherPoints;
    final productivityScore = (totalPoints / 1600) * 100;

    double percentage(int minutes) => totalMinutes == 0 ? 0 : minutes / totalMinutes * 100;

    return {
      'ui': percentage(bothMinutes),
      'ni': percentage(importantOnlyMinutes),
      'uu': percentage(urgentOnlyMinutes),
      'nu': percentage(neitherMinutes),
      'uiHours': bothHours,
      'niHours': importantOnlyHours,
      'uuHours': urgentOnlyHours,
      'nuHours': neitherHours,
      'uiPoints': bothPoints,
      'niPoints': importantOnlyPoints,
      'uuPoints': urgentOnlyPoints,
      'nuPoints': neitherPoints,
      'totalHours': totalHours,
      'totalPoints': totalPoints,
      'productivityScore': productivityScore.clamp(0, 100).toDouble(),
      'focusedHours': bothHours + importantOnlyHours + urgentOnlyHours,
      'distractionHours': neitherHours,
    };
  }

  String _productivityRating(double score) {
    if (score >= 90) return 'Elite 🌟';
    if (score >= 80) return 'Excellent 🏆';
    if (score >= 70) return 'Very Good 💪';
    if (score >= 60) return 'Good 👍';
    if (score >= 50) return 'Average 🙂';
    if (score >= 40) return 'Low ⚠️';
    return 'Poor ❌';
  }

  String _formatHours(double hours) {
    if (hours == 0) return '0 hrs';
    final wholeHours = hours.floor();
    final minutes = ((hours - wholeHours) * 60).round();
    if (wholeHours == 0) return '$minutes min';
    if (minutes == 0) return '$wholeHours hrs';
    return '$wholeHours hrs $minutes min';
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
    Widget cell({
      required String label,
      required String key,
      required Color color,
    }) {
      final hours = matrix['${key}Hours'] ?? 0;
      final percentage = matrix[key] ?? 0;
      final points = matrix['${key}Points'] ?? 0;
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: Colors.black54), color: color.withOpacity(0.08)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_formatHours(hours), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${percentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
            Text('${points.round()} pts', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      );
    }

    final productivityScore = matrix['productivityScore'] ?? 0;
    final totalPoints = matrix['totalPoints'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.black45), borderRadius: BorderRadius.circular(12), color: Colors.white),
      child: Column(
        children: [
          Text('Total hours recorded: ${matrix['totalHours']!.toStringAsFixed(1)}'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8F4FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Productivity Score: ${productivityScore.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('Rating: ${_productivityRating(productivityScore)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('Total Points: ${totalPoints.round()} / 1600'),
                Text('Focused Hours: ${_formatHours(matrix['focusedHours'] ?? 0)}'),
                Text('Distraction Hours: ${_formatHours(matrix['distractionHours'] ?? 0)}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Daily Productivity Matrix (by completed time, % and points)'),
          const SizedBox(height: 6),
          SizedBox(
            height: 190,
            child: Row(
              children: [
                const RotatedBox(quarterTurns: 3, child: Text('Urgent')),
                Expanded(
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Expanded(child: Center(child: Text('Important: No', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
                          Expanded(child: Center(child: Text('Important: Yes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
                        ],
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: cell(label: 'Urgent Only\n50 pts/hr', key: 'uu', color: Colors.amber)),
                            Expanded(child: cell(label: 'Both\n100 pts/hr', key: 'ui', color: Colors.redAccent)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: cell(label: 'Neither\n10 pts/hr', key: 'nu', color: Colors.grey)),
                            Expanded(child: cell(label: 'Important Only\n80 pts/hr', key: 'ni', color: Colors.blueAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text('Not Important'), Text('Important')]),
          const SizedBox(height: 6),
          Text(
            'Ideal target: Both 6–8 hrs • Important only 3–5 hrs • Urgent only 1–2 hrs • Neither ≤1 hr',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _todayTasksPanel(List<Task> tasks) {
    final visibleTasks = tasks.where((task) => !task.repeatTask || task.routineEnabled).toList();

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
              child: visibleTasks.isEmpty
                  ? const Center(child: Text('Nothing for Today, Great Job !'))
                  : ListView.separated(
                      itemCount: visibleTasks.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = visibleTasks[index];
                        return ListTile(
                          dense: true,
                          onTap: () => _editTask(task),
                          title: Text(task.task),
                          subtitle: Text('${task.priority} • ${task.status} • ${taskPlannedMinutes(task)} min'),
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
