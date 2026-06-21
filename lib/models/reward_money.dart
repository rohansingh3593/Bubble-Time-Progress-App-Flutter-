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


class RewardGoalImage {
  final String path;
  final String caption;
  final String description;
  final DateTime dateAdded;

  const RewardGoalImage({required this.path, this.caption = '', this.description = '', required this.dateAdded});

  List<dynamic> toStorageList() => [path, caption, description, dateAdded.toIso8601String()];

  factory RewardGoalImage.fromStorageList(List<dynamic> raw) {
    return RewardGoalImage(
      path: raw.isNotEmpty ? '${raw[0]}' : '',
      caption: raw.length > 1 ? '${raw[1]}' : '',
      description: raw.length > 2 ? '${raw[2]}' : '',
      dateAdded: raw.length > 3 ? DateTime.tryParse('${raw[3]}') ?? DateTime.now() : DateTime.now(),
    );
  }
}

class RewardGoalMilestone {
  final String id;
  final int percent;
  final String title;
  final String description;
  final String imagePath;
  final String reward;
  final int bonusPoints;

  const RewardGoalMilestone({required this.id, required this.percent, required this.title, this.description = '', this.imagePath = '', this.reward = '', this.bonusPoints = 0});

  List<dynamic> toStorageList() => [id, percent, title, description, imagePath, reward, bonusPoints];

  factory RewardGoalMilestone.fromStorageList(List<dynamic> raw) {
    return RewardGoalMilestone(
      id: raw.isNotEmpty ? '${raw[0]}' : 'milestone_${DateTime.now().microsecondsSinceEpoch}',
      percent: _readInt(raw, 1),
      title: raw.length > 2 ? '${raw[2]}' : 'Milestone',
      description: raw.length > 3 ? '${raw[3]}' : '',
      imagePath: raw.length > 4 ? '${raw[4]}' : '',
      reward: raw.length > 5 ? '${raw[5]}' : '',
      bonusPoints: _readInt(raw, 6),
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
  final List<RewardGoalImage> images;
  final List<RewardGoalMilestone> milestones;
  final DateTime? startDate;
  final DateTime? completedAt;
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
    this.images = const [],
    this.milestones = const [],
    this.startDate,
    this.completedAt,
    this.description = '',
    this.deadline,
    this.priority = 'Medium',
    required this.createdAt,
    this.category = 'Personal',
    this.status = statusInProgress,
    this.history = const [],
  });

  List<RewardGoalImage> get galleryImages => images.isNotEmpty ? images : (imagePath.isEmpty ? const [] : [RewardGoalImage(path: imagePath, dateAdded: createdAt)]);
  String get coverImagePath => galleryImages.isEmpty ? imagePath : galleryImages.first.path;

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
    List<RewardGoalImage>? images,
    List<RewardGoalMilestone>? milestones,
    DateTime? startDate,
    DateTime? completedAt,
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
      images: images ?? this.images,
      milestones: milestones ?? this.milestones,
      startDate: startDate ?? this.startDate,
      completedAt: completedAt ?? this.completedAt,
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
        galleryImages.map((image) => image.toStorageList()).toList(),
        milestones.map((milestone) => milestone.toStorageList()).toList(),
        startDate?.toIso8601String() ?? '',
        completedAt?.toIso8601String() ?? '',
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
    final parsedImages = <RewardGoalImage>[];
    if (raw.length > 12 && raw[12] is Iterable) {
      for (final image in raw[12] as Iterable) {
        if (image is List) parsedImages.add(RewardGoalImage.fromStorageList(image.cast<dynamic>()));
      }
    }
    final parsedMilestones = <RewardGoalMilestone>[];
    if (raw.length > 13 && raw[13] is Iterable) {
      for (final milestone in raw[13] as Iterable) {
        if (milestone is List) parsedMilestones.add(RewardGoalMilestone.fromStorageList(milestone.cast<dynamic>()));
      }
    }
    return RewardGoal(
      id: raw.isNotEmpty ? '${raw[0]}' : 'goal_${DateTime.now().microsecondsSinceEpoch}',
      name: raw.length > 1 ? '${raw[1]}' : 'Reward Goal',
      targetAmountRupees: _readInt(raw, 2),
      savedAmountRupees: _readInt(raw, 3),
      imagePath: raw.length > 4 ? '${raw[4]}' : '',
      images: parsedImages,
      milestones: parsedMilestones,
      startDate: raw.length > 14 && '${raw[14]}'.trim().isNotEmpty ? DateTime.tryParse('${raw[14]}') : null,
      completedAt: raw.length > 15 && '${raw[15]}'.trim().isNotEmpty ? DateTime.tryParse('${raw[15]}') : null,
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
