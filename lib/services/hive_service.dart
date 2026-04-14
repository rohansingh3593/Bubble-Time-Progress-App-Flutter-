import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';

class HiveService {
  HiveService._privateConstructor();
  static final HiveService instance = HiveService._privateConstructor();

  static const _boxName = 'tasksBox';
  late Box<List> _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskAdapter());
    }

    _box = await Hive.openBox<List>(_boxName);
  }

  String _formatKey(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  List<Task> getTasksForDate(DateTime date) {
    final key = _formatKey(date);
    final rawList = _box.get(key);
    if (rawList == null) return [];
    return rawList.cast<Task>().toList();
  }

  Future<void> addTask(DateTime date, Task task) async {
    final key = _formatKey(date);
    final tasks = getTasksForDate(date);
    tasks.add(task);
    await _box.put(key, tasks);
  }

  Future<void> updateTask(DateTime date, int index, Task task) async {
    final key = _formatKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;

    final previous = tasks[index];
    tasks[index] = task;
    await _box.put(key, tasks);

    await _handleRecurringIfNeeded(previous: previous, updated: task);
  }

  Future<void> deleteTask(DateTime date, int index) async {
    final key = _formatKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;
    tasks.removeAt(index);
    await _box.put(key, tasks);
  }

  Future<void> toggleTaskStatus(DateTime date, int index) async {
    final key = _formatKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;

    final currentTask = tasks[index];
    final nextDone = !currentTask.done;
    final updatedTask = currentTask.copyWith(
      done: nextDone,
      status: nextDone ? 'Completed' : 'In Progress',
    );

    tasks[index] = updatedTask;
    await _box.put(key, tasks);

    await _handleRecurringIfNeeded(previous: currentTask, updated: updatedTask);
  }

  Future<void> _handleRecurringIfNeeded({
    required Task previous,
    required Task updated,
  }) async {
    if (!updated.repeatTask) return;

    final didBecomeTerminal =
        !_isTerminalStatus(previous.status) && _isTerminalStatus(updated.status);

    if (!didBecomeTerminal) return;

    final nextDueDate = _computeNextDueDate(updated.dueDate, updated.repeatFrequency);
    if (nextDueDate == null) return;

    final nextKey = _formatKey(nextDueDate);
    final nextDateTasks = getTasksForDate(nextDueDate);

    final alreadyExists = nextDateTasks.any(
      (task) =>
          task.task == updated.task &&
          _isSameDate(task.dueDate, nextDueDate) &&
          task.repeatTask == true &&
          task.repeatFrequency == updated.repeatFrequency,
    );

    if (alreadyExists) return;

    nextDateTasks.add(
      updated.copyWith(
        dueDate: nextDueDate,
        done: false,
        status: 'Not Started',
      ),
    );

    await _box.put(nextKey, nextDateTasks);
  }

  bool _isTerminalStatus(String status) {
    return status == 'Completed' || status == 'Cancelled';
  }

  DateTime? _computeNextDueDate(DateTime dueDate, String? repeatFrequency) {
    switch (repeatFrequency) {
      case 'Daily':
        return dueDate.add(const Duration(days: 1));
      case 'Weekly':
        return dueDate.add(const Duration(days: 7));
      case 'Monthly':
        return DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
      case 'Yearly':
        return DateTime(dueDate.year + 1, dueDate.month, dueDate.day);
      default:
        return null;
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Map<String, int> getTaskSummaryForDate(DateTime date) {
    final tasks = getTasksForDate(date);
    final completed = tasks.where((task) => task.done).length;
    return {
      'completed': completed,
      'pending': tasks.length - completed,
    };
  }

  Map<DateTime, List<Task>> getAllTasksByDate() {
    final result = <DateTime, List<Task>>{};

    for (final key in _box.keys) {
      if (key is! String) continue;

      final parsedDate = DateTime.tryParse(key);
      if (parsedDate == null) continue;

      final tasks = _box.get(key);
      if (tasks == null) continue;

      result[DateTime(parsedDate.year, parsedDate.month, parsedDate.day)] =
          tasks.cast<Task>().toList();
    }

    return result;
  }

  /// Returns a ValueListenable that rebuilds when the box changes
  ValueListenable<Box<List>> getBoxListenable() {
    return _box.listenable();
  }
}
