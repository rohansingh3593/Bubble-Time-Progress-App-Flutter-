import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../services/hive_service.dart';
import '../models/task_model.dart';
import '../constants/colors.dart';
import '../utils/task_time_utils.dart';
import 'journal_view.dart';

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



  void _openJournalForTask(Task task) {
    Navigator.of(context).push(
      JournalView.route(hiveService: widget.hiveService, initialDate: task.dueDate),
    );
  }

  Future<void> _editTask(Task task, {int? index}) async {
    if (isRoutineTask(task)) {
      final action = await showRoutineOccurrenceDialog(context: context, task: task, hiveService: widget.hiveService);
      if (action == null || action == RoutineOccurrenceAction.close) return;

      switch (action) {
        case RoutineOccurrenceAction.openJournal:
          _openJournalForTask(task);
          return;
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
    final productivityScore = matrix['productivityScore'] ?? 0;
    final totalPoints = matrix['totalPoints'] ?? 0;
    final focusedHours = matrix['focusedHours'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: matrix['totalHours'] ?? 0.0),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                'Total hours recorded: ${value.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _matrixSummaryCard(width: cardWidth, emoji: '📈', label: 'Score', value: productivityScore, suffix: '%', decimals: 0, color: const Color(0xFF8E8CFF)),
                  _matrixSummaryTextCard(width: cardWidth, emoji: '💪', label: 'Rating', value: _productivityRating(productivityScore), color: const Color(0xFF7E57C2)),
                  _matrixSummaryCard(width: cardWidth, emoji: '⭐', label: 'Points', value: totalPoints, suffix: ' / 1600', decimals: 0, color: const Color(0xFFFF9800)),
                  _matrixSummaryCard(width: cardWidth, emoji: '🎯', label: 'Focus', value: focusedHours, suffix: ' hrs', decimals: 1, color: const Color(0xFF2196F3)),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Text('Daily Productivity Matrix', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text('Completed time, percentage share, and points by urgency/importance.', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final cardWidth = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _matrixQuadrantCard(width: cardWidth, emoji: '🔥', title: 'Both', rate: '100 pts/hr', keyPrefix: 'ui', color: const Color(0xFFE91E63), matrix: matrix),
                  _matrixQuadrantCard(width: cardWidth, emoji: '💙', title: 'Important Only', rate: '80 pts/hr', keyPrefix: 'ni', color: const Color(0xFF2196F3), matrix: matrix),
                  _matrixQuadrantCard(width: cardWidth, emoji: '⚡', title: 'Urgent Only', rate: '50 pts/hr', keyPrefix: 'uu', color: const Color(0xFFFFC107), matrix: matrix),
                  _matrixQuadrantCard(width: cardWidth, emoji: '🌫️', title: 'Neither', rate: '10 pts/hr', keyPrefix: 'nu', color: const Color(0xFF9E9E9E), matrix: matrix),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8E8CFF).withOpacity(0.22)),
            ),
            child: Text(
              _matrixInsight(matrix),
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF263238)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _matrixSummaryCard({
    required double width,
    required String emoji,
    required String label,
    required double value,
    required String suffix,
    required int decimals,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: value),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$emoji  $label', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 7),
              Text('${animatedValue.toStringAsFixed(decimals)}$suffix', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _matrixSummaryTextCard({
    required double width,
    required String emoji,
    required String label,
    required String value,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$emoji  $label', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 7),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
          ],
        ),
      ),
    );
  }

  Widget _matrixQuadrantCard({
    required double width,
    required String emoji,
    required String title,
    required String rate,
    required String keyPrefix,
    required Color color,
    required Map<String, double> matrix,
  }) {
    final hours = matrix['${keyPrefix}Hours'] ?? 0;
    final percentage = matrix[keyPrefix] ?? 0;
    final points = matrix['${keyPrefix}Points'] ?? 0;
    return SizedBox(
      width: width,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => Opacity(
          opacity: progress,
          child: Transform.translate(offset: Offset(0, 10 * (1 - progress)), child: child),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.18), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.28)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                ],
              ),
              const SizedBox(height: 10),
              Text(rate, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _animatedSmallMetric(label: 'Hours', value: hours, suffix: 'h', decimals: 1)),
                  Expanded(child: _animatedSmallMetric(label: 'Share', value: percentage, suffix: '%', decimals: 0)),
                  Expanded(child: _animatedSmallMetric(label: 'Points', value: points, suffix: ' pts', decimals: 0)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animatedSmallMetric({required String label, required double value, required String suffix, required int decimals}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${animatedValue.toStringAsFixed(decimals)}$suffix', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _matrixInsight(Map<String, double> matrix) {
    final neitherHours = matrix['nuHours'] ?? 0;
    final importantOnlyHours = matrix['niHours'] ?? 0;
    final bothHours = matrix['uiHours'] ?? 0;
    final urgentOnlyHours = matrix['uuHours'] ?? 0;
    if (neitherHours > 1) return 'Tip: Keep Neither below 1 hour and move low-value work into focused blocks.';
    if (importantOnlyHours < 3 && bothHours < 6) return 'Tip: Increase Important Only work and keep Neither below 1 hour.';
    if (urgentOnlyHours > bothHours + importantOnlyHours) return 'Tip: Reduce urgent-only firefighting by planning important work earlier.';
    return 'Tip: Great balance — protect deep work and keep low-value tasks capped.';
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
                          subtitle: Text(_taskSubtitle(task)),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }


  String _taskSubtitle(Task task) {
    final phases = parseTaskPhases(task.description);
    if (!task.repeatTask && phases.isNotEmpty) {
      final completed = phases.where((phase) => phase.isCompleted).length;
      TaskPhaseInfo? nextPhase;
      for (final phase in phases) {
        if (!phase.isCompleted && phase.status.toLowerCase() != 'cancelled') {
          nextPhase = phase;
          break;
        }
      }
      final nextLabel = nextPhase == null
          ? 'All phases complete'
          : 'Next: ${nextPhase.name.isEmpty ? 'Phase' : nextPhase.name} • ${nextPhase.minutes} min';
      return '$completed/${phases.length} phases • $nextLabel';
    }
    return '${task.priority} • ${task.status} • ${taskPlannedMinutes(task)} min';
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
