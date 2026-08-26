class LogRewardMilestone {
  final int qualifyingDays;
  final int coins;

  const LogRewardMilestone(this.qualifyingDays, this.coins);
}

/// Product policy for the Log & Earn presentation. Keeping this outside the
/// widget makes milestone changes independent of the dashboard layout.
abstract final class LogRewardPolicy {
  static const milestones = <LogRewardMilestone>[
    LogRewardMilestone(3, 100),
    LogRewardMilestone(7, 250),
    LogRewardMilestone(14, 600),
    LogRewardMilestone(30, 1500),
  ];

  static LogRewardMilestone nextMilestone(int qualifyingDays) =>
      milestones.firstWhere(
        (milestone) => milestone.qualifyingDays > qualifyingDays,
        orElse: () => milestones.last,
      );
}
