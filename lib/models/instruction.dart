class InstructionHistoryEntry {
  static const String statusFollowed = 'Followed';
  static const String statusMissed = 'Missed';
  static const String statusNotApplicable = 'Not Applicable';

  final DateTime date;
  final String status;
  final int bonusPoints;
  final int xpEarned;
  final String note;
  final String levelId;
  final String levelName;
  final double completedTarget;
  final String unit;
  final String optionId;
  final String optionName;
  final String optionEmoji;

  const InstructionHistoryEntry({
    required this.date,
    required this.status,
    this.bonusPoints = 0,
    this.xpEarned = 0,
    this.note = '',
    this.levelId = '',
    this.levelName = '',
    this.completedTarget = 0,
    this.unit = '',
    this.optionId = '',
    this.optionName = '',
    this.optionEmoji = '',
  });

  bool get followed => status == statusFollowed;
  bool get missed => status == statusMissed;
  bool get notApplicable => status == statusNotApplicable;
  bool get hasLevel => levelId.isNotEmpty;
  bool get hasOption => optionId.isNotEmpty;

  String get levelSummary {
    if (!hasLevel) return '';
    final targetText = completedTarget % 1 == 0 ? completedTarget.toStringAsFixed(0) : completedTarget.toStringAsFixed(1);
    return '$levelName - $targetText $unit'.trim();
  }

  String get optionSummary => hasOption ? '$optionEmoji $optionName'.trim() : '';
  String get selectionSummary => hasOption ? optionSummary : levelSummary;

  List<dynamic> toStorageList() => [
        date.toIso8601String(),
        status,
        bonusPoints,
        xpEarned,
        note,
        levelId,
        levelName,
        completedTarget,
        unit,
        optionId,
        optionName,
        optionEmoji,
      ];

  factory InstructionHistoryEntry.fromStorageList(List<dynamic> raw) {
    return InstructionHistoryEntry(
      date: raw.isNotEmpty ? DateTime.tryParse('${raw[0]}') ?? DateTime.now() : DateTime.now(),
      status: raw.length > 1 ? '${raw[1]}' : statusMissed,
      bonusPoints: _readInt(raw, 2),
      xpEarned: _readInt(raw, 3),
      note: raw.length > 4 ? '${raw[4]}' : '',
      levelId: raw.length > 5 ? '${raw[5]}' : '',
      levelName: raw.length > 6 ? '${raw[6]}' : '',
      completedTarget: _readDouble(raw, 7),
      unit: raw.length > 8 ? '${raw[8]}' : '',
      optionId: raw.length > 9 ? '${raw[9]}' : '',
      optionName: raw.length > 10 ? '${raw[10]}' : '',
      optionEmoji: raw.length > 11 ? '${raw[11]}' : '',
    );
  }
}

class InstructionLevel {
  final String id;
  final String name;
  final double target;
  final String unit;
  final int bonusPoints;
  final int xpEarned;

  const InstructionLevel({
    required this.id,
    required this.name,
    required this.target,
    required this.unit,
    required this.bonusPoints,
    required this.xpEarned,
  });

  String get targetLabel {
    final targetText = target % 1 == 0 ? target.toStringAsFixed(0) : target.toStringAsFixed(1);
    return '$targetText $unit'.trim();
  }

  String get displayLabel => '$name - $targetLabel';

  List<dynamic> toStorageList() => [id, name, target, unit, bonusPoints, xpEarned];

  factory InstructionLevel.fromStorageList(List<dynamic> raw) {
    return InstructionLevel(
      id: raw.isNotEmpty ? '${raw[0]}' : 'level_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Level',
      target: _readDouble(raw, 2),
      unit: raw.length > 3 ? '${raw[3]}' : '',
      bonusPoints: _readInt(raw, 4),
      xpEarned: _readInt(raw, 5),
    );
  }
}


class InstructionOption {
  final String id;
  final String name;
  final int bonusPoints;
  final int xpEarned;
  final String emoji;
  final String description;

  const InstructionOption({
    required this.id,
    required this.name,
    required this.bonusPoints,
    required this.xpEarned,
    this.emoji = '🥤',
    this.description = '',
  });

  String get displayLabel => '$emoji $name'.trim();

  List<dynamic> toStorageList() => [id, name, bonusPoints, xpEarned, emoji, description];

  factory InstructionOption.fromStorageList(List<dynamic> raw) {
    return InstructionOption(
      id: raw.isNotEmpty ? '${raw[0]}' : 'option_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Option',
      bonusPoints: _readInt(raw, 2),
      xpEarned: _readInt(raw, 3),
      emoji: raw.length > 4 ? '${raw[4]}' : '🥤',
      description: raw.length > 5 ? '${raw[5]}' : '',
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
  final int xpEarned;
  final int colorValue;
  final bool enabled;
  final bool streakTracking;
  final DateTime createdAt;
  final List<InstructionHistoryEntry> history;

  const InstructionRule({
    required this.id,
    required this.name,
    this.description = '',
    this.linkedTask = '',
    this.linkedPhase = '',
    this.repeatType = repeatDaily,
    this.instructionType = typeSimple,
    this.unit = '',
    this.levels = const [],
    this.options = const [],
    this.archived = false,
    this.bonusPoints = 20,
    this.xpEarned = 5,
    this.colorValue = 0xFF43A047,
    this.enabled = true,
    this.streakTracking = true,
    required this.createdAt,
    this.history = const [],
  });

  List<String> get linkedTasks => splitLinks(linkedTask);

  List<String> get linkedPhases => splitLinks(linkedPhase);

  bool get isTaskLinked => linkedTasks.isNotEmpty || linkedPhases.isNotEmpty;

  bool get isStandalone => !isTaskLinked;
  bool get isLevelBased => instructionType == typeLevelBased;
  bool get isOptionBased => instructionType == typeOptionBased;
  bool get isSimple => !isLevelBased && !isOptionBased;

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
    int? xpEarned,
    int? colorValue,
    bool? enabled,
    bool? streakTracking,
    List<InstructionHistoryEntry>? history,
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
      xpEarned: xpEarned ?? this.xpEarned,
      colorValue: colorValue ?? this.colorValue,
      enabled: enabled ?? this.enabled,
      streakTracking: streakTracking ?? this.streakTracking,
      createdAt: createdAt,
      history: history ?? this.history,
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
        xpEarned,
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
      instructionType: raw.length > 13 ? '${raw[13]}' : typeSimple,
      unit: raw.length > 14 ? '${raw[14]}' : '',
      levels: parsedLevels,
      options: parsedOptions,
      archived: raw.length > 17 ? raw[17] == true || '${raw[17]}'.toLowerCase() == 'true' : false,
      bonusPoints: _readInt(raw, 6, fallback: 20),
      xpEarned: _readInt(raw, 7, fallback: 5),
      colorValue: _readInt(raw, 8, fallback: 0xFF43A047),
      enabled: raw.length > 9 ? raw[9] == true || '${raw[9]}'.toLowerCase() == 'true' : true,
      streakTracking: raw.length > 10 ? raw[10] == true || '${raw[10]}'.toLowerCase() == 'true' : true,
      createdAt: raw.length > 11 ? DateTime.tryParse('${raw[11]}') ?? DateTime.now() : DateTime.now(),
      history: parsedHistory,
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
