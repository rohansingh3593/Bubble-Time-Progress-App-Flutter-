class InstructionHistoryEntry {
  static const String statusFollowed = 'Followed';
  static const String statusMissed = 'Missed';
  static const String statusNotApplicable = 'Not Applicable';

  final DateTime date;
  final String status;
  final int bonusPoints;
  final int pointsEarned;
  final String note;
  final String levelId;
  final String levelName;
  final double completedTarget;
  final String unit;
  final String optionId;
  final String optionName;
  final String optionEmoji;
  final List<InstructionOption> selectedOptions;

  const InstructionHistoryEntry({
    required this.date,
    required this.status,
    this.bonusPoints = 0,
    this.pointsEarned = 0,
    this.note = '',
    this.levelId = '',
    this.levelName = '',
    this.completedTarget = 0,
    this.unit = '',
    this.optionId = '',
    this.optionName = '',
    this.optionEmoji = '',
    this.selectedOptions = const [],
  });

  bool get followed => status == statusFollowed;
  bool get missed => status == statusMissed;
  bool get notApplicable => status == statusNotApplicable;
  bool get hasLevel => levelId.isNotEmpty;
  bool get hasOption => optionId.isNotEmpty || selectedOptions.isNotEmpty;
  int get selectedOptionCount => selectedOptions.isNotEmpty ? selectedOptions.length : (optionId.isNotEmpty ? 1 : 0);

  String get levelSummary {
    if (!hasLevel) return '';
    final targetText = completedTarget % 1 == 0 ? completedTarget.toStringAsFixed(0) : completedTarget.toStringAsFixed(1);
    return '$levelName - $targetText $unit'.trim();
  }

  String get optionSummary {
    if (selectedOptions.isNotEmpty) {
      return selectedOptions.map((option) => '${option.emoji} ${option.name}'.trim()).join(', ');
    }
    return optionId.isNotEmpty ? '$optionEmoji $optionName'.trim() : '';
  }

  String get selectionSummary => hasOption ? optionSummary : levelSummary;

  double selectedPercentage(int totalOptions) => totalOptions <= 0 ? 0 : (selectedOptionCount / totalOptions) * 100;

  String progressEmoji(int totalOptions) {
    if (missed) return '😞';
    final percent = selectedPercentage(totalOptions);
    if (percent >= 100) return '🤩';
    if (percent >= 75) return '😄';
    if (percent >= 50) return '😊';
    if (percent >= 25) return '🙂';
    return '😐';
  }

  List<dynamic> toStorageList() => [
        date.toIso8601String(),
        status,
        bonusPoints,
        pointsEarned,
        note,
        levelId,
        levelName,
        completedTarget,
        unit,
        optionId,
        optionName,
        optionEmoji,
        selectedOptions.map((option) => option.toStorageList()).toList(),
      ];

  factory InstructionHistoryEntry.fromStorageList(List<dynamic> raw) {
    return InstructionHistoryEntry(
      date: raw.isNotEmpty ? DateTime.tryParse('${raw[0]}') ?? DateTime.now() : DateTime.now(),
      status: raw.length > 1 ? '${raw[1]}' : statusMissed,
      bonusPoints: _readInt(raw, 2),
      pointsEarned: _readInt(raw, 3),
      note: raw.length > 4 ? '${raw[4]}' : '',
      levelId: raw.length > 5 ? '${raw[5]}' : '',
      levelName: raw.length > 6 ? '${raw[6]}' : '',
      completedTarget: _readDouble(raw, 7),
      unit: raw.length > 8 ? '${raw[8]}' : '',
      optionId: raw.length > 9 ? '${raw[9]}' : '',
      optionName: raw.length > 10 ? '${raw[10]}' : '',
      optionEmoji: raw.length > 11 ? '${raw[11]}' : '',
      selectedOptions: _readOptions(raw, 12),
    );
  }
}

class InstructionLevel {
  final String id;
  final String name;
  final double target;
  final String unit;
  final int bonusPoints;
  final int pointsEarned;

  const InstructionLevel({
    required this.id,
    required this.name,
    required this.target,
    required this.unit,
    required this.bonusPoints,
    required this.pointsEarned,
  });

  String get targetLabel {
    final targetText = target % 1 == 0 ? target.toStringAsFixed(0) : target.toStringAsFixed(1);
    return '$targetText $unit'.trim();
  }

  String get displayLabel => '$name - $targetLabel';

  List<dynamic> toStorageList() => [id, name, target, unit, bonusPoints, pointsEarned];

  factory InstructionLevel.fromStorageList(List<dynamic> raw) {
    return InstructionLevel(
      id: raw.isNotEmpty ? '${raw[0]}' : 'level_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Level',
      target: _readDouble(raw, 2),
      unit: raw.length > 3 ? '${raw[3]}' : '',
      bonusPoints: _readInt(raw, 4),
      pointsEarned: _readInt(raw, 5),
    );
  }
}


class InstructionOption {
  final String id;
  final String name;
  final int bonusPoints;
  final int pointsEarned;
  final String emoji;
  final String description;
  final List<String> imagePaths;
  final String coverImagePath;
  final String linkUrl;
  final List<String> linkUrls;

  const InstructionOption({
    required this.id,
    required this.name,
    required this.bonusPoints,
    required this.pointsEarned,
    this.emoji = '🥤',
    this.description = '',
    this.imagePaths = const [],
    this.coverImagePath = '',
    this.linkUrl = '',
    this.linkUrls = const [],
  });

  String get displayLabel => '$emoji $name'.trim();
  String get activeCoverImage => coverImagePath.isNotEmpty ? coverImagePath : (imagePaths.isNotEmpty ? imagePaths.first : '');
  List<String> get effectiveLinks {
    final links = <String>[];
    for (final link in [linkUrl, ...linkUrls]) {
      final trimmed = link.trim();
      if (trimmed.isNotEmpty && !links.contains(trimmed)) links.add(trimmed);
    }
    return links;
  }

  bool get hasLink => effectiveLinks.isNotEmpty;

  List<dynamic> toStorageList() => [id, name, bonusPoints, pointsEarned, emoji, description, imagePaths, coverImagePath, linkUrl, linkUrls];

  factory InstructionOption.fromStorageList(List<dynamic> raw) {
    return InstructionOption(
      id: raw.isNotEmpty ? '${raw[0]}' : 'option_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Option',
      bonusPoints: _readInt(raw, 2),
      pointsEarned: _readInt(raw, 3),
      emoji: raw.length > 4 ? '${raw[4]}' : '🥤',
      description: raw.length > 5 ? '${raw[5]}' : '',
      imagePaths: _readStringList(raw, 6),
      coverImagePath: raw.length > 7 ? '${raw[7]}' : '',
      linkUrl: raw.length > 8 ? '${raw[8]}' : '',
      linkUrls: _readStringList(raw, 9),
    );
  }
}
class InstructionRule {
  static const String repeatDaily = 'Daily';
  static const String repeatWeekly = 'Weekly';
  static const String repeatMonthly = 'Monthly';
  static const String repeatYearly = 'Yearly';
  static const String repeatOneTime = 'One-Time';

  static const String linkDelimiter = '|||';
  static const String typeMultipleOption = 'Multiple Option Instruction';
  static const String typeHowItWorks = 'How It Works';
  static const String typeSimple = 'Simple';
  static const String typeLevelBased = 'Level-Based';
  static const String typeOptionBased = 'Option-Based';

  final String id;
  final String name;
  final String description;
  final String linkedTask;
  final String linkedPhase;
  final String repeatType;
  final String instructionType;
  final String unit;
  final List<InstructionLevel> levels;
  final List<InstructionOption> options;
  final bool archived;
  final int bonusPoints;
  final int pointsEarned;
  final int colorValue;
  final bool enabled;
  final bool streakTracking;
  final DateTime createdAt;
  final List<InstructionHistoryEntry> history;
  final List<String> imagePaths;
  final String coverImagePath;

  const InstructionRule({
    required this.id,
    required this.name,
    this.description = '',
    this.linkedTask = '',
    this.linkedPhase = '',
    this.repeatType = repeatDaily,
    this.instructionType = typeMultipleOption,
    this.unit = '',
    this.levels = const [],
    this.options = const [],
    this.archived = false,
    this.bonusPoints = 20,
    this.pointsEarned = 5,
    this.colorValue = 0xFF43A047,
    this.enabled = true,
    this.streakTracking = true,
    required this.createdAt,
    this.history = const [],
    this.imagePaths = const [],
    this.coverImagePath = '',
  });

  List<String> get linkedTasks => splitLinks(linkedTask);

  List<String> get linkedPhases => splitLinks(linkedPhase);

  bool get isTaskLinked => linkedTasks.isNotEmpty || linkedPhases.isNotEmpty;

  bool get isStandalone => !isTaskLinked;
  bool get isLevelBased => false;
  bool get isOptionBased => true;
  bool get isSimple => false;
  int get totalOptionCount => options.length;
  String get activeCoverImage => coverImagePath.isNotEmpty ? coverImagePath : (imagePaths.isNotEmpty ? imagePaths.first : '');

  static String normalizeInstructionType(String value) => typeMultipleOption;

  bool isLinkedToTask(String taskName) {
    final normalizedTaskName = _normalizeLink(taskName);
    if (normalizedTaskName.isEmpty) return false;
    return linkedTasks.any((task) => _normalizeLink(task) == normalizedTaskName);
  }

  static String encodeLinks(Iterable<String> values) {
    final unique = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final normalized = _normalizeLink(trimmed);
      if (seen.add(normalized)) unique.add(trimmed);
    }
    return unique.join(linkDelimiter);
  }

  static List<String> splitLinks(String raw) {
    final normalizedRaw = raw.trim();
    if (normalizedRaw.isEmpty) return const <String>[];
    final separator = normalizedRaw.contains(linkDelimiter) ? linkDelimiter : ',';
    final parts = normalizedRaw.split(separator);
    final unique = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final normalized = _normalizeLink(trimmed);
      if (seen.add(normalized)) unique.add(trimmed);
    }
    return unique;
  }

  InstructionRule copyWith({
    String? name,
    String? description,
    String? linkedTask,
    String? linkedPhase,
    String? repeatType,
    String? instructionType,
    String? unit,
    List<InstructionLevel>? levels,
    List<InstructionOption>? options,
    bool? archived,
    int? bonusPoints,
    int? pointsEarned,
    int? colorValue,
    bool? enabled,
    bool? streakTracking,
    List<InstructionHistoryEntry>? history,
    List<String>? imagePaths,
    String? coverImagePath,
  }) {
    return InstructionRule(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      linkedTask: linkedTask ?? this.linkedTask,
      linkedPhase: linkedPhase ?? this.linkedPhase,
      repeatType: repeatType ?? this.repeatType,
      instructionType: instructionType ?? this.instructionType,
      unit: unit ?? this.unit,
      levels: levels ?? this.levels,
      options: options ?? this.options,
      archived: archived ?? this.archived,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      colorValue: colorValue ?? this.colorValue,
      enabled: enabled ?? this.enabled,
      streakTracking: streakTracking ?? this.streakTracking,
      createdAt: createdAt,
      history: history ?? this.history,
      imagePaths: imagePaths ?? this.imagePaths,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }

  List<dynamic> toStorageList() => [
        id,
        name,
        description,
        linkedTask,
        linkedPhase,
        repeatType,
        bonusPoints,
        pointsEarned,
        colorValue,
        enabled,
        streakTracking,
        createdAt.toIso8601String(),
        history.map((entry) => entry.toStorageList()).toList(),
        instructionType,
        unit,
        levels.map((level) => level.toStorageList()).toList(),
        options.map((option) => option.toStorageList()).toList(),
        archived,
        imagePaths,
        coverImagePath,
      ];

  factory InstructionRule.fromStorageList(List<dynamic> raw) {
    final parsedHistory = <InstructionHistoryEntry>[];
    if (raw.length > 12 && raw[12] is Iterable) {
      for (final entry in raw[12] as Iterable) {
        if (entry is List) parsedHistory.add(InstructionHistoryEntry.fromStorageList(entry.cast<dynamic>()));
      }
    }
    final parsedLevels = <InstructionLevel>[];
    if (raw.length > 15 && raw[15] is Iterable) {
      for (final level in raw[15] as Iterable) {
        if (level is List) parsedLevels.add(InstructionLevel.fromStorageList(level.cast<dynamic>()));
      }
    }
    final parsedOptions = <InstructionOption>[];
    if (raw.length > 16 && raw[16] is Iterable) {
      for (final option in raw[16] as Iterable) {
        if (option is List) parsedOptions.add(InstructionOption.fromStorageList(option.cast<dynamic>()));
      }
    }
    return InstructionRule(
      id: raw.isNotEmpty ? '${raw[0]}' : 'instruction_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Instruction',
      description: raw.length > 2 ? '${raw[2]}' : '',
      linkedTask: raw.length > 3 ? '${raw[3]}' : '',
      linkedPhase: raw.length > 4 ? '${raw[4]}' : '',
      repeatType: raw.length > 5 ? '${raw[5]}' : repeatDaily,
      instructionType: normalizeInstructionType(raw.length > 13 ? '${raw[13]}' : typeMultipleOption),
      unit: raw.length > 14 ? '${raw[14]}' : '',
      levels: parsedLevels,
      options: parsedOptions,
      archived: raw.length > 17 ? raw[17] == true || '${raw[17]}'.toLowerCase() == 'true' : false,
      bonusPoints: _readInt(raw, 6, fallback: 20),
      pointsEarned: _readInt(raw, 7, fallback: 5),
      colorValue: _readInt(raw, 8, fallback: 0xFF43A047),
      enabled: raw.length > 9 ? raw[9] == true || '${raw[9]}'.toLowerCase() == 'true' : true,
      streakTracking: raw.length > 10 ? raw[10] == true || '${raw[10]}'.toLowerCase() == 'true' : true,
      createdAt: raw.length > 11 ? DateTime.tryParse('${raw[11]}') ?? DateTime.now() : DateTime.now(),
      history: parsedHistory,
      imagePaths: _readStringList(raw, 18),
      coverImagePath: raw.length > 19 ? '${raw[19]}' : '',
    );
  }
}

String _normalizeLink(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

int _readInt(List<dynamic> raw, int index, {int fallback = 0}) {
  if (raw.length <= index) return fallback;
  final value = raw[index];
  if (value is num) return value.round();
  return int.tryParse('$value') ?? fallback;
}


double _readDouble(List<dynamic> raw, int index, {double fallback = 0}) {
  if (raw.length <= index) return fallback;
  final value = raw[index];
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

List<InstructionOption> _readOptions(List<dynamic> raw, int index) {
  if (raw.length <= index || raw[index] is! Iterable) return const <InstructionOption>[];
  final options = <InstructionOption>[];
  for (final option in raw[index] as Iterable) {
    if (option is List) options.add(InstructionOption.fromStorageList(option.cast<dynamic>()));
  }
  return options;
}

List<String> _readStringList(List<dynamic> raw, int index) {
  if (raw.length <= index || raw[index] is! Iterable) return const <String>[];
  return (raw[index] as Iterable).map((item) => '$item').where((item) => item.trim().isNotEmpty).toList();
}
