import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/colors.dart';
import '../models/productivity_snapshot.dart';
import '../models/reward_money.dart';
import '../models/rank_profile.dart';
import '../models/user_profile.dart';
import '../services/hive_service.dart';
import '../utils/path_image.dart';
import '../widgets/profile_avatar.dart';

class ProductivityTimelineView extends StatefulWidget {
  final HiveService hiveService;

  const ProductivityTimelineView({super.key, required this.hiveService});

  @override
  State<ProductivityTimelineView> createState() => _ProductivityTimelineViewState();
}

class _ProductivityTimelineViewState extends State<ProductivityTimelineView> {
  String _range = 'Last 30 Days';
  Timer? _rewardReminderTimer;
  int _rewardReminderIndex = 0;
  DateTime? _rewardReminderSnoozedUntil;

  @override
  void initState() {
    super.initState();
    _rewardReminderTimer = Timer.periodic(const Duration(minutes: 30), (_) => _showRewardGoalReminder());
  }

  @override
  void dispose() {
    _rewardReminderTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Productivity Timeline', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final snapshots = widget.hiveService.getProductivitySnapshots();
          final stats = widget.hiveService.getLifetimeProductivityStats();
          final username = widget.hiveService.getUsername();
          final userProfile = widget.hiveService.getUserProfile();
          final filtered = _filterSnapshots(snapshots, _range);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _LifetimePerformanceCard(username: username, stats: stats, userProfile: userProfile, hiveService: widget.hiveService),
              const SizedBox(height: 16),
              _RewardMoneyCard(hiveService: widget.hiveService),
              const SizedBox(height: 16),
              _PhotoGalleryCard(userProfile: userProfile, hiveService: widget.hiveService),
              const SizedBox(height: 16),
              _PointsTotalsCard(snapshots: snapshots, stats: stats),
              const SizedBox(height: 16),
              _PointsAnalyticsCard(snapshots: snapshots),
              const SizedBox(height: 16),
              _OverviewCards(stats: stats),
              const SizedBox(height: 16),
              _TrendCard(
                snapshots: filtered,
                selectedRange: _range,
                onRangeChanged: (value) => setState(() => _range = value),
              ),
              const SizedBox(height: 16),
              _HeatMapCard(
                snapshots: snapshots,
                onTapSnapshot: _showSnapshotDetails,
              ),
              const SizedBox(height: 16),
              _ReportsCard(snapshots: snapshots),
              const SizedBox(height: 16),
              _HistoryList(snapshots: snapshots.reversed.toList(), onTapSnapshot: _showSnapshotDetails),
            ],
          );
        },
      ),
    );
  }


  void _showRewardGoalReminder() {
    if (!mounted) return;
    final snoozedUntil = _rewardReminderSnoozedUntil;
    if (snoozedUntil != null && DateTime.now().isBefore(snoozedUntil)) return;
    final activeGoals = widget.hiveService.getRewardGoals().where((goal) => !goal.isCompleted).toList();
    if (activeGoals.isEmpty) return;
    final goal = activeGoals[_rewardReminderIndex % activeGoals.length];
    _rewardReminderIndex++;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🎯 Your Goal: ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved: ${_formatRupees(goal.savedAmountRupees)} / ${_formatRupees(goal.targetAmountRupees)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: goal.progress, minHeight: 10),
            const SizedBox(height: 12),
            const Text('Keep going. Complete one more task and move closer to your reward.', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _rewardReminderSnoozedUntil = DateTime.now().add(const Duration(hours: 1));
              Navigator.pop(context);
            },
            child: const Text('Snooze 1 hour'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss')),
        ],
      ),
    );
  }

  List<ProductivitySnapshot> _filterSnapshots(List<ProductivitySnapshot> snapshots, String range) {
    if (range == 'All Time') return snapshots;
    final now = DateTime.now();
    final days = switch (range) {
      'Last 7 Days' => 7,
      'Last 90 Days' => 90,
      'Last Year' => 365,
      _ => 30,
    };
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    return snapshots.where((snapshot) => !snapshot.date.isBefore(cutoff)).toList();
  }

  void _showSnapshotDetails(ProductivitySnapshot snapshot) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_formatDate(snapshot.date)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailLine('Total Hours', _formatHours(snapshot.totalHours)),
              _detailLine('Both', _formatHours(snapshot.bothHours)),
              _detailLine('Important', _formatHours(snapshot.importantHours)),
              _detailLine('Urgent', _formatHours(snapshot.urgentHours)),
              _detailLine('Neither', _formatHours(snapshot.neitherHours)),
              _detailLine('Base Points', '+${snapshot.basePoints}'),
              _detailLine('Streak Bonus', '+${snapshot.streakBonusPoints}'),
              _detailLine('Total Points', '${snapshot.totalPoints} / ${ProductivitySnapshot.maximumPoints.round()}'),
              _detailLine('Productivity', '${snapshot.productivityScore.toStringAsFixed(1)}%'),
              _detailLine('Rating', snapshot.rating),
              const SizedBox(height: 12),
              const Text('Points history', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              if (snapshot.pointEvents.isEmpty)
                const Text('No point events recorded for this day.')
              else
                ...snapshot.pointEvents.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• ${event.title}: base +${event.basePoints}, bonus +${event.streakBonusPoints}, total +${event.totalPoints}${event.reason.isEmpty ? '' : ' (${event.reason})'}'),
                    )),
              const SizedBox(height: 12),
              const Text('Completed work', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              if (snapshot.completedTaskNames.isEmpty)
                const Text('No completed tasks recorded for this day.')
              else
                ...snapshot.completedTaskNames.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $task'),
                    )),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(value),
        ],
      ),
    );
  }
}


class _LifetimePerformanceCard extends StatelessWidget {
  final String username;
  final LifetimeProductivityStats stats;
  final UserProfile userProfile;
  final HiveService hiveService;

  const _LifetimePerformanceCard({required this.username, required this.stats, required this.userProfile, required this.hiveService});

  @override
  Widget build(BuildContext context) {
    final rank = RankTier.forLevel(stats.level);
    final currentAchievement = _achievementForPoints(stats.totalPoints);
    final nextAchievement = _nextAchievementForPoints(stats.totalPoints);
    final milestone = nextAchievement?.points ?? currentAchievement.points;
    final progress = milestone == 0 ? 1.0 : (stats.totalPoints / milestone).clamp(0.0, 1.0).toDouble();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    ProductivitySnapshot? todaySnapshot;
    for (final snapshot in stats.snapshots) {
      final snapshotDate = DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day);
      if (snapshotDate == todayDate) {
        todaySnapshot = snapshot;
        break;
      }
    }

    return _TimelineSection(
      title: '👤 Lifetime Performance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                profile: userProfile,
                radius: 38,
                accentColor: Color(rank.colorValue),
                badge: rank.emoji,
                onTap: () => _showProfilePhotoActions(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    if (userProfile.nickname.isNotEmpty) Text('@${userProfile.nickname}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                    const SizedBox(height: 2),
                    Text('🏆 Rank: ${rank.name}  •  ⭐ Level: ${stats.level}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
                    if (userProfile.bio.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('“${userProfile.bio}”', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(context),
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatTile(label: '💎 Lifetime Points', value: _formatInt(stats.totalPoints)),
              _StatTile(label: '⭐ Today’s Points', value: '+${_formatInt(todaySnapshot?.totalPoints ?? 0)}'),
              _StatTile(label: '🔥 Today’s Bonus', value: '+${_formatInt(todaySnapshot?.streakBonusPoints ?? 0)}'),
              _StatTile(label: '⚡ Lifetime XP', value: _formatInt(stats.xp)),
              _StatTile(label: '🔥 Current Streak', value: '${stats.currentStreak} days'),
              _StatTile(label: '🏅 Best Streak', value: '${stats.bestStreak} days'),
              _StatTile(label: '📊 Avg Productivity', value: '${stats.averageDailyScore.toStringAsFixed(1)}%'),
              _StatTile(label: '⏱ Focus Hours', value: _formatHours(stats.totalFocusHours)),
              _StatTile(label: '✅ Tasks Completed', value: _formatInt(stats.totalCompletedTasks)),
              _StatTile(label: '📚 Phases Completed', value: _formatInt(stats.projectPhasesCompleted)),
              _StatTile(label: '🎁 Total Bonus Earned', value: '+${_formatInt(stats.totalBonusEarned)}'),
              _StatTile(label: '🏆 Highest Streak Bonus', value: '+${_formatInt(stats.highestStreakBonus)}'),
              _StatTile(label: '📅 Active Days', value: _formatInt(stats.activeDays)),
              _StatTile(label: '🏅 Achievement', value: '${currentAchievement.emoji} ${currentAchievement.name}'),
            ].map((tile) => SizedBox(width: 168, child: tile)).toList(),
          ),
          const SizedBox(height: 16),
          Text('Lifetime Points Milestone', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              color: AppColors.primary,
              backgroundColor: Colors.black12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nextAchievement == null
                ? '${_formatInt(stats.totalPoints)} lifetime points • All milestones unlocked'
                : '${_formatInt(stats.totalPoints)} / ${_formatInt(nextAchievement.points)} (${(progress * 100).round()}%) • Next: ${nextAchievement.emoji} ${nextAchievement.name}',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pointAchievements.map((achievement) {
              final unlocked = stats.totalPoints >= achievement.points;
              return Chip(
                avatar: Text(achievement.emoji),
                label: Text('${achievement.name} (${_formatInt(achievement.points)})'),
                backgroundColor: unlocked ? AppColors.primary.withOpacity(0.14) : Colors.grey.shade200,
                labelStyle: TextStyle(fontWeight: FontWeight.w800, color: unlocked ? AppColors.textPrimary : Colors.black45),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  Future<void> _showProfilePhotoActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Change Profile Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ),
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take Photo'), onTap: () => Navigator.pop(context, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(context, 'gallery')),
            ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('View Current Photo'), onTap: () => Navigator.pop(context, 'view')),
            ListTile(leading: const Icon(Icons.crop_outlined), title: const Text('Crop & Edit'), onTap: () => Navigator.pop(context, 'edit')),
            ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove Photo'), onTap: () => Navigator.pop(context, 'remove')),
            ListTile(leading: const Icon(Icons.close), title: const Text('Cancel'), onTap: () => Navigator.pop(context, 'cancel')),
          ],
        ),
      ),
    );
    if (action == null || action == 'cancel') return;
    if (action == 'view') {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileAvatar(profile: userProfile, radius: 120, accentColor: Color(RankTier.forLevel(stats.level).colorValue), badge: RankTier.forLevel(stats.level).emoji),
                const SizedBox(height: 16),
                Text(userProfile.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                Text(userProfile.avatarBorderStyle),
              ],
            ),
          ),
        ),
      );
      return;
    }
    if (action == 'remove') {
      await hiveService.removeProfilePhoto();
      return;
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    await _pickAndSaveProfilePhoto(context, source);
  }

  Future<void> _pickAndSaveProfilePhoto(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (image == null) return;
      await hiveService.saveUserProfile(userProfile.copyWith(profilePhotoPath: image.path));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open image picker: $error')),
      );
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final nameController = TextEditingController(text: userProfile.fullName);
    final nicknameController = TextEditingController(text: userProfile.nickname);
    final bioController = TextEditingController(text: userProfile.bio);
    final occupationController = TextEditingController(text: userProfile.occupation);
    final birthdayController = TextEditingController(text: userProfile.birthday);
    const themeOptions = ['Light', 'Dark', 'Gamified', 'Calm', 'Minimal'];
    const frameOptions = ['Silver', 'Blue Glow', 'Green Ring', 'Purple Aura', 'Golden Frame', 'Animated Rainbow'];
    var selectedTheme = themeOptions.contains(userProfile.favoriteTheme) ? userProfile.favoriteTheme : 'Calm';
    var selectedFrame = frameOptions.contains(userProfile.avatarBorderStyle) ? userProfile.avatarBorderStyle : 'Silver';
    final saved = await showDialog<UserProfile>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                TextField(controller: nicknameController, decoration: const InputDecoration(labelText: 'Nickname')),
                TextField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio / Personal Quote')),
                TextField(controller: occupationController, decoration: const InputDecoration(labelText: 'Occupation')),
                TextField(controller: birthdayController, decoration: const InputDecoration(labelText: 'Birthday (Optional)')),
                DropdownButtonFormField<String>(
                  value: selectedTheme,
                  decoration: const InputDecoration(labelText: 'Favorite Theme'),
                  items: themeOptions.map((theme) => DropdownMenuItem(value: theme, child: Text(theme))).toList(),
                  onChanged: (value) => setDialogState(() => selectedTheme = value ?? selectedTheme),
                ),
                DropdownButtonFormField<String>(
                  value: selectedFrame,
                  decoration: const InputDecoration(labelText: 'Avatar Border Style'),
                  items: frameOptions.map((frame) => DropdownMenuItem(value: frame, child: Text(frame))).toList(),
                  onChanged: (value) => setDialogState(() => selectedFrame = value ?? selectedFrame),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                userProfile.copyWith(
                  fullName: nameController.text,
                  nickname: nicknameController.text,
                  bio: bioController.text,
                  occupation: occupationController.text,
                  birthday: birthdayController.text,
                  favoriteTheme: selectedTheme,
                  avatarBorderStyle: selectedFrame,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    nicknameController.dispose();
    bioController.dispose();
    occupationController.dispose();
    birthdayController.dispose();
    if (saved != null) await hiveService.saveUserProfile(saved);
  }

}

class _RewardMoneyCard extends StatelessWidget {
  final HiveService hiveService;

  const _RewardMoneyCard({required this.hiveService});

  @override
  Widget build(BuildContext context) {
    final summary = hiveService.getRewardMoneySummary();
    final goals = summary.goals;
    final history = summary.ledger.take(5).toList();

    return _TimelineSection(
      title: '💰 Offline Reward Money',
      trailing: Text('10 points = ₹1', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RewardStat(label: 'Total Points', value: _formatInt(summary.totalPoints)),
              _RewardStat(label: 'Reward Money Earned', value: _formatRupees(summary.earnedRupees)),
              _RewardStat(label: 'Available Balance', value: _formatRupees(summary.availableRupees), color: Colors.green.shade700),
              _RewardStat(label: 'Withdrawn / Used', value: _formatRupees(summary.usedRupees), color: Colors.deepOrange.shade700),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showWithdrawDialog(context, summary),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Withdraw / Use'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showGoalDialog(context),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Add Goal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Reward Goals', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12)),
              child: const Text('Create a personal reward goal, then fund it from your offline balance.', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            )
          else
            ...goals.map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RewardGoalTile(
                    goal: goal,
                    availableBalance: summary.availableRupees,
                    onFund: () => _showFundGoalDialog(context, goal),
                    onEdit: () => _showGoalDialog(context, goal),
                  ),
                )),
          const SizedBox(height: 10),
          const Text('Money History', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Text('No withdrawals or goal funding yet. Earn points, then use them for your personal goals.', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54))
          else
            ...history.map((entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: entry.type == RewardLedgerEntry.typeGoalFunding ? Colors.blue.shade50 : Colors.orange.shade50,
                    child: Icon(entry.type == RewardLedgerEntry.typeGoalFunding ? Icons.flag_outlined : Icons.receipt_long_outlined, color: AppColors.primary),
                  ),
                  title: Text('${_formatRupees(entry.amountRupees)} ${entry.type == RewardLedgerEntry.typeGoalFunding ? 'added to ${entry.goalName}' : 'withdrawn'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${_formatDate(entry.date)} • ${entry.reason}${entry.note.isEmpty ? '' : ' • ${entry.note}'}\nBalance left: ${_formatRupees(entry.balanceAfter)}'),
                )),
        ],
      ),
    );
  }

  Future<void> _showWithdrawDialog(BuildContext context, RewardMoneySummary summary) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final goalController = TextEditingController();
    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw / Use Reward Money'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Available: ${_formatRupees(summary.availableRupees)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
              TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
              TextField(controller: goalController, decoration: const InputDecoration(labelText: 'Goal Linked (Optional)')),
              TextField(controller: noteController, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save Withdrawal')),
        ],
      ),
    );
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final reason = reasonController.text.trim();
    final goalName = goalController.text.trim();
    final note = noteController.text.trim();
    amountController.dispose();
    reasonController.dispose();
    goalController.dispose();
    noteController.dispose();
    if (saved != true) return;
    try {
      await hiveService.withdrawRewardMoney(amountRupees: amount, reason: reason, goalName: goalName, note: note);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reward withdrawal saved')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showFundGoalDialog(BuildContext context, RewardGoal goal) async {
    final summary = hiveService.getRewardMoneySummary();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Money to ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: ${_formatRupees(summary.availableRupees)} • Remaining: ${_formatRupees(goal.remainingAmountRupees)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Money')),
        ],
      ),
    );
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();
    if (saved != true) return;
    try {
      await hiveService.fundRewardGoal(goal: goal, amountRupees: amount, note: note);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal funding saved')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showGoalDialog(BuildContext context, [RewardGoal? goal]) async {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final targetController = TextEditingController(text: goal == null ? '' : '${goal.targetAmountRupees}');
    final descriptionController = TextEditingController(text: goal?.description ?? '');
    final deadlineController = TextEditingController(text: goal?.deadline == null ? '' : _formatIsoDate(goal!.deadline!));
    var priority = goal?.priority ?? 'Medium';
    var imagePath = goal?.imagePath ?? '';
    final saved = await showDialog<RewardGoal>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(goal == null ? 'Create Reward Goal' : 'Edit Reward Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Goal Name')),
                TextField(controller: targetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount (₹)')),
                TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: deadlineController, decoration: const InputDecoration(labelText: 'Deadline (YYYY-MM-DD, Optional)')),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const ['Low', 'Medium', 'High'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) => setDialogState(() => priority = value ?? priority),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = await _pickGoalImage(context, ImageSource.gallery);
                        if (path != null) setDialogState(() => imagePath = path);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from Gallery'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = await _pickGoalImage(context, ImageSource.camera);
                        if (path != null) setDialogState(() => imagePath = path);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take Photo'),
                    ),
                    if (imagePath.isNotEmpty)
                      TextButton.icon(onPressed: () => setDialogState(() => imagePath = ''), icon: const Icon(Icons.delete_outline), label: const Text('Remove Image')),
                  ],
                ),
                if (imagePath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(width: 360, height: 120, child: imageFromPath(imagePath, width: 360, height: 120, fit: BoxFit.cover, fallback: const Center(child: Text('Image preview unavailable')))),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final target = int.tryParse(targetController.text.trim()) ?? 0;
                Navigator.pop(
                  context,
                  RewardGoal(
                    id: goal?.id ?? 'goal_${DateTime.now().microsecondsSinceEpoch}',
                    name: nameController.text.trim().isEmpty ? 'Reward Goal' : nameController.text.trim(),
                    targetAmountRupees: target,
                    savedAmountRupees: goal?.savedAmountRupees ?? 0,
                    imagePath: imagePath,
                    description: descriptionController.text.trim(),
                    deadline: DateTime.tryParse(deadlineController.text.trim()),
                    priority: priority,
                    createdAt: goal?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Save Goal'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    targetController.dispose();
    descriptionController.dispose();
    deadlineController.dispose();
    if (saved != null) await hiveService.saveRewardGoal(saved);
  }

  Future<String?> _pickGoalImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
      return image?.path;
    } catch (error) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open image picker: $error')));
      return null;
    }
  }
}

class _RewardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _RewardStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _RewardGoalTile extends StatelessWidget {
  final RewardGoal goal;
  final int availableBalance;
  final VoidCallback onFund;
  final VoidCallback onEdit;

  const _RewardGoalTile({required this.goal, required this.availableBalance, required this.onFund, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.14))),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: goal.imagePath.isEmpty
                ? Container(width: 58, height: 58, color: AppColors.surface, child: const Icon(Icons.flag_outlined, color: AppColors.primary))
                : imageFromPath(goal.imagePath, width: 58, height: 58, fit: BoxFit.cover, fallback: Container(width: 58, height: 58, color: AppColors.surface, child: const Icon(Icons.flag_outlined))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('${_formatRupees(goal.savedAmountRupees)} / ${_formatRupees(goal.targetAmountRupees)} • Remaining ${_formatRupees(goal.remainingAmountRupees)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: goal.progress, minHeight: 8, backgroundColor: Colors.black12, color: goal.isCompleted ? Colors.green : AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text('${(goal.progress * 100).round()}% completed • ${goal.priority} priority', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
              ],
            ),
          ),
          Column(
            children: [
              TextButton(onPressed: onEdit, child: const Text('Edit')),
              ElevatedButton(onPressed: availableBalance > 0 && !goal.isCompleted ? onFund : null, child: const Text('Add ₹')),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatRupees(int value) => '₹${_formatInt(value)}';

class _PhotoGalleryCard extends StatelessWidget {
  final UserProfile userProfile;
  final HiveService hiveService;

  const _PhotoGalleryCard({required this.userProfile, required this.hiveService});

  @override
  Widget build(BuildContext context) {
    final photos = <String>[
      if (userProfile.profilePhotoPath.trim().isNotEmpty) userProfile.profilePhotoPath.trim(),
      ...userProfile.photoHistory,
    ];
    return _TimelineSection(
      title: '📷 Photo Gallery',
      child: photos.isEmpty
          ? const Text('Profile photo history will appear here after you add or change your photo.')
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: photos.map((path) {
                final isCurrent = path == userProfile.profilePhotoPath;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: isCurrent ? null : () => hiveService.saveUserProfile(userProfile.copyWith(profilePhotoPath: path)),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primary.withOpacity(0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isCurrent ? AppColors.primary : AppColors.primary.withOpacity(0.16)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ProfileAvatar(profile: userProfile.copyWith(profilePhotoPath: path), radius: 42, accentColor: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(isCurrent ? 'Current photo' : 'Tap to restore', style: const TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _PointsTotalsCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final LifetimeProductivityStats stats;

  const _PointsTotalsCard({required this.snapshots, required this.stats});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);
    final yearStart = DateTime(today.year, 1, 1);
    return _TimelineSection(
      title: '📉 Cumulative Points',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatTile(label: 'This Week', value: '${_formatInt(_pointsSince(snapshots, weekStart))} pts'),
          _StatTile(label: 'This Month', value: '${_formatInt(_pointsSince(snapshots, monthStart))} pts'),
          _StatTile(label: 'This Year', value: '${_formatInt(_pointsSince(snapshots, yearStart))} pts'),
          _StatTile(label: 'Streak Bonus', value: '+${_formatInt(stats.totalBonusEarned)} pts'),
          _StatTile(label: 'Lifetime', value: '${_formatInt(stats.totalPoints)} pts'),
        ].map((tile) => SizedBox(width: 168, child: tile)).toList(),
      ),
    );
  }
}

class _PointsAnalyticsCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;

  const _PointsAnalyticsCard({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final recent = snapshots.length <= 14 ? snapshots : snapshots.sublist(snapshots.length - 14);
    final maxPoints = recent.fold<int>(1, (max, snapshot) => math.max(max, snapshot.totalPoints));
    var cumulative = 0;
    return _TimelineSection(
      title: '📈 Points Analytics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isEmpty)
            const Text('Complete tasks to build daily points charts.')
          else
            ...recent.map((snapshot) {
              cumulative += snapshot.totalPoints;
              final value = snapshot.totalPoints / maxPoints;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 54, child: Text('${snapshot.date.month}/${snapshot.date.day}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: value, minHeight: 10, color: _heatColor(snapshot.productivityScore), backgroundColor: Colors.black12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 92, child: Text('${_formatInt(snapshot.totalPoints)} pts', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ],
                ),
              );
            }),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Lifetime growth in this view: ${_formatInt(cumulative)} points', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final LifetimeProductivityStats stats;

  const _OverviewCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Lifetime Productivity', '${stats.lifetimeProductivity.toStringAsFixed(1)}%'),
      ('Total Points Earned', '${stats.totalPoints}'),
      ('Total Focus Hours', _formatHours(stats.totalFocusHours)),
      ('Total Completed Tasks', '${stats.totalCompletedTasks}'),
      ('Current Streak', '${stats.currentStreak} days'),
      ('Best Streak', '${stats.bestStreak} days'),
      ('Active Days', '${stats.activeDays}'),
      ('Average Daily Score', '${stats.averageDailyScore.toStringAsFixed(1)}%'),
      ('Highest Score', stats.highestDay == null ? '0%' : '${stats.highestDay!.productivityScore.toStringAsFixed(1)}%'),
      ('Lowest Score', stats.lowestDay == null ? '0%' : '${stats.lowestDay!.productivityScore.toStringAsFixed(1)}%'),
      ('Routine Completions', '${stats.routineCompletions}'),
      ('Project Phases Done', '${stats.projectPhasesCompleted}'),
      ('XP / Level', '${stats.xp} XP • Lv ${stats.level}'),
      ('Median Score', '${stats.medianProductivity.toStringAsFixed(1)}%'),
    ];

    return _TimelineSection(
      title: 'Lifetime Overview',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map((card) => SizedBox(
                  width: 168,
                  child: _StatTile(label: card.$1, value: card.$2),
                ))
            .toList(),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _TrendCard({required this.snapshots, required this.selectedRange, required this.onRangeChanged});

  @override
  Widget build(BuildContext context) {
    const ranges = ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last Year', 'All Time'];
    return _TimelineSection(
      title: 'Productivity Trend Graph',
      trailing: DropdownButton<String>(
        value: selectedRange,
        underline: const SizedBox.shrink(),
        items: ranges.map((range) => DropdownMenuItem(value: range, child: Text(range))).toList(),
        onChanged: (value) {
          if (value != null) onRangeChanged(value);
        },
      ),
      child: SizedBox(
        height: 210,
        child: snapshots.isEmpty
            ? const Center(child: Text('Complete tasks to build your trend line.'))
            : CustomPaint(
                painter: _TrendPainter(snapshots),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class _HeatMapCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final ValueChanged<ProductivitySnapshot> onTapSnapshot;

  const _HeatMapCard({required this.snapshots, required this.onTapSnapshot});

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final snapshot in snapshots) _dateKey(snapshot.date): snapshot};
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 364));
    return _TimelineSection(
      title: 'Calendar Heat Map',
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(365, (index) {
          final date = start.add(Duration(days: index));
          final snapshot = byKey[_dateKey(date)];
          final color = _heatColor(snapshot?.productivityScore ?? -1);
          return Tooltip(
            message: snapshot == null ? '${_formatDate(date)}: no score' : '${_formatDate(date)}: ${snapshot.productivityScore.toStringAsFixed(1)}%',
            child: InkWell(
              onTap: snapshot == null ? null : () => onTapSnapshot(snapshot),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ReportsCard extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;

  const _ReportsCard({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final monthly = _groupAverage(snapshots, (date) => '${_monthName(date.month)} ${date.year}');
    final yearly = _groupAverage(snapshots, (date) => '${date.year}');
    return _TimelineSection(
      title: 'Monthly & Yearly Reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (monthly.isEmpty) const Text('No monthly reports yet.'),
          ...monthly.take(4).map((entry) => _ReportRow(label: entry.key, report: entry.value)),
          const SizedBox(height: 12),
          const Text('Yearly', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (yearly.isEmpty) const Text('No yearly reports yet.'),
          ...yearly.take(4).map((entry) => _ReportRow(label: entry.key, report: entry.value)),
        ],
      ),
    );
  }

  List<MapEntry<String, _ProductivityReport>> _groupAverage(List<ProductivitySnapshot> snapshots, String Function(DateTime date) labelFor) {
    final groups = <String, List<ProductivitySnapshot>>{};
    for (final snapshot in snapshots) {
      groups.putIfAbsent(labelFor(snapshot.date), () => <ProductivitySnapshot>[]).add(snapshot);
    }
    final entries = groups.entries.map((entry) => MapEntry(entry.key, _ProductivityReport.fromSnapshots(entry.value))).toList();
    entries.sort((a, b) => b.value.latestDate.compareTo(a.value.latestDate));
    return entries;
  }
}

class _HistoryList extends StatelessWidget {
  final List<ProductivitySnapshot> snapshots;
  final ValueChanged<ProductivitySnapshot> onTapSnapshot;

  const _HistoryList({required this.snapshots, required this.onTapSnapshot});

  @override
  Widget build(BuildContext context) {
    return _TimelineSection(
      title: 'Daily Productivity Journal',
      child: Column(
        children: snapshots.isEmpty
            ? [const Text('Daily records will appear here automatically after tasks are completed.')]
            : [
                const _DailyHistoryHeader(),
                ...snapshots.take(30).map((snapshot) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: _heatColor(snapshot.productivityScore), child: Text('${snapshot.productivityScore.round()}%', style: const TextStyle(fontSize: 11, color: Colors.white))),
                      title: Text(_formatDate(snapshot.date), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Points: ${_formatInt(snapshot.totalPoints)} (bonus +${_formatInt(snapshot.streakBonusPoints)}) • Productivity: ${snapshot.productivityScore.toStringAsFixed(1)}% • ${snapshot.rating}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onTapSnapshot(snapshot),
                    )),
              ],
      ),
    );
  }
}


class _DailyHistoryHeader extends StatelessWidget {
  const _DailyHistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: const Row(
        children: [
          SizedBox(width: 48, child: Text('Score', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54))),
          Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54))),
          Expanded(flex: 3, child: Text('Points • Productivity • Rating', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54))),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _TimelineSection({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final _ProductivityReport report;

  const _ReportRow({required this.label, required this.report});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label • Avg ${report.average.toStringAsFixed(1)}% • High ${report.highest.toStringAsFixed(1)}% • Low ${report.lowest.toStringAsFixed(1)}% • ${report.totalPoints} pts • ${_formatHours(report.focusHours)} • ${report.completedTasks} tasks'),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<ProductivitySnapshot> snapshots;

  _TrendPainter(this.snapshots);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final chart = Rect.fromLTWH(34, 8, size.width - 44, size.height - 34);

    for (final pct in [0, 25, 50, 75, 100]) {
      final y = chart.bottom - (pct / 100 * chart.height);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), axisPaint);
      textPainter.text = TextSpan(text: '$pct', style: const TextStyle(fontSize: 10, color: Colors.black45));
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - 6));
    }

    if (snapshots.length == 1) {
      final y = chart.bottom - (snapshots.first.productivityScore / 100 * chart.height);
      canvas.drawCircle(Offset(chart.center.dx, y), 5, Paint()..color = AppColors.primary);
      return;
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < snapshots.length; i++) {
      final x = chart.left + (i / math.max(1, snapshots.length - 1)) * chart.width;
      final y = chart.bottom - (snapshots[i].productivityScore / 100 * chart.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chart.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(chart.right, chart.bottom);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.snapshots != snapshots;
}

class _ProductivityReport {
  final DateTime latestDate;
  final double average;
  final double highest;
  final double lowest;
  final int totalPoints;
  final double focusHours;
  final int completedTasks;

  const _ProductivityReport({required this.latestDate, required this.average, required this.highest, required this.lowest, required this.totalPoints, required this.focusHours, required this.completedTasks});

  factory _ProductivityReport.fromSnapshots(List<ProductivitySnapshot> snapshots) {
    final sorted = snapshots.toList()..sort((a, b) => a.date.compareTo(b.date));
    return _ProductivityReport(
      latestDate: sorted.last.date,
      average: sorted.fold<double>(0, (sum, snapshot) => sum + snapshot.productivityScore) / sorted.length,
      highest: sorted.map((snapshot) => snapshot.productivityScore).reduce(math.max),
      lowest: sorted.map((snapshot) => snapshot.productivityScore).reduce(math.min),
      totalPoints: sorted.fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints),
      focusHours: sorted.fold<double>(0, (sum, snapshot) => sum + snapshot.focusedHours),
      completedTasks: sorted.fold<int>(0, (sum, snapshot) => sum + snapshot.completedTasks),
    );
  }
}


class _PointAchievement {
  final int points;
  final String emoji;
  final String name;

  const _PointAchievement(this.points, this.emoji, this.name);
}

const _pointAchievements = [
  _PointAchievement(1000, '🌱', 'Beginner'),
  _PointAchievement(5000, '🎯', 'Focused'),
  _PointAchievement(10000, '💪', 'Consistent'),
  _PointAchievement(25000, '🚀', 'Achiever'),
  _PointAchievement(50000, '🔥', 'Momentum Master'),
  _PointAchievement(100000, '👑', 'Legend'),
  _PointAchievement(250000, '💎', 'Grandmaster'),
  _PointAchievement(500000, '🌟', 'Productivity Titan'),
];

_PointAchievement _achievementForPoints(int points) {
  var current = _pointAchievements.first;
  for (final achievement in _pointAchievements) {
    if (points >= achievement.points) current = achievement;
  }
  return current;
}

_PointAchievement? _nextAchievementForPoints(int points) {
  for (final achievement in _pointAchievements) {
    if (points < achievement.points) return achievement;
  }
  return null;
}

int _pointsSince(List<ProductivitySnapshot> snapshots, DateTime start) {
  final startDay = DateTime(start.year, start.month, start.day);
  return snapshots
      .where((snapshot) => !DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day).isBefore(startDay))
      .fold<int>(0, (sum, snapshot) => sum + snapshot.totalPoints);
}

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

Color _heatColor(double score) {
  if (score < 0) return Colors.grey.shade200;
  if (score >= 90) return const Color(0xFF1B5E20);
  if (score >= 80) return const Color(0xFF43A047);
  if (score >= 60) return const Color(0xFFFDD835);
  if (score >= 40) return const Color(0xFFFF9800);
  return const Color(0xFFE53935);
}

String _dateKey(DateTime date) => date.toIso8601String().split('T').first;

String _formatDate(DateTime date) => '${date.day} ${_monthName(date.month)} ${date.year}';

String _formatHours(double hours) {
  if (hours == 0) return '0 hrs';
  final whole = hours.floor();
  final minutes = ((hours - whole) * 60).round();
  if (whole == 0) return '$minutes min';
  if (minutes == 0) return '$whole hrs';
  return '$whole hrs $minutes min';
}

String _monthName(int month) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[(month - 1).clamp(0, 11).toInt()];
}

String _formatIsoDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
