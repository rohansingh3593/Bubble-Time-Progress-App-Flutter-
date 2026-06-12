class InstructionHistoryEntry {
  static const String statusFollowed = 'Followed';
  static const String statusMissed = 'Missed';
  static const String statusNotApplicable = 'Not Applicable';

  final DateTime date;
  final String status;
  final int bonusPoints;
  final int xpEarned;
  final String note;

  const InstructionHistoryEntry({
    required this.date,
    required this.status,
    this.bonusPoints = 0,
    this.xpEarned = 0,
    this.note = '',
  });

  bool get followed => status == statusFollowed;
  bool get missed => status == statusMissed;
  bool get notApplicable => status == statusNotApplicable;

  List<dynamic> toStorageList() => [
        date.toIso8601String(),
        status,
        bonusPoints,
        xpEarned,
        note,
      ];

  factory InstructionHistoryEntry.fromStorageList(List<dynamic> raw) {
    return InstructionHistoryEntry(
      date: raw.isNotEmpty ? DateTime.tryParse('${raw[0]}') ?? DateTime.now() : DateTime.now(),
      status: raw.length > 1 ? '${raw[1]}' : statusMissed,
      bonusPoints: _readInt(raw, 2),
      xpEarned: _readInt(raw, 3),
      note: raw.length > 4 ? '${raw[4]}' : '',
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

  final String id;
  final String name;
  final String description;
  final String linkedTask;
  final String linkedPhase;
  final String repeatType;
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
      ];

  factory InstructionRule.fromStorageList(List<dynamic> raw) {
    final parsedHistory = <InstructionHistoryEntry>[];
    if (raw.length > 12 && raw[12] is Iterable) {
      for (final entry in raw[12] as Iterable) {
        if (entry is List) parsedHistory.add(InstructionHistoryEntry.fromStorageList(entry.cast<dynamic>()));
      }
    }
    return InstructionRule(
      id: raw.isNotEmpty ? '${raw[0]}' : 'instruction_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Instruction',
      description: raw.length > 2 ? '${raw[2]}' : '',
      linkedTask: raw.length > 3 ? '${raw[3]}' : '',
      linkedPhase: raw.length > 4 ? '${raw[4]}' : '',
      repeatType: raw.length > 5 ? '${raw[5]}' : repeatDaily,
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
