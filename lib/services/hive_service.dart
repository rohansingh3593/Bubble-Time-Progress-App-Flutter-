import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../utils/date_utils.dart';

class HiveService {
  HiveService._privateConstructor();
  static final HiveService instance = HiveService._privateConstructor();

  static const _boxName = 'tasks';
  late Box<List> _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskAdapter());
    }

    _box = await Hive.openBox<List>(_boxName);
  }

  /// Gets a date key in UTC format (yyyy-MM-dd) with zeroed time.
  String _getDateKey(DateTime date) {
    return toDateKeyUtc(date);
  }

  /// Retrieves all tasks for a given date.
  List<Task> getTasksForDate(DateTime date) {
    final key = _getDateKey(date);
    final rawList = _box.get(key);
    if (rawList == null) return [];
    return rawList.cast<Task>().toList();
  }

  /// Adds a new task for the given date.
  Future<void> addTask(DateTime date, Task task) async {
    final key = _getDateKey(date);
    final tasks = getTasksForDate(date);
    tasks.add(task);
    await _box.put(key, tasks);
  }

  /// Updates an existing task by index for the given date.
  Future<void> updateTask(DateTime date, int index, Task updated) async {
    final key = _getDateKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;
    tasks[index] = updated;
    await _box.put(key, tasks);
  }

  /// Deletes a task by index for the given date.
  Future<void> deleteTask(DateTime date, int index) async {
    final key = _getDateKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;
    tasks.removeAt(index);
    await _box.put(key, tasks);
  }

  /// Toggles the completion status of a task by index for the given date.
  Future<void> toggleTaskStatus(DateTime date, int index) async {
    final key = _getDateKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;
    final currentTask = tasks[index];
    tasks[index] = Task(task: currentTask.task, done: !currentTask.done);
    await _box.put(key, tasks);
  }

  /// Returns a map with task summary: {total, completed, pending}.
  Map<String, int> getTaskSummaryForDate(DateTime date) {
    final tasks = getTasksForDate(date);
    final completed = tasks.where((task) => task.done).length;
    final pending = tasks.length - completed;
    return {
      'total': tasks.length,
      'completed': completed,
      'pending': pending,
    };
  }

  /// Returns a ValueListenable that rebuilds when the box changes.
  /// If [keys] is provided, only rebuilds when those specific keys change.
  ValueListenable<Box<List>> listenable({List<String>? keys}) {
    if (keys != null && keys.isNotEmpty) {
      return _box.listenable(keys: keys);
    }
    return _box.listenable();
  }
}
