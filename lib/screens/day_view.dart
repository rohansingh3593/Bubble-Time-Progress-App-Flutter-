import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/routine_occurrence_dialog.dart';
import '../widgets/period_progress_bubble_map.dart';
import '../services/hive_service.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';
import '../constants/colors.dart';
import '../constants/dashboard_themes.dart';
import '../utils/task_time_utils.dart';
import 'journal_view.dart';
import '../utils/text_formatters.dart';

class DayView extends StatefulWidget {
  final HiveService hiveService;

  const DayView({super.key, required this.hiveService});

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> with SingleTickerProviderStateMixin {
  late DateTime _currentDay;
  bool _showTodayTasks = true;
  late final AnimationController _schedulePulseController;
  Timer? _scheduleClockTimer;
  DateTime _scheduleNow = DateTime.now();

  static const int _scheduleSnapMinutes = 15;
  static const int _defaultScheduledDurationMinutes = 15;
  static const List<int> _scheduleDurationSteps = [15, 30, 45, 60, 75, 90, 105, 120];

  @override
  void initState() {
    super.initState();
    _currentDay = DateTime.now();
    _schedulePulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _scheduleClockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _scheduleNow = DateTime.now());
    });
  }

  @override
  void dispose() {
    _scheduleClockTimer?.cancel();
    _schedulePulseController.dispose();
    super.dispose();
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

  void _openJournalForDate(DateTime date) {
    Navigator.of(context).push(
      JournalView.route(hiveService: widget.hiveService, initialDate: date),
    );
  }

  Future<void> _editTask(Task task, {int? index}) async {
    if (isRoutineTask(task) || hasTaskLinkedInstructions(widget.hiveService, task)) {
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
            title: isRoutineTask(task) ? 'Edit Routine Details' : 'View Task Details',
            actionLabel: isRoutineTask(task) ? 'Save Routine' : 'Save Task',
          );
          if (edited != null) {
            if (isRoutineTask(task)) {
              await widget.hiveService.updateRecurringTaskSeriesByReference(task, edited.copyWith(repeatTask: true));
            } else {
              await widget.hiveService.updateTaskByReference(task, edited);
            }
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

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _taskOccurrenceKey(Task task) {
    return '${task.task.trim().toLowerCase()}|${task.category.trim().toLowerCase()}|${task.repeatFrequency?.trim().toLowerCase() ?? ''}';
  }

  bool _routineOccursOnDay(Task task, DateTime day) {
    if (!task.repeatTask || !task.routineEnabled) return false;
    final start = _dateOnly(task.dueDate);
    if (day.isBefore(start)) return false;
    switch (task.repeatFrequency?.trim().toLowerCase()) {
      case 'daily':
        return true;
      case 'weekly':
        return day.weekday == start.weekday;
      case 'monthly':
        return day.day == start.day;
      case 'yearly':
        return day.month == start.month && day.day == start.day;
      default:
        return _sameDate(day, start);
    }
  }

  List<Task> _tasksForCurrentDay() {
    final selectedDay = _dateOnly(_currentDay);
    final tasks = widget.hiveService.getTasksForDate(selectedDay).toList();
    final existingKeys = tasks.where((task) => task.repeatTask).map(_taskOccurrenceKey).toSet();
    final routineTemplates = widget.hiveService
        .getAllTasksByDate()
        .values
        .expand((items) => items)
        .where((task) => _routineOccursOnDay(task, selectedDay));

    for (final template in routineTemplates) {
      final key = _taskOccurrenceKey(template);
      if (existingKeys.contains(key)) continue;
      existingKeys.add(key);
      tasks.add(template.copyWith(
        done: false,
        status: 'Not Updated',
        dueDate: DateTime(selectedDay.year, selectedDay.month, selectedDay.day, template.dueDate.hour, template.dueDate.minute),
      ));
    }
    return tasks;
  }

  DashboardThemeStyle _selectedDashboardTheme() {
    return DashboardThemeStyle.of(
      widget.hiveService.getDashboardTheme(),
      palette: widget.hiveService.getDashboardPalette(),
    );
  }

  Widget _dayHourProgressMap(DashboardThemeStyle theme, DateTime now, bool isToday, bool isPastDay) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final selectedDayStart = DateTime(_currentDay.year, _currentDay.month, _currentDay.day);
    final isFutureDay = selectedDayStart.isAfter(todayStart);
    final passedHours = isPastDay ? 24 : isFutureDay ? 0 : now.hour.clamp(0, 24).toInt();
    final remainingHours = isPastDay ? 0 : isFutureDay ? 24 : (24 - passedHours - 1).clamp(0, 24).toInt();
    return PeriodProgressBubbleMap(
      theme: theme,
      title: 'Day Hour Progress',
      subtitle: '$passedHours hours passed • $remainingHours hours left',
      totalItems: 24,
      minBubbleSize: 42,
      maxBubbleSize: 56,
      passedItems: passedHours,
      currentIndex: isToday ? now.hour : null,
      itemsPerRow: 6,
      passedLabel: 'Passed',
      currentLabel: 'Now',
      remainingLabel: 'Remaining',
      tooltipBuilder: (index) => _formatHour(index),
      bubbleLabelBuilder: (index) => _formatHour(index).replaceFirst(' ', '\n'),
    );
  }

  List<_DayScheduleEntry> _buildDayScheduleEntries(List<Task> tasks) {
    final taskEntries = <_DayScheduleEntry>[];
    for (final task in tasks.where((task) => !task.repeatTask || task.routineEnabled)) {
      final range = _scheduleRangeForTask(task);
      if (range == null) continue;
      taskEntries.add(_DayScheduleEntry(startMinutes: range.start, endMinutes: range.end, task: task));
    }
    taskEntries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final entries = <_DayScheduleEntry>[];
    var cursor = 8 * 60;
    final dayEnd = taskEntries.isEmpty ? 18 * 60 : taskEntries.map((entry) => entry.endMinutes).reduce((a, b) => a > b ? a : b).clamp(18 * 60, 24 * 60).toInt();
    for (final entry in taskEntries) {
      if (entry.startMinutes > cursor) {
        entries.add(_DayScheduleEntry(startMinutes: cursor, endMinutes: entry.startMinutes));
      }
      entries.add(entry);
      if (entry.endMinutes > cursor) cursor = entry.endMinutes;
    }
    if (cursor < dayEnd) entries.add(_DayScheduleEntry(startMinutes: cursor, endMinutes: dayEnd));
    return entries;
  }

  _DayScheduleRange? _scheduleRangeForTask(Task task) {
    return _scheduleRangeFromDescription(task.description);
  }

  bool _isSchedulablePendingTask(Task task) {
    final status = task.status.trim().toLowerCase();
    return !task.done && status != 'completed' && status != 'missed' && status != 'cancelled' && (!task.repeatTask || task.routineEnabled);
  }

  bool _hasScheduleRange(Task task) => _scheduleRangeForTask(task) != null;

  _DayScheduleRange? _scheduleRangeFromDescription(String description) {
    int? start;
    int? end;
    for (final line in description.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('⏰ Schedule Start:')) {
        start = _parseScheduleMinutes(trimmed.substring('⏰ Schedule Start:'.length).trim());
      } else if (trimmed.startsWith('⏰ Schedule End:')) {
        end = _parseScheduleMinutes(trimmed.substring('⏰ Schedule End:'.length).trim());
      }
    }
    if (start == null || end == null) return null;
    if (end <= start) end = (start + 15).clamp(0, 24 * 60).toInt();
    return _DayScheduleRange(start: start, end: end);
  }

  String _mergeScheduleIntoDescription(String description, int startMinutes, int endMinutes) {
    final cleaned = description
        .split('\n')
        .where((line) {
          final trimmed = line.trim();
          return !trimmed.startsWith('⏰ Schedule Start:') &&
              !trimmed.startsWith('⏰ Schedule End:') &&
              !trimmed.startsWith('⏰ Schedule Bonus:') &&
              !trimmed.startsWith('⏰ Scheduled:');
        })
        .join('\n')
        .trim();
    final lines = <String>[
      if (cleaned.isNotEmpty) cleaned,
      '⏰ Schedule Start: ${_formatStorageTime(startMinutes)}',
      '⏰ Schedule End: ${_formatStorageTime(endMinutes)}',
      '⏰ Schedule Bonus: 20',
    ];
    return lines.join('\n');
  }

  String _formatStorageTime(int minutes) {
    final normalized = minutes.clamp(0, 24 * 60 - 1).toInt();
    return '${(normalized ~/ 60).toString().padLeft(2, '0')}:${(normalized % 60).toString().padLeft(2, '0')}';
  }

  int _snapMinutes(int minutes) {
    return (minutes / _scheduleSnapMinutes).round() * _scheduleSnapMinutes;
  }

  Future<void> _saveScheduledTask(Task task, int startMinutes, int endMinutes) async {
    final snappedStart = _snapMinutes(startMinutes).clamp(0, 24 * 60 - _scheduleSnapMinutes).toInt();
    final snappedEnd = _snapMinutes(endMinutes).clamp(snappedStart + _scheduleSnapMinutes, 24 * 60).toInt();
    final selectedDay = _dateOnly(_currentDay);
    final updated = task.copyWith(
      dueDate: DateTime(selectedDay.year, selectedDay.month, selectedDay.day, snappedStart ~/ 60, snappedStart % 60),
      estimatedMinutes: snappedEnd - snappedStart,
      description: _mergeScheduleIntoDescription(task.description, snappedStart, snappedEnd),
    );
    if (task.repeatTask) {
      await widget.hiveService.updateRecurringTaskSeriesByReference(task, updated.copyWith(repeatTask: true));
    } else {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  Future<void> _scheduleTaskAt(Task task, int startMinutes) {
    final duration = task.estimatedMinutes > 0 ? task.estimatedMinutes : _defaultScheduledDurationMinutes;
    return _saveScheduledTask(task, startMinutes, (startMinutes + duration).clamp(startMinutes + _scheduleSnapMinutes, 24 * 60).toInt());
  }

  Future<void> _resizeScheduledTask(Task task, int newDuration) {
    final range = _scheduleRangeForTask(task);
    if (range == null) return Future.value();
    return _saveScheduledTask(task, range.start, (range.start + newDuration).clamp(range.start + _scheduleSnapMinutes, 24 * 60).toInt());
  }

  Future<void> _returnTaskToPending(Task task) async {
    final cleaned = task.description
        .split('\n')
        .where((line) {
          final trimmed = line.trim();
          return !trimmed.startsWith('⏰ Schedule Start:') &&
              !trimmed.startsWith('⏰ Schedule End:') &&
              !trimmed.startsWith('⏰ Schedule Bonus:') &&
              !trimmed.startsWith('⏰ Scheduled:');
        })
        .join('\n')
        .trim();
    final selectedDay = _dateOnly(_currentDay);
    final updated = task.copyWith(
      description: cleaned,
      dueDate: DateTime(selectedDay.year, selectedDay.month, selectedDay.day),
    );
    if (task.repeatTask) {
      await widget.hiveService.updateRecurringTaskSeriesByReference(task, updated.copyWith(repeatTask: true));
    } else {
      await widget.hiveService.updateTaskByReference(task, updated);
    }
  }

  int? _parseScheduleMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  String _formatScheduleTime(int minutes) {
    final normalized = minutes.clamp(0, 24 * 60).toInt();
    final hour = (normalized ~/ 60) % 24;
    final minute = normalized % 60;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return minute == 0 ? '$displayHour $period' : '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  _DayScheduleStatus _scheduleStatusFor(Task task, _DayScheduleEntry entry) {
    final status = task.status.trim().toLowerCase();
    if (task.done || status == 'completed') return _DayScheduleStatus.completed;
    if (status == 'missed') return _DayScheduleStatus.missed;
    final selectedDay = _dateOnly(_currentDay);
    final today = _dateOnly(_scheduleNow);
    if (selectedDay.isBefore(today)) return _DayScheduleStatus.overdue;
    if (selectedDay.isAfter(today)) return _DayScheduleStatus.upcoming;
    final nowMinutes = _scheduleNow.hour * 60 + _scheduleNow.minute;
    if (nowMinutes >= entry.startMinutes && nowMinutes < entry.endMinutes) return _DayScheduleStatus.active;
    if (nowMinutes >= entry.endMinutes) return _DayScheduleStatus.overdue;
    return _DayScheduleStatus.upcoming;
  }

  Color _scheduleStatusColor(_DayScheduleStatus status, DashboardThemeStyle theme) {
    final appTheme = AppThemeColors.fromDashboardStyle(theme);
    switch (status) {
      case _DayScheduleStatus.completed:
        return appTheme.success;
      case _DayScheduleStatus.active:
        return appTheme.accent;
      case _DayScheduleStatus.overdue:
      case _DayScheduleStatus.missed:
        return appTheme.danger;
      case _DayScheduleStatus.upcoming:
        return appTheme.cardTint;
    }
  }

  String _scheduleStatusLabel(_DayScheduleStatus status) {
    switch (status) {
      case _DayScheduleStatus.completed:
        return 'Completed';
      case _DayScheduleStatus.active:
        return 'Active';
      case _DayScheduleStatus.overdue:
        return 'Overdue';
      case _DayScheduleStatus.upcoming:
        return 'Upcoming';
      case _DayScheduleStatus.missed:
        return 'Missed';
    }
  }

  List<_PositionedDayScheduleEntry> _positionOverlappingEntries(List<_DayScheduleEntry> entries) {
    final positioned = <_PositionedDayScheduleEntry>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final overlappingIndexes = <int>[];
      for (var j = 0; j < entries.length; j++) {
        final other = entries[j];
        if (entry.startMinutes < other.endMinutes && other.startMinutes < entry.endMinutes) {
          overlappingIndexes.add(j);
        }
      }
      final columnCount = overlappingIndexes.length.clamp(1, 4).toInt();
      final column = overlappingIndexes.indexOf(i).clamp(0, columnCount - 1).toInt();
      positioned.add(_PositionedDayScheduleEntry(entry: entry, column: column, columnCount: columnCount));
    }
    return positioned;
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
          final todayTasks = _tasksForCurrentDay();
          final matrix = _calculateMatrix(todayTasks);
          final selectedDashboardTheme = _selectedDashboardTheme();
          final journalEntry = widget.hiveService.getJournalEntryForDate(_currentDay);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
            child: Column(
              children: [
                _dayHourProgressMap(selectedDashboardTheme, now, isToday, isPastDay),
                const SizedBox(height: 10),
                _metricsPanel(matrix),
                const SizedBox(height: 10),
                _todaySchedulePanel(todayTasks, selectedDashboardTheme),
                const SizedBox(height: 10),
                _todayTasksPanel(todayTasks, selectedDashboardTheme),
                const SizedBox(height: 10),
                _journalReflectionPanel(selectedDashboardTheme, journalEntry),
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

  Widget _todaySchedulePanel(List<Task> tasks, DashboardThemeStyle theme) {
    final entries = _buildDayScheduleEntries(tasks);
    final positionedEntries = _positionOverlappingEntries(entries.where((entry) => entry.task != null).toList());
    final unscheduledTasks = tasks.where((task) => _isSchedulablePendingTask(task) && !_hasScheduleRange(task)).toList();
    final visibleTasks = tasks.where((task) => !task.repeatTask || task.routineEnabled).toList();
    final completed = visibleTasks.where((task) => task.done || task.status.trim().toLowerCase() == 'completed').length;
    final completionRate = visibleTasks.isEmpty ? 0 : ((completed / visibleTasks.length) * 100).round();
    const hourHeight = 72.0;
    const labelWidth = 58.0;
    const timelineHeight = hourHeight * 24;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.primary.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: theme.primary.withOpacity(theme.dark ? 0.16 : 0.08), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Today Schedule', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900))),
              Text('${_currentDay.month}/${_currentDay.day}/${_currentDay.year}', style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$completionRate% Complete', style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _unscheduledTaskPlanner(theme, unscheduledTasks),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final laneAreaWidth = constraints.maxWidth - labelWidth;
              return DragTarget<Task>(
                onAcceptWithDetails: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(details.offset);
                  final minutes = ((local.dy / hourHeight) * 60).clamp(0, 24 * 60 - _scheduleSnapMinutes).toInt();
                  _scheduleTaskAt(details.data, minutes);
                },
                builder: (context, candidateData, rejectedData) {
                  final preview = candidateData.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: preview ? theme.primary.withOpacity(0.06) : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: preview ? Border.all(color: theme.primary.withOpacity(0.28)) : null,
                    ),
                    child: SizedBox(
                      height: timelineHeight,
                      child: Stack(
                        children: [
                          for (var hour = 0; hour < 24; hour++)
                            Positioned(
                              top: hour * hourHeight,
                              left: 0,
                              right: 0,
                              height: hourHeight,
                              child: InkWell(
                                onTap: () => showTaskFormDialog(context, date: _currentDay, initialHourSlot: hour),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: labelWidth, child: Text(_formatScheduleTime(hour * 60), style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w800))),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.textMuted.withOpacity(0.35)))),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_sameDate(_currentDay, _scheduleNow))
                            Positioned(
                              top: ((_scheduleNow.hour * 60 + _scheduleNow.minute) / 60) * hourHeight,
                              left: labelWidth,
                              right: 0,
                              child: Container(height: 2, color: AppThemeColors.fromDashboardStyle(theme).accent),
                            ),
                          for (final positioned in positionedEntries)
                            Positioned(
                              top: (positioned.entry.startMinutes / 60) * hourHeight,
                              left: labelWidth + positioned.column * ((laneAreaWidth - ((positioned.columnCount - 1) * 6)) / positioned.columnCount + 6),
                              width: (laneAreaWidth - ((positioned.columnCount - 1) * 6)) / positioned.columnCount,
                              height: ((positioned.entry.endMinutes - positioned.entry.startMinutes) / 60 * hourHeight).clamp(36.0, timelineHeight),
                              child: _taskScheduleTile(theme, positioned.entry, compact: positioned.columnCount > 2 || (positioned.entry.endMinutes - positioned.entry.startMinutes) <= 75),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _unscheduledTaskPlanner(DashboardThemeStyle theme, List<Task> tasks) {
    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        if (_hasScheduleRange(details.data)) _returnTaskToPending(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final returning = candidateData.whereType<Task>().any(_hasScheduleRange);
        return Container(
          width: double.infinity,
          padding: returning ? const EdgeInsets.all(10) : EdgeInsets.zero,
          decoration: returning
              ? BoxDecoration(
                  color: theme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.primary.withOpacity(0.30)),
                )
              : null,
          child: tasks.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (theme.cardTint ?? theme.elevatedSurface).withOpacity(0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.primary.withOpacity(0.16)),
                  ),
                  child: Text(
                    returning ? 'Drop here to return this task to Pending Tasks.' : 'All pending tasks with schedule times are placed below.',
                    style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w800),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Tasks (Not Scheduled)', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tasks.map((task) => _draggablePendingTaskCard(theme, task)).toList(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _draggablePendingTaskCard(DashboardThemeStyle theme, Task task) {
    final instructionCount = widget.hiveService.getInstructions().where((instruction) => instruction.enabled && instruction.isLinkedToTask(task.task.trim())).length;
    final duration = task.estimatedMinutes > 0 ? task.estimatedMinutes : _defaultScheduledDurationMinutes;
    final card = Container(
      width: 170,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (theme.cardTint ?? theme.elevatedSurface).withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withOpacity(0.34), style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(toTitleCase(task.task), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${task.category} • ${task.priority}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700, fontSize: 12)),
          Text('Instructions: $instructionCount', style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700, fontSize: 12)),
          Text('$duration min', style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
    return Draggable<Task>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.88, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _taskScheduleTile(DashboardThemeStyle theme, _DayScheduleEntry entry, {bool compact = false}) {
    final task = entry.task!;
    final status = _scheduleStatusFor(task, entry);
    final color = _scheduleStatusColor(status, theme);
    final active = status == _DayScheduleStatus.active;

    final tile = AnimatedBuilder(
      animation: _schedulePulseController,
      builder: (context, child) {
        final pulse = active ? 0.35 + (_schedulePulseController.value * 0.35) : 0.20;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editTask(task),
          child: Container(
            padding: EdgeInsets.all(compact ? 4 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(active ? 0.28 : status == _DayScheduleStatus.missed ? 0.10 : 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(active ? pulse : 0.36), width: active ? 2 : 1),
              boxShadow: active ? [BoxShadow(color: color.withOpacity(pulse), blurRadius: 18, spreadRadius: 1)] : null,
            ),
            child: child,
          ),
        );
      },
      child: compact
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    '${toTitleCase(task.task)} • ${_scheduleStatusLabel(status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) SizedBox(width: 72, child: Text(_formatScheduleTime(entry.startMinutes), style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w900))),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (active)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                    child: Text('Active Now', style: TextStyle(color: AppThemeColors.readableTextOn(color, theme), fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                Text(toTitleCase(task.task), style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900)),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text('${_formatScheduleTime(entry.startMinutes)} - ${_formatScheduleTime(entry.endMinutes)}', style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                ],
                Text(_scheduleStatusLabel(status), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                if ((entry.endMinutes - entry.startMinutes) >= 120) ...[
                  const SizedBox(height: 4),
                  _durationResizeControls(theme, task, entry),
                ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Draggable<Task>(
      data: task,
      feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.88, child: SizedBox(width: 180, child: tile))),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }

  Widget _durationResizeControls(DashboardThemeStyle theme, Task task, _DayScheduleEntry entry) {
    final duration = entry.endMinutes - entry.startMinutes;
    final currentIndex = _scheduleDurationSteps.indexWhere((value) => value >= duration);
    final resolvedIndex = currentIndex == -1 ? _scheduleDurationSteps.length - 1 : currentIndex;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: resolvedIndex <= 0 ? null : () => _resizeScheduledTask(task, _scheduleDurationSteps[resolvedIndex - 1]),
          child: Icon(Icons.remove_circle_outline, size: 18, color: resolvedIndex <= 0 ? theme.textMuted.withOpacity(0.45) : theme.primary),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('$duration min', style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
        InkWell(
          onTap: resolvedIndex >= _scheduleDurationSteps.length - 1 ? null : () => _resizeScheduledTask(task, _scheduleDurationSteps[resolvedIndex + 1]),
          child: Icon(Icons.add_circle_outline, size: 18, color: resolvedIndex >= _scheduleDurationSteps.length - 1 ? theme.textMuted.withOpacity(0.45) : theme.primary),
        ),
      ],
    );
  }

  Widget _freeScheduleTile(DashboardThemeStyle theme, int start, int end) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showQuickAddTaskDialog(context, _currentDay, widget.hiveService),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.elevatedSurface.withOpacity(0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.textMuted.withOpacity(0.16)),
        ),
        child: Row(
          children: [
            SizedBox(width: 72, child: Text(_formatScheduleTime(start), style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w800))),
            Expanded(child: Text('${_formatScheduleTime(start)} - ${_formatScheduleTime(end)}\nFree Time', style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w800))),
            Icon(Icons.add_circle_outline, color: theme.primary),
          ],
        ),
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

  Widget _todayTasksPanel(List<Task> tasks, DashboardThemeStyle theme) {
    final visibleTasks = tasks.where((task) => !task.repeatTask || task.routineEnabled).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.primary.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: theme.primary.withOpacity(theme.dark ? 0.16 : 0.08), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            onTap: () => setState(() => _showTodayTasks = !_showTodayTasks),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(theme.dark ? 0.34 : 0.18),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "TODAY'S TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary, letterSpacing: 4, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(_showTodayTasks ? Icons.expand_more : Icons.chevron_right, color: theme.primary),
                ],
              ),
            ),
          ),
          if (_showTodayTasks) ...[
            Container(
              width: double.infinity,
              color: theme.cardTint?.withOpacity(0.55) ?? theme.elevatedSurface,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('TASK', textAlign: TextAlign.center, style: TextStyle(color: theme.textPrimary, letterSpacing: 3, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              height: 170,
              child: visibleTasks.isEmpty
                  ? Center(child: Text('Nothing for Today, Great Job !', style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700)))
                  : ListView.separated(
                      itemCount: visibleTasks.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: theme.primary.withOpacity(0.14)),
                      itemBuilder: (context, index) {
                        final task = visibleTasks[index];
                        return ListTile(
                          dense: true,
                          onTap: () => _editTask(task),
                          title: Text(toTitleCase(task.task), style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
                          subtitle: Text(_taskSubtitle(task), style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w600)),
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

  Widget _journalReflectionPanel(DashboardThemeStyle theme, JournalEntry? entry) {
    final hasEntry = entry != null && entry.reflection.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.primary.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: theme.primary.withOpacity(theme.dark ? 0.16 : 0.08), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: theme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Journal & Reflection',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasEntry ? 'Saved mood: ${entry.mood}' : 'No reflection saved for this day yet.',
            style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700),
          ),
          if (hasEntry) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (theme.cardTint ?? theme.elevatedSurface).withOpacity(theme.dark ? 0.34 : 0.58),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.primary.withOpacity(0.14)),
              ),
              child: Text(
                entry.reflection,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700, height: 1.25),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openJournalForDate(_currentDay),
              icon: Icon(hasEntry ? Icons.auto_stories_rounded : Icons.edit_note_rounded),
              label: Text(hasEntry ? 'Open Journal & Reflection' : 'Write Journal & Reflection'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DayScheduleStatus {
  completed,
  active,
  overdue,
  upcoming,
  missed;
}

class _DayScheduleRange {
  final int start;
  final int end;

  const _DayScheduleRange({required this.start, required this.end});
}

class _DayScheduleEntry {
  final int startMinutes;
  final int endMinutes;
  final Task? task;

  const _DayScheduleEntry({
    required this.startMinutes,
    required this.endMinutes,
    this.task,
  });
}

class _PositionedDayScheduleEntry {
  final _DayScheduleEntry entry;
  final int column;
  final int columnCount;

  const _PositionedDayScheduleEntry({
    required this.entry,
    required this.column,
    required this.columnCount,
  });
}
