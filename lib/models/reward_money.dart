const int rewardPointsPerRupee = 10;

class RewardLedgerEntry {
  static const String typeWithdrawal = 'withdrawal';
  static const String typeGoalFunding = 'goalFunding';
  static const String typeManualAdjustment = 'manualAdjustment';

  final String id;
  final DateTime date;
  final String type;
  final int amountRupees;
  final String reason;
  final String goalId;
  final String goalName;
  final String note;
  final int balanceAfter;

  const RewardLedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.amountRupees,
    required this.reason,
    this.goalId = '',
    this.goalName = '',
    this.note = '',
    this.balanceAfter = 0,
  });

  List<dynamic> toStorageList() => [
        id,
        date.toIso8601String(),
        type,
        amountRupees,
        reason,
        goalId,
        goalName,
        note,
        balanceAfter,
      ];

  factory RewardLedgerEntry.fromStorageList(List<dynamic> raw) {
    return RewardLedgerEntry(
      id: raw.isNotEmpty ? '${raw[0]}' : 'reward_${DateTime.now().microsecondsSinceEpoch}',
      date: raw.length > 1 ? DateTime.tryParse('${raw[1]}') ?? DateTime.now() : DateTime.now(),
      type: raw.length > 2 ? '${raw[2]}' : typeWithdrawal,
      amountRupees: _readInt(raw, 3),
      reason: raw.length > 4 ? '${raw[4]}' : '',
      goalId: raw.length > 5 ? '${raw[5]}' : '',
      goalName: raw.length > 6 ? '${raw[6]}' : '',
      note: raw.length > 7 ? '${raw[7]}' : '',
      balanceAfter: _readInt(raw, 8),
    );
  }
}

class RewardGoalHistoryEntry {
  final DateTime date;
  final String title;
  final String note;
  final int amountRupees;

  const RewardGoalHistoryEntry({
    required this.date,
    required this.title,
    this.note = '',
    this.amountRupees = 0,
  });

  List<dynamic> toStorageList() => [
        date.toIso8601String(),
        title,
        note,
        amountRupees,
      ];

  factory RewardGoalHistoryEntry.fromStorageList(List<dynamic> raw) {
    return RewardGoalHistoryEntry(
      date: raw.isNotEmpty ? DateTime.tryParse('${raw[0]}') ?? DateTime.now() : DateTime.now(),
      title: raw.length > 1 ? '${raw[1]}' : 'Goal updated',
      note: raw.length > 2 ? '${raw[2]}' : '',
      amountRupees: _readInt(raw, 3),
    );
  }
}

class RewardGoal {
  static const String statusInProgress = 'In Progress';
  static const String statusAchieved = 'Achieved';
  static const String statusPaused = 'Paused';
  static const String statusCancelled = 'Cancelled';

  final String id;
  final String name;
  final int targetAmountRupees;
  final int savedAmountRupees;
  final String imagePath;
  final String description;
  final DateTime? deadline;
  final String priority;
  final DateTime createdAt;
  final String category;
  final String status;
  final List<RewardGoalHistoryEntry> history;

  const RewardGoal({
    required this.id,
    required this.name,
    required this.targetAmountRupees,
    this.savedAmountRupees = 0,
    this.imagePath = '',
    this.description = '',
    this.deadline,
    this.priority = 'Medium',
    required this.createdAt,
    this.category = 'Personal',
    this.status = statusInProgress,
    this.history = const [],
  });

  int get remainingAmountRupees => (targetAmountRupees - savedAmountRupees).clamp(0, targetAmountRupees).toInt();
  double get progress => targetAmountRupees <= 0 ? 0 : (savedAmountRupees / targetAmountRupees).clamp(0, 1).toDouble();
  bool get isCompleted => targetAmountRupees > 0 && savedAmountRupees >= targetAmountRupees;
  bool get isAchieved => status == statusAchieved || isCompleted;
  String get effectiveStatus => isAchieved ? statusAchieved : status;

  RewardGoal copyWith({
    String? name,
    int? targetAmountRupees,
    int? savedAmountRupees,
    String? imagePath,
    String? description,
    DateTime? deadline,
    bool clearDeadline = false,
    String? priority,
    String? category,
    String? status,
    List<RewardGoalHistoryEntry>? history,
  }) {
    return RewardGoal(
      id: id,
      name: name ?? this.name,
      targetAmountRupees: targetAmountRupees ?? this.targetAmountRupees,
      savedAmountRupees: savedAmountRupees ?? this.savedAmountRupees,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      priority: priority ?? this.priority,
      createdAt: createdAt,
      category: category ?? this.category,
      status: status ?? this.status,
      history: history ?? this.history,
    );
  }

  List<dynamic> toStorageList() => [
        id,
        name,
        targetAmountRupees,
        savedAmountRupees,
        imagePath,
        description,
        deadline?.toIso8601String() ?? '',
        priority,
        createdAt.toIso8601String(),
        category,
        effectiveStatus,
        history.map((entry) => entry.toStorageList()).toList(),
      ];

  factory RewardGoal.fromStorageList(List<dynamic> raw) {
    final parsedHistory = <RewardGoalHistoryEntry>[];
    if (raw.length > 11 && raw[11] is Iterable) {
      for (final entry in raw[11] as Iterable) {
        if (entry is List) {
          parsedHistory.add(RewardGoalHistoryEntry.fromStorageList(entry.cast<dynamic>()));
        }
      }
    }
    return RewardGoal(
      id: raw.isNotEmpty ? '${raw[0]}' : 'goal_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Reward Goal',
      targetAmountRupees: _readInt(raw, 2),
      savedAmountRupees: _readInt(raw, 3),
      imagePath: raw.length > 4 ? '${raw[4]}' : '',
      description: raw.length > 5 ? '${raw[5]}' : '',
      deadline: raw.length > 6 && '${raw[6]}'.trim().isNotEmpty ? DateTime.tryParse('${raw[6]}') : null,
      priority: raw.length > 7 ? '${raw[7]}' : 'Medium',
      createdAt: raw.length > 8 ? DateTime.tryParse('${raw[8]}') ?? DateTime.now() : DateTime.now(),
      category: raw.length > 9 ? '${raw[9]}' : 'Personal',
      status: raw.length > 10 ? '${raw[10]}' : statusInProgress,
      history: parsedHistory,
    );
  }
}

class RewardMoneySummary {
  final int totalPoints;
  final int earnedRupees;
  final int withdrawnRupees;
  final int goalFundedRupees;
  final List<RewardLedgerEntry> ledger;
  final List<RewardGoal> goals;

  const RewardMoneySummary({
    required this.totalPoints,
    required this.earnedRupees,
    required this.withdrawnRupees,
    required this.goalFundedRupees,
    required this.ledger,
    required this.goals,
  });

  int get usedRupees => withdrawnRupees + goalFundedRupees;
  int get availableRupees => (earnedRupees - usedRupees).clamp(0, earnedRupees).toInt();
}

int _readInt(List<dynamic> raw, int index) {
  if (raw.length <= index) return 0;
  final value = raw[index];
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}
