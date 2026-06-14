import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/instruction.dart';
import '../models/journal_entry.dart';
import '../models/journey_entry.dart';
import '../models/productivity_snapshot.dart';
import '../models/reward_money.dart';
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
  static const _dailyJournalTaskName = 'Daily Journal';
  static const _dailyJournalCategory = 'Journal';
  static const _dailyJournalDescription =
      'Built-in System Task • Completed by saving a journal entry\n'
      '⏰ Schedule Start: 22:00\n'
      '⏰ Schedule End: 00:00\n'
      '⏰ Schedule Bonus: 20 points';
  static const _legacyScheduledTimeMarker = '⏰ Scheduled:';
  static const _scheduleStartMarker = '⏰ Schedule Start:';
  static const _scheduleEndMarker = '⏰ Schedule End:';
  static const _scheduleBonusMarker = '⏰ Schedule Bonus:';
  static const _defaultScheduleBonusPoints = 20;
  static const _journeyPrefix = '__journey__';
  static const _productivityPrefix = '__productivity_snapshot__';
  static const _instructionPrefix = '__instruction__';
  static const _rewardLedgerPrefix = '__reward_ledger__';
  static const _rewardGoalPrefix = '__reward_goal__';
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
    _dailyJournalCategory,
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

  List<Task> _storedTasksForDate(DateTime date) {
    final key = _formatKey(date);
    final rawList = _box.get(key);
    if (rawList == null) return <Task>[];
    return rawList.cast<Task>().where((task) => !_isDailyJournalTask(task)).toList();
  }

  List<Task> getTasksForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return [
      ..._storedTasksForDate(day),
      _dailyJournalTaskForDate(day),
    ];
  }

  Task _dailyJournalTaskForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final journal = getJournalEntryForDate(day);
    final completed = journal?.hasReflection ?? false;
    final missed = !completed && day.isBefore(todayOnly);
    final journalWordCount = journal == null ? 0 : _journalWordCount(journal.reflection);

    return Task(
      task: _dailyJournalTaskName,
      done: completed,
      description: completed
          ? 'Built-in System Task • Journal saved successfully\n'
              '📝 Reflection Words: $journalWordCount\n'
              '⏰ Schedule Start: 22:00\n'
              '⏰ Schedule End: 00:00\n'
              '⏰ Schedule Bonus: 20 points'
          : _dailyJournalDescription,
      dueDate: completed ? journal!.date : day,
      priority: 'Important',
      status: completed ? 'Completed' : missed ? 'Missed' : 'Not Completed',
      category: _dailyJournalCategory,
      repeatTask: true,
      repeatFrequency: 'Daily',
      urgent: false,
      important: true,
      estimatedMinutes: completed ? _journalEstimatedMinutes(journal!.reflection) : 15,
      colorValue: 0xFF7E57C2,
      routineEnabled: true,
    );
  }

  bool _isDailyJournalTask(Task task) {
    return task.task.trim().toLowerCase() == _dailyJournalTaskName.toLowerCase() &&
        task.category.trim().toLowerCase() == _dailyJournalCategory.toLowerCase();
  }

  int _journalWordCount(String reflection) {
    return RegExp(r"\b[\w']+\b").allMatches(reflection).length;
  }

  int _journalEstimatedMinutes(String reflection) {
    final wordCount = _journalWordCount(reflection);
    if (wordCount <= 0) return 0;
    return (wordCount / 10).ceil().clamp(15, 120).toInt();
  }

  bool isDailyJournalTask(Task task) => _isDailyJournalTask(task);

  Future<void> _putTasksForKey(
    String key,
    List<Task> tasks, {
    bool dedupeRecurring = true,
  }) async {
    final filtered = tasks.where((task) => !_isDailyJournalTask(task)).toList();
    await _box.put(
      key,
      dedupeRecurring ? _dedupeRecurringTasksForDate(filtered) : filtered,
    );
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
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    await _box.put(_journalKey(day), entry.toStorageList());
    await recalculateProductivitySnapshotForDate(day);
  }

  Future<void> deleteJournalEntry(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    await _box.delete(_journalKey(day));
    await recalculateProductivitySnapshotForDate(day);
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
    final tasks = _storedTasksForDate(date);
    final normalizedTask = _withNormalizedTaskName(task);
    tasks.add(normalizedTask);
    await _putTasksForKey(key, tasks);
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
    final tasks = _storedTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;

    tasks[index] = normalizedTask;
    await _putTasksForKey(key, tasks);
    await recalculateProductivitySnapshotForDate(date);

    await _handleRecurringIfNeeded(updated: normalizedTask);
  }

  Future<void> deleteTask(DateTime date, int index) async {
    final key = _formatKey(date);
    final tasks = _storedTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;
    tasks.removeAt(index);
    await _putTasksForKey(key, tasks, dedupeRecurring: false);
    await recalculateProductivitySnapshotForDate(date);
  }

  Future<void> toggleTaskStatus(DateTime date, int index) async {
    final key = _formatKey(date);
    final tasks = _storedTasksForDate(date);
    if (index < 0 || index >= tasks.length) return;

    final currentTask = tasks[index];
    final nextDone = !currentTask.done;
    final updatedTask = currentTask.copyWith(
      done: nextDone,
      status: nextDone ? 'Completed' : 'In Progress',
    );

    tasks[index] = updatedTask;
    await _putTasksForKey(key, tasks);
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
    final nextDateTasks = _storedTasksForDate(nextDueDate);

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

    await _putTasksForKey(nextKey, nextDateTasks);
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
    final completionTimestamp = DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    final normalizedUpdated = normalizedTask.copyWith(
      dueDate: _isCompletedTask(normalizedTask) ? completionTimestamp : occurrenceDate,
      repeatTask: true,
    );
    final key = _formatKey(occurrenceDate);
    final tasks = _storedTasksForDate(occurrenceDate);

    final existingIndex = tasks.indexWhere((task) => _isSameRecurringTaskIdentity(task, normalizedUpdated));
    if (existingIndex >= 0) {
      tasks[existingIndex] = normalizedUpdated;
    } else {
      tasks.add(normalizedUpdated);
    }

    await _putTasksForKey(key, tasks);
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
          await _putTasksForKey(key, tasks);
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
          await _putTasksForKey(key, tasks);
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
        await _putTasksForKey(key, tasks);
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
        await _putTasksForKey(key, tasks);
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
    final tasks = _storedTasksForDate(occurrenceDate);
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

    await _putTasksForKey(key, tasks);
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



  String _instructionKey(String id) => '$_instructionPrefix$id';

  List<InstructionRule> getInstructions() {
    final instructions = <InstructionRule>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_instructionPrefix)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      instructions.add(InstructionRule.fromStorageList(raw.cast<dynamic>()));
    }
    instructions.sort((a, b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return instructions;
  }

  List<InstructionRule> getStandaloneInstructions() {
    return getInstructions().where((instruction) => instruction.isStandalone).toList();
  }

  List<InstructionRule> getTaskLinkedInstructions() {
    return getInstructions().where((instruction) => instruction.isTaskLinked).toList();
  }

  Future<void> saveInstruction(InstructionRule instruction) async {
    await _box.put(_instructionKey(instruction.id), instruction.toStorageList());
  }

  Future<void> deleteInstruction(String id) async {
    await _box.delete(_instructionKey(id));
  }

  Future<void> setInstructionEnabled(InstructionRule instruction, bool enabled) async {
    await saveInstruction(instruction.copyWith(enabled: enabled));
  }

  InstructionHistoryEntry? instructionEntryForDate(InstructionRule instruction, DateTime date) {
    final occurrence = _instructionOccurrenceDate(instruction, date);
    for (final entry in instruction.history) {
      if (_isSameDate(_instructionOccurrenceDate(instruction, entry.date), occurrence)) return entry;
    }
    return null;
  }

  Future<void> updateInstructionStatus(InstructionRule instruction, DateTime date, String status, {String note = '', InstructionLevel? level}) async {
    final occurrence = _instructionOccurrenceDate(instruction, date);
    final updatedHistory = instruction.history
        .where((entry) => !_isSameDate(_instructionOccurrenceDate(instruction, entry.date), occurrence))
        .toList();
    final followed = status == InstructionHistoryEntry.statusFollowed;
    final selectedLevel = followed ? level : null;
    updatedHistory.add(
      InstructionHistoryEntry(
        date: occurrence,
        status: status,
        bonusPoints: followed ? (selectedLevel?.bonusPoints ?? instruction.bonusPoints) : 0,
        xpEarned: followed ? (selectedLevel?.xpEarned ?? instruction.xpEarned) : 0,
        note: note.trim(),
        levelId: selectedLevel?.id ?? '',
        levelName: selectedLevel?.name ?? '',
        completedTarget: selectedLevel?.target ?? 0,
        unit: selectedLevel?.unit ?? instruction.unit,
      ),
    );
    await saveInstruction(instruction.copyWith(history: updatedHistory));
    await recalculateProductivitySnapshotForDate(occurrence);
  }

  DateTime _instructionOccurrenceDate(InstructionRule instruction, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    switch (instruction.repeatType.trim().toLowerCase()) {
      case 'weekly':
        return day.subtract(Duration(days: day.weekday - 1));
      case 'monthly':
        return DateTime(day.year, day.month, 1);
      case 'yearly':
        return DateTime(day.year, 1, 1);
      case 'one-time':
        return DateTime(instruction.createdAt.year, instruction.createdAt.month, instruction.createdAt.day);
      case 'daily':
      default:
        return day;
    }
  }

  DateTime? _previousInstructionOccurrence(InstructionRule instruction, DateTime occurrence) {
    switch (instruction.repeatType.trim().toLowerCase()) {
      case 'daily':
        return occurrence.subtract(const Duration(days: 1));
      case 'weekly':
        return occurrence.subtract(const Duration(days: 7));
      case 'monthly':
        return DateTime(occurrence.year, occurrence.month - 1, 1);
      case 'yearly':
        return DateTime(occurrence.year - 1, 1, 1);
      default:
        return null;
    }
  }

  int instructionCurrentStreak(InstructionRule instruction, DateTime date) {
    if (!instruction.enabled || !instruction.streakTracking) return 0;
    final followedOccurrences = instruction.history
        .where((entry) => entry.followed)
        .map((entry) => _instructionOccurrenceDate(instruction, entry.date))
        .toSet();
    final currentOccurrence = _instructionOccurrenceDate(instruction, date);
    var cursor = followedOccurrences.contains(currentOccurrence)
        ? currentOccurrence
        : _previousInstructionOccurrence(instruction, currentOccurrence);
    var streak = 0;
    while (cursor != null && followedOccurrences.contains(cursor)) {
      streak++;
      cursor = _previousInstructionOccurrence(instruction, cursor);
    }
    return streak;
  }

  int instructionBestStreak(InstructionRule instruction) {
    final followed = instruction.history
        .where((entry) => entry.followed)
        .map((entry) => _instructionOccurrenceDate(instruction, entry.date))
        .toList()
      ..sort();
    var best = 0;
    var current = 0;
    DateTime? previous;
    for (final occurrence in followed) {
      final expected = previous == null ? null : _previousInstructionOccurrence(instruction, occurrence);
      current = previous != null && expected != null && _isSameDate(expected, previous) ? current + 1 : 1;
      if (current > best) best = current;
      previous = occurrence;
    }
    return best;
  }

  int instructionBonusForDate(DateTime date, {bool standaloneOnly = false}) {
    var total = 0;
    final instructions = standaloneOnly ? getStandaloneInstructions() : getInstructions();
    for (final instruction in instructions) {
      final entry = instructionEntryForDate(instruction, date);
      if (instruction.enabled && entry != null && entry.followed) total += entry.bonusPoints;
    }
    return total;
  }

  String _rewardLedgerKey(String id) => '$_rewardLedgerPrefix$id';
  String _rewardGoalKey(String id) => '$_rewardGoalPrefix$id';

  List<RewardLedgerEntry> getRewardLedgerEntries() {
    final entries = <RewardLedgerEntry>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_rewardLedgerPrefix)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      entries.add(RewardLedgerEntry.fromStorageList(raw.cast<dynamic>()));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  List<RewardGoal> getRewardGoals() {
    final goals = <RewardGoal>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_rewardGoalPrefix)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      goals.add(RewardGoal.fromStorageList(raw.cast<dynamic>()));
    }
    goals.sort((a, b) {
      if (a.isAchieved != b.isAchieved) return a.isAchieved ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return goals;
  }

  RewardMoneySummary getRewardMoneySummary() {
    final totalPoints = getLifetimeProductivityStats().totalPoints;
    final earnedRupees = totalPoints ~/ rewardPointsPerRupee;
    final ledger = getRewardLedgerEntries();
    final withdrawn = ledger
        .where((entry) => entry.type == RewardLedgerEntry.typeWithdrawal)
        .fold<int>(0, (sum, entry) => sum + entry.amountRupees);
    final goalFunded = ledger
        .where((entry) => entry.type == RewardLedgerEntry.typeGoalFunding)
        .fold<int>(0, (sum, entry) => sum + entry.amountRupees);
    return RewardMoneySummary(
      totalPoints: totalPoints,
      earnedRupees: earnedRupees,
      withdrawnRupees: withdrawn,
      goalFundedRupees: goalFunded,
      ledger: ledger,
      goals: getRewardGoals(),
    );
  }

  Future<void> saveRewardGoal(RewardGoal goal) async {
    final existingRaw = _box.get(_rewardGoalKey(goal.id));
    final existing = existingRaw == null ? null : RewardGoal.fromStorageList(existingRaw.cast<dynamic>());
    var updated = _normalizeRewardGoal(goal);
    final history = [...updated.history];
    if (existing == null) {
      history.add(RewardGoalHistoryEntry(date: DateTime.now(), title: 'Goal created', note: updated.name));
    } else {
      if (existing.imagePath != updated.imagePath || existing.galleryImages.length != updated.galleryImages.length) {
        history.add(RewardGoalHistoryEntry(date: DateTime.now(), title: 'Goal image updated'));
      }
      if (existing.effectiveStatus != updated.effectiveStatus) {
        history.add(RewardGoalHistoryEntry(date: DateTime.now(), title: 'Status changed', note: updated.effectiveStatus));
      }
      if (!existing.isAchieved && updated.isAchieved) {
        history.add(RewardGoalHistoryEntry(date: DateTime.now(), title: '🎉 Goal achieved', note: updated.name));
      }
    }
    updated = updated.copyWith(history: history);
    await _box.put(_rewardGoalKey(updated.id), updated.toStorageList());
  }

  Future<void> deleteRewardGoal(String id) async {
    await _box.delete(_rewardGoalKey(id));
  }

  RewardGoal _normalizeRewardGoal(RewardGoal goal) {
    if (goal.targetAmountRupees > 0 && goal.savedAmountRupees >= goal.targetAmountRupees) {
      return goal.copyWith(status: RewardGoal.statusAchieved, completedAt: goal.completedAt ?? DateTime.now());
    }
    return goal;
  }

  Future<void> withdrawRewardMoney({
    required int amountRupees,
    required String reason,
    String goalId = '',
    String goalName = '',
    String note = '',
    DateTime? date,
  }) async {
    final cleanAmount = amountRupees.clamp(0, 1 << 31).toInt();
    if (cleanAmount <= 0) return;
    final summary = getRewardMoneySummary();
    if (cleanAmount > summary.availableRupees) {
      throw ArgumentError('Not enough reward balance available.');
    }
    final entry = RewardLedgerEntry(
      id: 'reward_${DateTime.now().microsecondsSinceEpoch}',
      date: date ?? DateTime.now(),
      type: RewardLedgerEntry.typeWithdrawal,
      amountRupees: cleanAmount,
      reason: reason.trim().isEmpty ? 'Reward used' : reason.trim(),
      goalId: goalId,
      goalName: goalName,
      note: note.trim(),
      balanceAfter: summary.availableRupees - cleanAmount,
    );
    await _box.put(_rewardLedgerKey(entry.id), entry.toStorageList());
  }

  Future<void> fundRewardGoal({
    required RewardGoal goal,
    required int amountRupees,
    String note = '',
  }) async {
    final cleanAmount = amountRupees.clamp(0, 1 << 31).toInt();
    if (cleanAmount <= 0) return;
    final summary = getRewardMoneySummary();
    if (cleanAmount > summary.availableRupees) {
      throw ArgumentError('Not enough reward balance available.');
    }
    final amountToApply = cleanAmount.clamp(0, goal.remainingAmountRupees).toInt();
    if (amountToApply <= 0) return;
    final newSavedAmount = goal.savedAmountRupees + amountToApply;
    final history = [
      ...goal.history,
      RewardGoalHistoryEntry(
        date: DateTime.now(),
        title: '+ ₹$amountToApply added from reward balance',
        amountRupees: amountToApply,
        note: note.trim(),
      ),
      if (goal.targetAmountRupees > 0 && newSavedAmount >= goal.targetAmountRupees && !goal.isAchieved)
        RewardGoalHistoryEntry(date: DateTime.now(), title: '🎉 Goal achieved', note: goal.name),
    ];
    final updatedGoal = _normalizeRewardGoal(
      goal.copyWith(
        savedAmountRupees: newSavedAmount,
        status: goal.targetAmountRupees > 0 && newSavedAmount >= goal.targetAmountRupees ? RewardGoal.statusAchieved : goal.status,
        completedAt: goal.targetAmountRupees > 0 && newSavedAmount >= goal.targetAmountRupees ? (goal.completedAt ?? DateTime.now()) : goal.completedAt,
        history: history,
      ),
    );
    final entry = RewardLedgerEntry(
      id: 'reward_${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime.now(),
      type: RewardLedgerEntry.typeGoalFunding,
      amountRupees: amountToApply,
      reason: 'Added to reward goal',
      goalId: goal.id,
      goalName: goal.name,
      note: note.trim(),
      balanceAfter: summary.availableRupees - amountToApply,
    );
    await _box.put(_rewardGoalKey(updatedGoal.id), updatedGoal.toStorageList());
    await _box.put(_rewardLedgerKey(entry.id), entry.toStorageList());
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
    var timingBonusPoints = 0;
    final completedTaskNames = <String>[];
    final pointEvents = <ProductivityPointEvent>[];

    for (final task in tasks) {
      final phases = task.repeatTask ? const <TaskPhaseInfo>[] : parseTaskPhases(task.description);
      if (phases.isNotEmpty) {
        final completedPhases = phases.where((phase) => phase.isCompleted).toList();
        if (completedPhases.isEmpty) continue;

        var taskBasePoints = 0;
        var taskRecordedMinutes = 0;
        for (final phase in completedPhases) {
          final minutes = phase.recordedMinutes;
          taskRecordedMinutes += minutes;
          taskBasePoints += _productivityPointsForFlags(
            urgent: phase.urgent,
            important: phase.important,
            recordedMinutes: minutes,
          );

          if (phase.urgent && phase.important) {
            bothMinutes += minutes;
          } else if (phase.important) {
            importantMinutes += minutes;
          } else if (phase.urgent) {
            urgentMinutes += minutes;
          } else {
            neitherMinutes += minutes;
          }
        }

        final completedPhaseCount = completedPhases.length;
        projectPhasesCompleted += completedPhaseCount;
        if (_isCompletedTask(task)) completedTasks++;
        completedTaskNames.add('${task.task} ($completedPhaseCount/${phases.length} phases)');

        basePoints += taskBasePoints;
        pointEvents.add(
          ProductivityPointEvent(
            title: '${task.task} Phase Progress',
            basePoints: taskBasePoints,
            streakBonusPoints: 0,
            timingBonusPoints: 0,
            xpBonus: 0,
            totalPoints: taskBasePoints,
            reason: '$completedPhaseCount project phase${completedPhaseCount == 1 ? '' : 's'} completed • ${taskRecordedMinutes} min recorded',
          ),
        );
        continue;
      }

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

      var taskTimingBonusPoints = 0;
      var taskTimingXpBonus = 0;
      if (_isCompletedTask(task)) {
        completedTasks++;
        completedTaskNames.add(task.task);
        if (task.repeatTask) {
          if (!_isDailyJournalTask(task)) routineCompletions++;
          final streak = _routineCompletionStreakForDate(task, day);
          taskBonusPoints = _streakBonusForLength(streak);
          if (taskBonusPoints > 0) {
            reason = '$streak-day streak milestone';
          }

          final timingBonus = _routineTimingBonusForTask(task);
          taskTimingBonusPoints = timingBonus.points;
          taskTimingXpBonus = timingBonus.xp;
          if (taskTimingBonusPoints > 0) {
            reason = reason == 'Base productivity points'
                ? timingBonus.reason
                : '$reason • ${timingBonus.reason}';
          }
        }
      }

      basePoints += taskBasePoints;
      streakBonusPoints += taskBonusPoints;
      timingBonusPoints += taskTimingBonusPoints;
      pointEvents.add(
        ProductivityPointEvent(
          title: task.repeatTask ? '${task.task} Completed' : '${task.task} Completed',
          basePoints: taskBasePoints,
          streakBonusPoints: taskBonusPoints,
          timingBonusPoints: taskTimingBonusPoints,
          xpBonus: taskTimingXpBonus,
          totalPoints: taskBasePoints + taskBonusPoints + taskTimingBonusPoints,
          reason: reason,
        ),
      );
    }

    for (final instruction in getInstructions()) {
      if (!instruction.enabled) continue;
      final entry = instructionEntryForDate(instruction, day);
      if (entry == null || !entry.followed) continue;
      timingBonusPoints += entry.bonusPoints;
      pointEvents.add(
        ProductivityPointEvent(
          title: '✅ Instruction followed: ${instruction.name}',
          basePoints: 0,
          streakBonusPoints: 0,
          timingBonusPoints: entry.bonusPoints,
          xpBonus: entry.xpEarned,
          totalPoints: entry.bonusPoints,
          reason: instruction.description.isEmpty ? 'Instruction bonus' : instruction.description,
        ),
      );
    }

    final bothHours = bothMinutes / 60.0;
    final importantHours = importantMinutes / 60.0;
    final urgentHours = urgentMinutes / 60.0;
    final neitherHours = neitherMinutes / 60.0;
    final totalHours = bothHours + importantHours + urgentHours + neitherHours;
    final totalPoints = basePoints + streakBonusPoints + timingBonusPoints;
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
      timingBonusPoints: timingBonusPoints,
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

  int _productivityPointsForFlags({
    required bool urgent,
    required bool important,
    required int recordedMinutes,
  }) {
    return (recordedMinutes / 60 * _productivityPointRateForFlags(urgent: urgent, important: important)).round();
  }

  int _productivityPointRateForFlags({required bool urgent, required bool important}) {
    if (urgent && important) return 100;
    if (important) return 80;
    if (urgent) return 50;
    return 10;
  }

  int _productivityPointRate(Task task) {
    if (task.urgent && task.important) return 100;
    if (task.important) return 80;
    if (task.urgent) return 50;
    return 10;
  }


  _RoutineTimingBonus _routineTimingBonusForTask(Task task) {
    final schedule = _routineScheduleForTask(task);
    if (schedule == null || !_isCompletedTask(task)) return const _RoutineTimingBonus.none();

    var completed = (task.dueDate.hour * 60) + task.dueDate.minute;
    final start = schedule.startMinutes;
    var end = schedule.endMinutes;
    if (end < start) {
      end += 24 * 60;
      if (completed < start) completed += 24 * 60;
    }

    if (completed < start || completed > end) {
      return const _RoutineTimingBonus.none();
    }

    return _RoutineTimingBonus(
      points: schedule.bonusPoints,
      xp: (schedule.bonusPoints / 4).round(),
      reason: 'On time within ${_formatScheduleMinutes(schedule.startMinutes)}–${_formatScheduleMinutes(schedule.endMinutes)} window',
    );
  }

  _RoutineSchedule? _routineScheduleForTask(Task task) {
    int? start;
    int? end;
    int? bonus;
    int? legacy;

    for (final line in task.description.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith(_scheduleStartMarker)) {
        start = _parseScheduleMinutes(trimmed.substring(_scheduleStartMarker.length).trim());
      } else if (trimmed.startsWith(_scheduleEndMarker)) {
        end = _parseScheduleMinutes(trimmed.substring(_scheduleEndMarker.length).trim());
      } else if (trimmed.startsWith(_scheduleBonusMarker)) {
        bonus = int.tryParse(
          trimmed.substring(_scheduleBonusMarker.length).replaceAll('points', '').trim(),
        );
      } else if (trimmed.startsWith(_legacyScheduledTimeMarker)) {
        legacy = _parseScheduleMinutes(trimmed.substring(_legacyScheduledTimeMarker.length).trim());
      }
    }

    if (start == null && end == null && legacy != null) {
      start = (legacy - 15) % (24 * 60);
      if (start < 0) start += 24 * 60;
      end = (legacy + 15) % (24 * 60);
    }

    if (start == null || end == null) return null;
    return _RoutineSchedule(
      startMinutes: start,
      endMinutes: end,
      bonusPoints: bonus ?? _defaultScheduleBonusPoints,
    );
  }

  int? _parseScheduleMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return (hour * 60) + minute;
  }

  String _formatScheduleMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }


  String? _routineMoodTimelineLine(Task task, DateTime day) {
    if (!task.repeatTask || _isDailyJournalTask(task) || !_isCompletedTask(task)) return null;
    final linkedInstructions = getTaskLinkedInstructions()
        .where((instruction) => instruction.enabled && instruction.isLinkedToTask(task.task))
        .toList();
    if (linkedInstructions.isEmpty) return '😐 ${task.task} steady at Neutral Mood';

    final followed = linkedInstructions.where((instruction) {
      return instructionEntryForDate(instruction, day)?.followed ?? false;
    }).length;
    final ratio = followed / linkedInstructions.length;
    if (ratio >= 1) return '🤩 ${task.task} reached Excellent Mood • all instructions followed';
    if (ratio >= 0.75) return '😄 ${task.task} recovered to Happy Mood • $followed/${linkedInstructions.length} instructions followed';
    if (ratio >= 0.5) return '🙂 ${task.task} reached Good Mood • $followed/${linkedInstructions.length} instructions followed';
    if (followed > 0) return '😐 ${task.task} stayed Neutral • $followed/${linkedInstructions.length} instructions followed';
    return '😕 ${task.task} completed but skipped linked instructions';
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
    final lines = <String>[
      '${_isSameDate(day, DateTime.now()) ? 'Today' : 'Day'} • ${_humanDate(day)}',
    ];

    for (final task in tasks) {
      final status = task.status.trim().toLowerCase();
      final minutes = taskRecordedMinutesForDay(task);
      if (_isCompletedTask(task) && minutes > 0) {
        if (_isDailyJournalTask(task)) {
          lines.add('📔 Daily Journal completed • Reflection saved successfully • +$minutes min');
        } else {
          lines.add(
            '${task.repeatTask ? '✅ Routine' : '✅ Task'} ${task.task} completed • +$minutes min',
          );
          final moodLine = _routineMoodTimelineLine(task, day);
          if (moodLine != null) lines.add(moodLine);
        }
      } else if (task.repeatTask &&
          !_isDailyJournalTask(task) &&
          (status == 'missed' || status == 'overdue' || status == 'cancelled')) {
        lines.add("❌ ${task.task} ${status == 'cancelled' ? 'cancelled' : status}");
        lines.add('😞 ${task.task} missed today');
      }

      for (final phase in parseTaskPhases(task.description).where((phase) => phase.isCompleted)) {
        lines.add('🧩 ${task.task} phase completed: ${phase.name} • +${phase.minutes} min');
      }
    }

    final disabledRoutines = tasks
        .where((task) => task.repeatTask && !_isDailyJournalTask(task) && !task.routineEnabled)
        .length;
    final enabledRoutines = tasks
        .where((task) => task.repeatTask && !_isDailyJournalTask(task) && task.routineEnabled)
        .length;
    if (disabledRoutines > 0) lines.add('⏸️ $disabledRoutines routine${disabledRoutines == 1 ? '' : 's'} disabled');
    if (enabledRoutines > 0) lines.add('🔁 $enabledRoutines routine${enabledRoutines == 1 ? '' : 's'} enabled');

    lines.add('📊 Productivity score: ${snapshot.productivityScore.toStringAsFixed(1)}%');
    lines.add('⭐ Points earned today: +${snapshot.totalPoints}');
    if (snapshot.streakBonusPoints > 0) lines.add('🏆 Streak bonus earned: +${snapshot.streakBonusPoints}');
    if (snapshot.timingBonusPoints > 0) lines.add('⏰ Timing bonus earned: +${snapshot.timingBonusPoints}');
    for (final event in snapshot.pointEvents.where((event) => event.streakBonusPoints > 0 || event.timingBonusPoints > 0)) {
      if (event.streakBonusPoints > 0) {
        lines.add('🔥 ${event.title} • ${event.reason} • +${event.streakBonusPoints} streak bonus points');
      }
      if (event.timingBonusPoints > 0) {
        lines.add('⏰ ${event.title} • ${event.reason} • +${event.timingBonusPoints} timing bonus points • +${event.xpBonus} XP');
      }
    }
    lines.add('💎 Lifetime points: ${lifetime.totalPoints}');
    lines.add('🔥 Streak: ${lifetime.currentStreak} day${lifetime.currentStreak == 1 ? '' : 's'}');
    lines.add('🏅 Lifetime XP: ${lifetime.xp} • Level ${lifetime.level}');

    if (journal != null) {
      lines.add('😊 Mood: ${journal.mood}');
      if (journal.reflection.trim().isNotEmpty) lines.add('📝 Reflection added');
    }
    if (photoCount > 0) lines.add('📷 $photoCount photo${photoCount == 1 ? '' : 's'} attached');

    final hasTaskActivity = tasks.any((task) => !_isDailyJournalTask(task) || _isCompletedTask(task));
    final hasActivity =
        snapshot.totalPoints > 0 || hasTaskActivity || journal != null || manualEntries.isNotEmpty;
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

      final day = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      result[day] = [
        ..._dedupeRecurringTasksForDate(
          tasks.cast<Task>().where((task) => !_isDailyJournalTask(task)).toList(),
        ),
        _dailyJournalTaskForDate(day),
      ];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    result.putIfAbsent(today, () => <Task>[_dailyJournalTaskForDate(today)]);
    for (final journal in getAllJournalEntries()) {
      final day = DateTime(journal.date.year, journal.date.month, journal.date.day);
      result.putIfAbsent(day, () => <Task>[_dailyJournalTaskForDate(day)]);
    }

    return result;
  }

  /// Returns a ValueListenable that rebuilds when the box changes
  ValueListenable<Box<List>> getBoxListenable() {
    return _box.listenable();
  }
}

class _RoutineSchedule {
  final int startMinutes;
  final int endMinutes;
  final int bonusPoints;

  const _RoutineSchedule({
    required this.startMinutes,
    required this.endMinutes,
    required this.bonusPoints,
  });
}

class _RoutineTimingBonus {
  final int points;
  final int xp;
  final String reason;

  const _RoutineTimingBonus({required this.points, required this.xp, required this.reason});

  const _RoutineTimingBonus.none()
      : points = 0,
        xp = 0,
        reason = '';
}
