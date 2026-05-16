import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';

class HiveService {
  HiveService._privateConstructor();
  static final HiveService instance = HiveService._privateConstructor();

  static const _boxName = 'tasksBox';
  static const _categoriesKey = '__meta_categories__';
  static const _delegatesKey = '__meta_delegates__';
  static const _usernameKey = '__meta_username__';
  static const _journalPrefix = '__journal__';
  static const _schemaVersionKey = '__meta_schema_version__';
  static const int _currentSchemaVersion = 1;

  static const List<String> _defaultCategories = [
    'Work',
    'Personal',
    'Study',
    'Health',
    'Finance',
  ];
  late Box<List> _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskAdapter());
    }

    _box = await Hive.openBox<List>(_boxName);
    await _runMigrationsIfNeeded();
  }

  Future<void> _runMigrationsIfNeeded() async {
    final storedVersion = _readStoredSchemaVersion();
    if (storedVersion >= _currentSchemaVersion) return;

    if (storedVersion < 1) {
      await _migrateToV1();
    }

    await _box.put(_schemaVersionKey, <int>[_currentSchemaVersion]);
  }

  int _readStoredSchemaVersion() {
    final raw = _box.get(_schemaVersionKey);
    if (raw == null) return 0;

    if (raw is List && raw.isNotEmpty) {
      final value = raw.first;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  Future<void> _migrateToV1() async {
    final categories = (_box.get(_categoriesKey) ?? <String>[]).cast<String>();
    final delegates = (_box.get(_delegatesKey) ?? <String>[]).cast<String>();

    await _box.put(_categoriesKey, categories.toList());
    await _box.put(_delegatesKey, delegates.toList());
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


  List<String> getCategories() {
    final saved = (_box.get(_categoriesKey) ?? <String>[]).cast<String>();
    final merged = <String>[..._defaultCategories];
    for (final category in saved) {
      if (!merged.any((item) => item.toLowerCase() == category.toLowerCase())) {
        merged.add(category);
      }
    }
    return merged;
  }

  Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;

    final saved = (_box.get(_categoriesKey) ?? <String>[]).cast<String>().toList();
    if (!saved.any((item) => item.toLowerCase() == trimmed.toLowerCase()) &&
        !_defaultCategories.any((item) => item.toLowerCase() == trimmed.toLowerCase())) {
      saved.add(trimmed);
      await _box.put(_categoriesKey, saved);
    }
  }

  String getUsername() {
    final saved = (_box.get(_usernameKey) ?? <String>['Productivity Hero']).cast<String>();
    if (saved.isEmpty || saved.first.trim().isEmpty) return 'Productivity Hero';
    return saved.first.trim();
  }

  Future<void> setUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;
    await _box.put(_usernameKey, <String>[trimmed]);
  }


  String _journalKey(DateTime date) {
    return '$_journalPrefix${_formatKey(date)}';
  }

  JournalEntry? getJournalEntryForDate(DateTime date) {
    final raw = _box.get(_journalKey(date));
    if (raw == null) return null;
    return JournalEntry.fromStorageList(raw.cast<dynamic>(), DateTime(date.year, date.month, date.day));
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    await _box.put(_journalKey(entry.date), entry.toStorageList());
  }

  Future<void> deleteJournalEntry(DateTime date) async {
    await _box.delete(_journalKey(date));
  }

  List<JournalEntry> getAllJournalEntries() {
    final entries = <JournalEntry>[];

    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_journalPrefix)) continue;
      final dateText = key.substring(_journalPrefix.length);
      final parsedDate = DateTime.tryParse(dateText);
      final raw = _box.get(key);
      if (parsedDate == null || raw == null) continue;
      entries.add(JournalEntry.fromStorageList(raw.cast<dynamic>(), parsedDate));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  List<String> getDelegates() {
    return (_box.get(_delegatesKey) ?? <String>[]).cast<String>().toList();
  }

  Future<void> addDelegate(String delegate) async {
    final trimmed = delegate.trim();
    if (trimmed.isEmpty) return;

    final saved = (_box.get(_delegatesKey) ?? <String>[]).cast<String>().toList();
    if (!saved.any((item) => item.toLowerCase() == trimmed.toLowerCase())) {
      saved.add(trimmed);
      await _box.put(_delegatesKey, saved);
    }
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

    tasks[index] = task;
    await _box.put(key, tasks);

    await _handleRecurringIfNeeded(updated: task);
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

    await _handleRecurringIfNeeded(updated: updatedTask);
  }

  Future<void> _handleRecurringIfNeeded({
    required Task updated,
  }) async {
    if (!updated.repeatTask) return;

    if (!_isTerminalStatus(updated.status)) return;

    final nextDueDate = _computeNextDueDate(updated.dueDate, updated.repeatFrequency);
    if (nextDueDate == null) return;

    final nextKey = _formatKey(nextDueDate);
    final nextDateTasks = getTasksForDate(nextDueDate);

    final alreadyExists = nextDateTasks.any(
      (task) =>
          task.task == updated.task &&
          _isSameDate(task.dueDate, nextDueDate) &&
          task.repeatTask == true &&
          _normalizedRepeatFrequency(task.repeatFrequency) == _normalizedRepeatFrequency(updated.repeatFrequency),
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
    final normalized = status.trim().toLowerCase();
    return normalized == 'completed' ||
        normalized == 'cancelled' ||
        normalized == 'missed' ||
        normalized == 'overdue';
  }

  DateTime? _computeNextDueDate(DateTime dueDate, String? repeatFrequency) {
    switch (_normalizedRepeatFrequency(repeatFrequency)) {
      case 'daily':
        return dueDate.add(const Duration(days: 1));
      case 'weekly':
        return dueDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
      case 'yearly':
        return DateTime(dueDate.year + 1, dueDate.month, dueDate.day);
      default:
        return null;
    }
  }

  String _normalizedRepeatFrequency(String? repeatFrequency) {
    final normalized = (repeatFrequency ?? '').trim().toLowerCase();
    return normalized.isEmpty ? 'daily' : normalized;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }


  Future<bool> updateTaskByReference(Task original, Task updated) async {
    for (final key in _box.keys) {
      if (key is! String) continue;

      final rawList = _box.get(key);
      if (rawList == null) continue;
      final tasks = rawList.cast<Task>().toList();

      for (int i = 0; i < tasks.length; i++) {
        final candidate = tasks[i];
        if (identical(candidate, original) || _matchesTaskIdentity(candidate, original)) {
          tasks[i] = updated;
          await _box.put(key, tasks);
          await _handleRecurringIfNeeded(updated: updated);
          return true;
        }
      }
    }

    return false;
  }

  bool _matchesTaskIdentity(Task a, Task b) {
    return a.task == b.task &&
        a.dueDate.year == b.dueDate.year &&
        a.dueDate.month == b.dueDate.month &&
        a.dueDate.day == b.dueDate.day &&
        a.priority == b.priority &&
        a.status == b.status &&
        a.category == b.category;
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
