import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/journal_entry.dart';
import '../models/journey_entry.dart';
import '../models/productivity_snapshot.dart';
import '../models/task_model.dart';
import '../models/user_profile.dart';
import '../constants/dashboard_themes.dart';
import '../utils/task_time_utils.dart';

class HiveService {
  HiveService._privateConstructor();
  static final HiveService instance = HiveService._privateConstructor();

  static const _boxName = 'tasksBox';
  static const _categoriesKey = '__meta_categories__';
  static const _delegatesKey = '__meta_delegates__';
  static const _usernameKey = '__meta_username__';
  static const _userProfileKey = '__meta_user_profile__';
  static const _journalPrefix = '__journal__';
  static const _journeyPrefix = '__journey__';
  static const _productivityPrefix = '__productivity_snapshot__';
  static const _autoJourneyPrefix = 'auto_journey_';
  static const _schemaVersionKey = '__meta_schema_version__';
  static const _dashboardThemeKey = '__meta_dashboard_theme__';
  static const _dashboardPaletteKey = '__meta_dashboard_palette__';
  static const _appFontFamilyKey = '__meta_app_font_family__';
  static const _appFontScaleKey = '__meta_app_font_scale__';
  static const _appFontWeightKey = '__meta_app_font_weight__';
  static const _dashboardLayoutStyleKey = '__meta_dashboard_layout_style__';
  static const _dashboardCardAnimationKey = '__meta_dashboard_card_animation__';
  static const _dashboardAnimationSpeedKey = '__meta_dashboard_animation_speed__';
  static const _dashboardChartStyleKey = '__meta_dashboard_chart_style__';
  static const _dashboardIconPackKey = '__meta_dashboard_icon_pack__';
  static const _followSystemThemeKey = '__meta_follow_system_theme__';
  static const _autoDayNightKey = '__meta_auto_day_night__';
  static const _adaptiveColorsKey = '__meta_adaptive_colors__';
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
    await refreshProductivitySnapshotsFromTasks();
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

  String getUsername() => getUserProfile().displayName;

  Future<void> setUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;
    await saveUserProfile(getUserProfile().copyWith(fullName: trimmed));
  }

  UserProfile getUserProfile() {
    final legacyName = (_box.get(_usernameKey) ?? <String>['Productivity Hero']).cast<String>();
    final fallbackName = legacyName.isNotEmpty && legacyName.first.trim().isNotEmpty ? legacyName.first.trim() : 'Productivity Hero';
    final raw = _box.get(_userProfileKey);
    if (raw == null) return UserProfile.defaults(fullName: fallbackName);
    return UserProfile.fromStorageList(raw.cast<dynamic>(), fallbackName: fallbackName);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final previous = getUserProfile();
    final trimmed = profile.copyWith(
      fullName: profile.fullName.trim().isEmpty ? previous.displayName : profile.fullName.trim(),
      nickname: profile.nickname.trim(),
      bio: profile.bio.trim(),
      occupation: profile.occupation.trim(),
      birthday: profile.birthday.trim(),
      favoriteTheme: profile.favoriteTheme.trim().isEmpty ? 'Calm' : profile.favoriteTheme.trim(),
      avatarBorderStyle: profile.avatarBorderStyle.trim().isEmpty ? _avatarFrameForAchievement(getLifetimeProductivityStats().totalPoints) : profile.avatarBorderStyle.trim(),
      profilePhotoPath: profile.profilePhotoPath.trim(),
      photoHistory: _mergedPhotoHistory(previous, profile),
    );
    await _box.put(_userProfileKey, trimmed.toStorageList());
    await _box.put(_usernameKey, <String>[trimmed.displayName]);
    await _box.put(_dashboardThemeKey, <String>[_themeStorageKeyForLabel(trimmed.favoriteTheme)]);
    await _logProfileUpdate(previous, trimmed);
    await _syncAutoJourneyForDate(DateTime.now());
  }

  Future<void> removeProfilePhoto() async {
    final profile = getUserProfile();
    await saveUserProfile(profile.copyWith(profilePhotoPath: ''));
  }

  List<String> _mergedPhotoHistory(UserProfile previous, UserProfile next) {
    final history = <String>[...previous.photoHistory];
    final previousPhoto = previous.profilePhotoPath.trim();
    if (previousPhoto.isNotEmpty && previousPhoto != next.profilePhotoPath.trim() && !history.contains(previousPhoto)) {
      history.insert(0, previousPhoto);
    }
    return history.take(12).toList();
  }

  Future<void> _logProfileUpdate(UserProfile previous, UserProfile next) async {
    final changes = <String>[];
    if (previous.profilePhotoPath.trim() != next.profilePhotoPath.trim()) {
      changes.add(next.profilePhotoPath.trim().isEmpty ? '🗑️ Removed profile picture' : '📸 Updated profile picture');
    }
    if (previous.displayName != next.displayName || previous.nickname != next.nickname) changes.add('👤 Updated profile identity');
    if (previous.bio != next.bio) changes.add('😊 Changed bio');
    if (previous.occupation != next.occupation) changes.add('💼 Updated occupation');
    if (previous.favoriteTheme != next.favoriteTheme || previous.avatarBorderStyle != next.avatarBorderStyle) changes.add('🎨 Updated profile style');
    if (changes.isEmpty) return;

    final now = DateTime.now();
    final entry = JourneyEntry(
      id: 'profile_${now.microsecondsSinceEpoch}',
      date: now,
      type: 'Profile update',
      title: 'Profile updated',
      description: changes.join('\n'),
      colorValue: 0xFF8E24AA,
      imageUrl: next.profilePhotoPath.trim().isEmpty ? null : next.profilePhotoPath.trim(),
    );
    await saveJourneyEntry(entry);
  }

  String _avatarFrameForAchievement(int points) {
    if (points >= 100000) return 'Animated Rainbow';
    if (points >= 50000) return 'Golden Frame';
    if (points >= 25000) return 'Purple Aura';
    if (points >= 10000) return 'Green Ring';
    if (points >= 5000) return 'Blue Glow';
    return 'Silver';
  }

  String _themeStorageKeyForLabel(String label) {
    final normalized = label.trim().toLowerCase();
    for (final theme in DashboardThemeType.values) {
      if (theme.label.toLowerCase() == normalized || theme.storageKey.toLowerCase() == normalized) {
        return theme.storageKey;
      }
    }
    return DashboardThemeType.calm.storageKey;
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
    await _syncAutoJourneyForDate(entry.date);
  }

  Future<void> deleteJournalEntry(DateTime date) async {
    await _box.delete(_journalKey(date));
    await _syncAutoJourneyForDate(date);
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
    if (!entry.isAutoDailySummary) {
      await _syncAutoJourneyForDate(entry.date);
    }
  }

  Future<void> deleteJourneyEntry(String id) async {
    final key = _journeyKey(id);
    final raw = _box.get(key);
    final entry = raw == null ? null : JourneyEntry.fromStorageList(raw.cast<dynamic>(), DateTime.now());
    await _box.delete(key);
    if (entry != null && !entry.isAutoDailySummary) {
      await _syncAutoJourneyForDate(entry.date);
    }
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

  DashboardPaletteType getDashboardPalette() {
    final stored = _box.get(_dashboardPaletteKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return dashboardPaletteTypeFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setDashboardPalette(DashboardPaletteType palette) async {
    await _box.put(_dashboardPaletteKey, <String>[palette.storageKey]);
  }

  AppFontFamily getAppFontFamily() {
    final stored = _box.get(_appFontFamilyKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return appFontFamilyFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setAppFontFamily(AppFontFamily font) async {
    await _box.put(_appFontFamilyKey, <String>[font.storageKey]);
  }

  AppFontScale getAppFontScale() {
    final stored = _box.get(_appFontScaleKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return appFontScaleFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setAppFontScale(AppFontScale scale) async {
    await _box.put(_appFontScaleKey, <String>[scale.storageKey]);
  }

  AppFontWeightChoice getAppFontWeight() {
    final stored = _box.get(_appFontWeightKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return appFontWeightFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setAppFontWeight(AppFontWeightChoice weight) async {
    await _box.put(_appFontWeightKey, <String>[weight.storageKey]);
  }

  DashboardLayoutStyle getDashboardLayoutStyle() {
    final stored = _box.get(_dashboardLayoutStyleKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return dashboardLayoutStyleFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setDashboardLayoutStyle(DashboardLayoutStyle layout) async {
    await _box.put(_dashboardLayoutStyleKey, <String>[layout.storageKey]);
  }

  DashboardCardAnimationStyle getDashboardCardAnimationStyle() {
    final stored = _box.get(_dashboardCardAnimationKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return dashboardCardAnimationStyleFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setDashboardCardAnimationStyle(DashboardCardAnimationStyle animation) async {
    await _box.put(_dashboardCardAnimationKey, <String>[animation.storageKey]);
  }

  DashboardAnimationSpeed getDashboardAnimationSpeed() {
    final stored = _box.get(_dashboardAnimationSpeedKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return dashboardAnimationSpeedFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setDashboardAnimationSpeed(DashboardAnimationSpeed speed) async {
    await _box.put(_dashboardAnimationSpeedKey, <String>[speed.storageKey]);
  }

  DashboardChartStyle getDashboardChartStyle() {
    final stored = _box.get(_dashboardChartStyleKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return dashboardChartStyleFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setDashboardChartStyle(DashboardChartStyle chartStyle) async {
    await _box.put(_dashboardChartStyleKey, <String>[chartStyle.storageKey]);
  }

  DashboardIconPack getDashboardIconPack() {
    final stored = _box.get(_dashboardIconPackKey);
    final firstValue = stored == null || stored.isEmpty ? null : stored.first;
    return dashboardIconPackFromStorage(firstValue is String ? firstValue : null);
  }

  Future<void> setDashboardIconPack(DashboardIconPack iconPack) async {
    await _box.put(_dashboardIconPackKey, <String>[iconPack.storageKey]);
  }

  bool _getBoolPreference(String key) {
    final stored = _box.get(key);
    if (stored == null || stored.isEmpty) return false;
    return stored.first == true;
  }

  bool getFollowSystemTheme() => _getBoolPreference(_followSystemThemeKey);

  Future<void> setFollowSystemTheme(bool value) async {
    await _box.put(_followSystemThemeKey, <dynamic>[value]);
  }

  bool getAutoDayNight() => _getBoolPreference(_autoDayNightKey);

  Future<void> setAutoDayNight(bool value) async {
    await _box.put(_autoDayNightKey, <dynamic>[value]);
  }

  bool getAdaptiveColors() => _getBoolPreference(_adaptiveColorsKey);

  Future<void> setAdaptiveColors(bool value) async {
    await _box.put(_adaptiveColorsKey, <dynamic>[value]);
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
    await recalculateProductivitySnapshotForDate(date);
  }

  Future<void> updateTask(DateTime date, int index, Task task) async {
    final normalizedTask = _withNormalizedTaskName(task);
    if (normalizedTask.repeatTask) {
      await _updateRecurringTaskForCurrentOccurrence(normalizedTask);
      await recalculateProductivitySnapshotForDate(DateTime.now());
      return;
    }

    final key = _formatKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;

    tasks[index] = normalizedTask;
    await _box.put(key, _dedupeRecurringTasksForDate(tasks));
    await recalculateProductivitySnapshotForDate(date);

    await _handleRecurringIfNeeded(updated: normalizedTask);
  }

  Future<void> deleteTask(DateTime date, int index) async {
    final key = _formatKey(date);
    final tasks = getTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;
    tasks.removeAt(index);
    await _box.put(key, tasks);
    await recalculateProductivitySnapshotForDate(date);
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
    await recalculateProductivitySnapshotForDate(date);

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
      status: 'Not Updated',
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
    await recalculateProductivitySnapshotForDate(occurrenceDate);
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
          final changedDate = DateTime.parse(key);
          await recalculateProductivitySnapshotForDate(changedDate);
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
          final changedDate = DateTime.parse(key);
          await recalculateProductivitySnapshotForDate(changedDate);
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> updateRecurringTaskSeriesByReference(Task original, Task updated) async {
    if (!original.repeatTask || !updated.repeatTask) return false;

    final normalizedUpdated = _withNormalizedTaskName(updated.copyWith(repeatTask: true));
    var changed = false;
    final changedDates = <DateTime>[];

    for (final key in _box.keys) {
      if (key is! String || DateTime.tryParse(key) == null) continue;

      final rawList = _box.get(key);
      if (rawList == null) continue;
      final tasks = rawList.cast<Task>().toList();
      var listChanged = false;

      for (int i = 0; i < tasks.length; i++) {
        final candidate = tasks[i];
        if (_isSameRecurringSeriesIdentity(candidate, original)) {
          tasks[i] = normalizedUpdated.copyWith(
            dueDate: candidate.dueDate,
            done: candidate.done,
            status: candidate.status,
            hourSlot: candidate.hourSlot,
            routineEnabled: candidate.routineEnabled,
          );
          listChanged = true;
          changed = true;
        }
      }

      if (listChanged) {
        await _box.put(key, _dedupeRecurringTasksForDate(tasks));
        changedDates.add(DateTime.parse(key));
      }
    }

    for (final changedDate in changedDates) {
      await recalculateProductivitySnapshotForDate(changedDate);
    }

    if (changed && normalizedUpdated.routineEnabled) {
      await _ensureCurrentRecurringOccurrenceEnabled(normalizedUpdated);
    }

    return changed;
  }

  Future<bool> setRecurringTaskEnabledByReference(Task original, bool enabled) async {
    if (!original.repeatTask) return false;

    var changed = false;
    final changedDates = <DateTime>[];
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
        changedDates.add(DateTime.parse(key));
      }
    }

    for (final changedDate in changedDates) {
      await recalculateProductivitySnapshotForDate(changedDate);
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
        status: 'Not Updated',
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
    await recalculateProductivitySnapshotForDate(occurrenceDate);
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


  String _productivityKey(DateTime date) {
    return '$_productivityPrefix${_formatKey(date)}';
  }

  ProductivitySnapshot getProductivitySnapshotForDate(DateTime date) {
    final raw = _box.get(_productivityKey(date));
    if (raw == null) return calculateProductivitySnapshotForDate(date);
    return ProductivitySnapshot.fromStorageList(raw.cast<dynamic>());
  }

  List<ProductivitySnapshot> getProductivitySnapshots() {
    final snapshots = <ProductivitySnapshot>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_productivityPrefix)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      snapshots.add(ProductivitySnapshot.fromStorageList(raw.cast<dynamic>()));
    }
    snapshots.sort((a, b) => a.date.compareTo(b.date));
    return snapshots;
  }

  LifetimeProductivityStats getLifetimeProductivityStats() {
    return LifetimeProductivityStats.fromSnapshots(getProductivitySnapshots());
  }

  Future<void> refreshProductivitySnapshotsFromTasks() async {
    for (final date in getAllTasksByDate().keys) {
      await recalculateProductivitySnapshotForDate(date);
    }
  }

  Future<ProductivitySnapshot> recalculateProductivitySnapshotForDate(DateTime date) async {
    final snapshot = calculateProductivitySnapshotForDate(date);
    await _box.put(_productivityKey(date), snapshot.toStorageList());
    await _syncAutoJourneyForDate(date);
    return snapshot;
  }

  ProductivitySnapshot calculateProductivitySnapshotForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final tasks = getTasksForDate(day);
    var bothMinutes = 0;
    var importantMinutes = 0;
    var urgentMinutes = 0;
    var neitherMinutes = 0;
    var completedTasks = 0;
    var routineCompletions = 0;
    var projectPhasesCompleted = 0;
    var basePoints = 0;
    var streakBonusPoints = 0;
    final completedTaskNames = <String>[];
    final pointEvents = <ProductivityPointEvent>[];

    for (final task in tasks) {
      final recordedMinutes = taskRecordedMinutesForDay(task);
      if (recordedMinutes <= 0) continue;

      if (task.urgent && task.important) {
        bothMinutes += recordedMinutes;
      } else if (task.important) {
        importantMinutes += recordedMinutes;
      } else if (task.urgent) {
        urgentMinutes += recordedMinutes;
      } else {
        neitherMinutes += recordedMinutes;
      }

      final taskBasePoints = _productivityPointsForTask(task, recordedMinutes);
      var taskBonusPoints = 0;
      var reason = 'Base productivity points';

      if (_isCompletedTask(task)) {
        completedTasks++;
        completedTaskNames.add(task.task);
        if (task.repeatTask) {
          routineCompletions++;
          final streak = _routineCompletionStreakForDate(task, day);
          taskBonusPoints = _streakBonusForLength(streak);
          if (taskBonusPoints > 0) {
            reason = '$streak-day streak milestone';
          }
        }
      }

      final phases = parseTaskPhases(task.description);
      final completedPhaseCount = phases.where((phase) => phase.isCompleted).length;
      projectPhasesCompleted += completedPhaseCount;
      if (!_isCompletedTask(task) && completedPhaseCount > 0) {
        completedTaskNames.add('${task.task} ($completedPhaseCount phases)');
      }

      basePoints += taskBasePoints;
      streakBonusPoints += taskBonusPoints;
      pointEvents.add(
        ProductivityPointEvent(
          title: task.repeatTask
              ? '${task.task} Completed'
              : completedPhaseCount > 0
                  ? '${task.task} Phase Progress'
                  : '${task.task} Completed',
          basePoints: taskBasePoints,
          streakBonusPoints: taskBonusPoints,
          totalPoints: taskBasePoints + taskBonusPoints,
          reason: taskBonusPoints > 0 ? reason : (completedPhaseCount > 0 ? '$completedPhaseCount project phase${completedPhaseCount == 1 ? '' : 's'} completed' : reason),
        ),
      );
    }

    final bothHours = bothMinutes / 60.0;
    final importantHours = importantMinutes / 60.0;
    final urgentHours = urgentMinutes / 60.0;
    final neitherHours = neitherMinutes / 60.0;
    final totalHours = bothHours + importantHours + urgentHours + neitherHours;
    final totalPoints = basePoints + streakBonusPoints;
    final score = (totalPoints / ProductivitySnapshot.maximumPoints * 100).clamp(0.0, 100.0).toDouble();

    return ProductivitySnapshot(
      date: day,
      bothHours: bothHours,
      importantHours: importantHours,
      urgentHours: urgentHours,
      neitherHours: neitherHours,
      totalHours: totalHours,
      totalPoints: totalPoints,
      basePoints: basePoints,
      streakBonusPoints: streakBonusPoints,
      productivityScore: score,
      rating: ProductivitySnapshot.ratingForScore(score),
      completedTasks: completedTasks,
      routineCompletions: routineCompletions,
      projectPhasesCompleted: projectPhasesCompleted,
      completedTaskNames: completedTaskNames,
      pointEvents: pointEvents,
    );
  }

  bool _isCompletedTask(Task task) {
    return task.done || task.status.trim().toLowerCase() == 'completed';
  }


  int _productivityPointsForTask(Task task, int recordedMinutes) {
    return (recordedMinutes / 60 * _productivityPointRate(task)).round();
  }

  int _productivityPointRate(Task task) {
    if (task.urgent && task.important) return 100;
    if (task.important) return 80;
    if (task.urgent) return 50;
    return 10;
  }

  int _streakBonusForLength(int streakLength) {
    const bonuses = {
      3: 10,
      7: 25,
      15: 50,
      30: 100,
      60: 200,
      100: 500,
    };
    return bonuses[streakLength] ?? 0;
  }

  int _routineCompletionStreakForDate(Task task, DateTime date) {
    if (!task.repeatTask || !_isCompletedTask(task)) return 0;
    final frequency = _normalizedRepeatFrequency(task.repeatFrequency);
    final stepDays = frequency == 'daily'
        ? 1
        : frequency == 'weekly'
            ? 7
            : 0;
    if (stepDays == 0) return 0;

    final completedOccurrences = <DateTime>{};
    for (final entry in getAllTasksByDate().entries) {
      for (final candidate in entry.value) {
        if (_isSameRecurringSeriesIdentity(candidate, task) && _isCompletedTask(candidate)) {
          final occurrence = _currentOccurrenceDate(candidate.repeatFrequency, candidate.dueDate);
          completedOccurrences.add(DateTime(occurrence.year, occurrence.month, occurrence.day));
        }
      }
    }

    var cursor = _currentOccurrenceDate(task.repeatFrequency, date);
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    var streak = 0;
    while (completedOccurrences.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(Duration(days: stepDays));
    }
    return streak;
  }


  String _autoJourneyId(DateTime date) {
    return '$_autoJourneyPrefix${_formatKey(date)}';
  }

  Future<void> _syncAutoJourneyForDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final snapshot = calculateProductivitySnapshotForDate(day);
    final tasks = getTasksForDate(day);
    final journal = getJournalEntryForDate(day);
    final manualEntries = getAllJourneyEntries()
        .where((entry) => !entry.isAutoDailySummary && _isSameDate(entry.date, day))
        .toList();
    final photoCount = manualEntries.where((entry) => entry.hasImage).length;
    final lifetime = getLifetimeProductivityStats();
    final lines = <String>['${_isSameDate(day, DateTime.now()) ? 'Today' : 'Day'} • ${_humanDate(day)}'];

    for (final task in tasks) {
      final status = task.status.trim().toLowerCase();
      final minutes = taskRecordedMinutesForDay(task);
      if (_isCompletedTask(task) && minutes > 0) {
        lines.add('${task.repeatTask ? '✅ Routine' : '✅ Task'} ${task.task} completed • +$minutes min');
      } else if (task.repeatTask && (status == 'missed' || status == 'overdue' || status == 'cancelled')) {
        lines.add("❌ ${task.task} ${status == 'cancelled' ? 'cancelled' : status}");
      }

      for (final phase in parseTaskPhases(task.description).where((phase) => phase.isCompleted)) {
        lines.add('🧩 ${task.task} phase completed: ${phase.name} • +${phase.minutes} min');
      }
    }

    final disabledRoutines = tasks.where((task) => task.repeatTask && !task.routineEnabled).length;
    final enabledRoutines = tasks.where((task) => task.repeatTask && task.routineEnabled).length;
    if (disabledRoutines > 0) lines.add('⏸️ $disabledRoutines routine${disabledRoutines == 1 ? '' : 's'} disabled');
    if (enabledRoutines > 0) lines.add('🔁 $enabledRoutines routine${enabledRoutines == 1 ? '' : 's'} enabled');

    lines.add('📊 Productivity score: ${snapshot.productivityScore.toStringAsFixed(1)}%');
    lines.add('⭐ Points earned today: +${snapshot.totalPoints}');
    if (snapshot.streakBonusPoints > 0) lines.add('🏆 Streak bonus earned: +${snapshot.streakBonusPoints}');
    for (final event in snapshot.pointEvents.where((event) => event.streakBonusPoints > 0)) {
      lines.add('🔥 ${event.title} • ${event.reason} • +${event.streakBonusPoints} bonus points');
    }
    lines.add('💎 Lifetime points: ${lifetime.totalPoints}');
    lines.add('🔥 Streak: ${lifetime.currentStreak} day${lifetime.currentStreak == 1 ? '' : 's'}');
    lines.add('🏅 Lifetime XP: ${lifetime.xp} • Level ${lifetime.level}');

    if (journal != null) {
      lines.add('😊 Mood: ${journal.mood}');
      if (journal.reflection.trim().isNotEmpty) lines.add('📝 Reflection added');
    }
    if (photoCount > 0) lines.add('📷 $photoCount photo${photoCount == 1 ? '' : 's'} attached');

    final hasActivity = snapshot.totalPoints > 0 || tasks.isNotEmpty || journal != null || manualEntries.isNotEmpty;
    final key = _journeyKey(_autoJourneyId(day));
    if (!hasActivity) {
      await _box.delete(key);
      return;
    }

    final accent = tasks.isNotEmpty
        ? tasks.first.colorValue
        : journal != null
            ? _journalMoodColor(journal.mood)
            : 0xFF1E88E5;

    final entry = JourneyEntry(
      id: _autoJourneyId(day),
      date: day,
      type: 'Daily auto update',
      title: _isSameDate(day, DateTime.now()) ? 'Today’s activity' : 'Daily activity',
      description: lines.join('\n'),
      colorValue: accent,
    );
    await _box.put(key, entry.toStorageList());
  }

  String _humanDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[(date.month - 1).clamp(0, 11)]} ${date.year}';
  }

  int _journalMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'focused':
        return 0xFF26A69A;
      case 'happy':
        return 0xFFFFB74D;
      case 'calm':
        return 0xFF81C784;
      case 'stressed':
        return 0xFFFF8A65;
      case 'tired':
        return 0xFF9575CD;
      default:
        return 0xFF1E88E5;
    }
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
