import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/journal_entry.dart';
import '../models/journey_entry.dart';
import '../models/task_model.dart';
import '../constants/dashboard_themes.dart';

class HiveService {
  HiveService._privateConstructor();
  static final HiveService instance = HiveService._privateConstructor();

  static const _boxName = 'tasksBox';
  static const _categoriesKey = '__meta_categories__';
  static const _delegatesKey = '__meta_delegates__';
  static const _usernameKey = '__meta_username__';
  static const _journalPrefix = '__journal__';
  static const _journeyPrefix = '__journey__';
  static const _schemaVersionKey = '__meta_schema_version__';
  static const _dashboardThemeKey = '__meta_dashboard_theme__';
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
    await _normalizeTaskNamesOnStartup();
    await _dedupeRecurringTasksOnStartup();
  }



  Future<void> _normalizeTaskNamesOnStartup() async {
    for (final key in _box.keys) {
      if (key is! String) continue;
      if (DateTime.tryParse(key) == null) continue;
      final rawList = _box.get(key);
      if (rawList == null) continue;
      final tasks = rawList.cast<Task>().toList();
      bool changed = false;
      final normalized = tasks.map((task) {
        final title = _toTitleCase(task.task);
        if (title != task.task) {
          changed = true;
          return task.copyWith(task: title);
        }
        return task;
      }).toList();
      if (changed) {
        await _box.put(key, normalized);
      }
    }
  }

  String _toTitleCase(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    final words = trimmed.split(RegExp(r'\s+'));
    return words
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  Task _withNormalizedTaskName(Task task) {
    return task.copyWith(task: _toTitleCase(task.task));
  }

  Future<void> _dedupeRecurringTasksOnStartup() async {
    for (final key in _box.keys) {
      if (key is! String) continue;
      if (DateTime.tryParse(key) == null) continue;
      final rawList = _box.get(key);
      if (rawList == null) continue;
      final tasks = rawList.cast<Task>().toList();
      final deduped = _dedupeRecurringTasksForDate(tasks);
      if (deduped.length != tasks.length) {
        await _box.put(key, deduped);
      }
    }
  }

  List<Task> _dedupeRecurringTasksForDate(List<Task> tasks) {
    final result = <Task>[];
    final recurringIndex = <String, int>{};

    for (final task in tasks) {
      if (!task.repeatTask) {
        result.add(task);
        continue;
      }

      final recurringKey = _recurringIdentityKey(task);
      if (!recurringIndex.containsKey(recurringKey)) {
        recurringIndex[recurringKey] = result.length;
        result.add(task);
        continue;
      }

      final existingPos = recurringIndex[recurringKey]!;
      final existing = result[existingPos];
      final existingTerminal = _isTerminalStatus(existing.status) || existing.done;
      final incomingTerminal = _isTerminalStatus(task.status) || task.done;

      // Prefer finalized occurrence records over not-started duplicates.
      if (!existingTerminal && incomingTerminal) {
        result[existingPos] = task;
      }
    }

    return result;
  }

  String _recurringIdentityKey(Task task) {
    final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    return '${task.task.trim().toLowerCase()}|${task.category.trim().toLowerCase()}|${_normalizedRepeatFrequency(task.repeatFrequency)}|${_formatKey(due)}';
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


  String _journeyKey(String id) {
    return '$_journeyPrefix$id';
  }

  Future<void> saveJourneyEntry(JourneyEntry entry) async {
    await _box.put(_journeyKey(entry.id), entry.toStorageList());
  }

  Future<void> deleteJourneyEntry(String id) async {
    await _box.delete(_journeyKey(id));
  }

  List<JourneyEntry> getAllJourneyEntries() {
    final entries = <JourneyEntry>[];

    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_journeyPrefix)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      entries.add(JourneyEntry.fromStorageList(raw.cast<dynamic>(), DateTime.now()));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }


  DashboardThemeType getDashboardTheme() {
    final stored = _box.get(_dashboardThemeKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return dashboardThemeTypeFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setDashboardTheme(DashboardThemeType theme) async {
    await _box.put(_dashboardThemeKey, <String>[theme.storageKey]);
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
    final normalizedTask = _withNormalizedTaskName(task);
    tasks.add(normalizedTask);
    await _box.put(key, _dedupeRecurringTasksForDate(tasks));
  }

  Future<void> updateTask(DateTime date, int index, Task task) async {
    final normalizedTask = _withNormalizedTaskName(task);
    if (normalizedTask.repeatTask) {
      await _updateRecurringTaskForCurrentOccurrence(normalizedTask);
      return;
    }

    final key = _formatKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;

    tasks[index] = normalizedTask;
    await _box.put(key, _dedupeRecurringTasksForDate(tasks));

    await _handleRecurringIfNeeded(updated: normalizedTask);
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
    await _box.put(key, _dedupeRecurringTasksForDate(tasks));

    await _handleRecurringIfNeeded(updated: updatedTask);
  }

  Future<void> _handleRecurringIfNeeded({
    required Task updated,
  }) async {
    if (!updated.repeatTask || !updated.routineEnabled) return;

    if (!_isTerminalStatus(updated.status)) return;

    final nextDueDate = _computeNextDueDate(updated.dueDate, updated.repeatFrequency);
    if (nextDueDate == null) return;

    final nextKey = _formatKey(nextDueDate);
    final nextDateTasks = getTasksForDate(nextDueDate);

    final nextOccurrence = updated.copyWith(
      dueDate: nextDueDate,
      done: false,
      status: 'Not Started',
    );

    final existingIndex = nextDateTasks.indexWhere(
      (task) => _isSameRecurringTaskIdentity(task, nextOccurrence),
    );

    if (existingIndex >= 0) {
      nextDateTasks[existingIndex] = nextOccurrence;
    } else {
      nextDateTasks.add(nextOccurrence);
    }

    await _box.put(nextKey, _dedupeRecurringTasksForDate(nextDateTasks));
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


  DateTime _currentOccurrenceDate(String? repeatFrequency, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    switch (_normalizedRepeatFrequency(repeatFrequency)) {
      case 'daily':
        return day;
      case 'weekly':
        return day.subtract(Duration(days: day.weekday - 1)); // Monday
      case 'monthly':
        return DateTime(day.year, day.month, 1);
      case 'yearly':
        return DateTime(day.year, 1, 1);
      default:
        return day;
    }
  }

  Future<bool> _updateRecurringTaskForCurrentOccurrence(Task updated) async {
    final now = DateTime.now();
    final normalizedTask = _withNormalizedTaskName(updated);
    final occurrenceDate = _currentOccurrenceDate(normalizedTask.repeatFrequency, now);
    final normalizedUpdated = normalizedTask.copyWith(dueDate: occurrenceDate, repeatTask: true);
    final key = _formatKey(occurrenceDate);
    final tasks = getTasksForDate(occurrenceDate);

    final existingIndex = tasks.indexWhere((task) => _isSameRecurringTaskIdentity(task, normalizedUpdated));
    if (existingIndex >= 0) {
      tasks[existingIndex] = normalizedUpdated;
    } else {
      tasks.add(normalizedUpdated);
    }

    await _box.put(key, _dedupeRecurringTasksForDate(tasks));
    await _handleRecurringIfNeeded(updated: normalizedUpdated);
    return true;
  }

  Future<bool> updateTaskByReference(Task original, Task updated) async {
    final normalizedUpdated = _withNormalizedTaskName(updated);
    if (normalizedUpdated.repeatTask) {
      return _updateRecurringTaskForCurrentOccurrence(normalizedUpdated);
    }

    for (final key in _box.keys) {
      if (key is! String || DateTime.tryParse(key) == null) continue;

      final rawList = _box.get(key);
      if (rawList == null) continue;
      final tasks = rawList.cast<Task>().toList();

      for (int i = 0; i < tasks.length; i++) {
        final candidate = tasks[i];
        if (identical(candidate, original) || _matchesTaskIdentity(candidate, original)) {
          tasks[i] = normalizedUpdated;
          await _box.put(key, _dedupeRecurringTasksForDate(tasks));
          await _handleRecurringIfNeeded(updated: normalizedUpdated);
          return true;
        }
      }
    }

    return false;
  }


  Future<bool> deleteTaskByReference(Task original) async {
    for (final key in _box.keys) {
      if (key is! String || DateTime.tryParse(key) == null) continue;

      final rawList = _box.get(key);
      if (rawList == null) continue;
      final tasks = rawList.cast<Task>().toList();

      for (int i = 0; i < tasks.length; i++) {
        final candidate = tasks[i];
        if (identical(candidate, original) || _matchesTaskIdentity(candidate, original)) {
          tasks.removeAt(i);
          await _box.put(key, _dedupeRecurringTasksForDate(tasks));
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> setRecurringTaskEnabledByReference(Task original, bool enabled) async {
    if (!original.repeatTask) return false;

    var changed = false;
    for (final key in _box.keys) {
      if (key is! String || DateTime.tryParse(key) == null) continue;

      final rawList = _box.get(key);
      if (rawList == null) continue;
      final tasks = rawList.cast<Task>().toList();
      var listChanged = false;

      for (int i = 0; i < tasks.length; i++) {
        final candidate = tasks[i];
        if (_isSameRecurringSeriesIdentity(candidate, original)) {
          tasks[i] = candidate.copyWith(routineEnabled: enabled);
          listChanged = true;
          changed = true;
        }
      }

      if (listChanged) {
        await _box.put(key, _dedupeRecurringTasksForDate(tasks));
      }
    }

    if (enabled && changed) {
      await _ensureCurrentRecurringOccurrenceEnabled(original);
    }

    return changed;
  }

  Future<void> _ensureCurrentRecurringOccurrenceEnabled(Task original) async {
    final occurrenceDate = _currentOccurrenceDate(original.repeatFrequency, DateTime.now());
    final key = _formatKey(occurrenceDate);
    final tasks = getTasksForDate(occurrenceDate);
    final occurrence = _withNormalizedTaskName(
      original.copyWith(
        dueDate: occurrenceDate,
        done: false,
        status: 'Not Started',
        repeatTask: true,
        routineEnabled: true,
      ),
    );

    final existingIndex = tasks.indexWhere((task) => _isSameRecurringTaskIdentity(task, occurrence));
    if (existingIndex >= 0) {
      tasks[existingIndex] = tasks[existingIndex].copyWith(routineEnabled: true);
    } else {
      tasks.add(occurrence);
    }

    await _box.put(key, _dedupeRecurringTasksForDate(tasks));
  }

  bool _matchesTaskIdentity(Task a, Task b) {
    return a.task == b.task &&
        a.dueDate.year == b.dueDate.year &&
        a.dueDate.month == b.dueDate.month &&
        a.dueDate.day == b.dueDate.day &&
        a.priority == b.priority &&
        a.category == b.category;
  }


  bool _isSameRecurringSeriesIdentity(Task a, Task b) {
    return a.repeatTask &&
        b.repeatTask &&
        a.task.trim().toLowerCase() == b.task.trim().toLowerCase() &&
        a.category.trim().toLowerCase() == b.category.trim().toLowerCase() &&
        _normalizedRepeatFrequency(a.repeatFrequency) == _normalizedRepeatFrequency(b.repeatFrequency);
  }

  bool _isSameRecurringTaskIdentity(Task a, Task b) {
    return a.repeatTask &&
        b.repeatTask &&
        a.task.trim().toLowerCase() == b.task.trim().toLowerCase() &&
        a.category.trim().toLowerCase() == b.category.trim().toLowerCase() &&
        _normalizedRepeatFrequency(a.repeatFrequency) == _normalizedRepeatFrequency(b.repeatFrequency) &&
        _isSameDate(a.dueDate, b.dueDate);
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
          _dedupeRecurringTasksForDate(tasks.cast<Task>().toList());
    }

    return result;
  }

  /// Returns a ValueListenable that rebuilds when the box changes
  ValueListenable<Box<List>> getBoxListenable() {
    return _box.listenable();
  }
}
