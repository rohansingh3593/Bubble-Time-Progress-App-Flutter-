import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/dashboard_themes.dart';
import '../models/rank_profile.dart';
import '../models/user_profile.dart';
import 'profile_avatar.dart';
import 'app_text.dart';

class RankProfileCard extends StatelessWidget {
  final RankProfile profile;
  final Future<void> Function(String username)? onUsernameChanged;
  final VoidCallback? onTap;
  final VoidCallback? onJourneyTap;
  final bool compact;
  final UserProfile? userProfile;
  final VoidCallback? onProfilePhotoTap;
  final DashboardThemeStyle? dashboardStyle;

  const RankProfileCard({
    super.key,
    required this.profile,
    this.onUsernameChanged,
    this.onTap,
    this.onJourneyTap,
    this.compact = false,
    this.userProfile,
    this.onProfilePhotoTap,
    this.dashboardStyle,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = Color(profile.currentRank.colorValue);
    final effectiveProfile = userProfile ?? UserProfile.defaults(fullName: profile.username);
    final style = dashboardStyle;
    final gradientColors = style?.heroGradient.isNotEmpty == true
        ? style!.heroGradient
        : [rankColor.withOpacity(0.95), AppColors.primaryDark];
    final accentColor = style?.accent ?? rankColor;
    final contentColor = style == null ? Colors.white : AppThemeColors.readableTextOn(gradientColors.first, style);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (style?.primary ?? rankColor).withOpacity(0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatar(profile: effectiveProfile, accentColor: accentColor, badge: profile.currentRank.emoji, radius: 31, onTap: onProfilePhotoTap),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.username,
                              style: TextStyle(
                                color: contentColor,
                                fontSize: responsiveFont(context, 20),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (onUsernameChanged != null)
                            IconButton(
                              tooltip: 'Edit username',
                              icon: Icon(Icons.edit, color: contentColor, size: 20),
                              onPressed: () => _showEditUsernameDialog(context),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rank: ${profile.currentRank.name} ${profile.currentRank.emoji}',
                        style: TextStyle(color: contentColor, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Level: ${profile.level}  •  Current Streak: ${profile.activeStreak} Days',
                        style: TextStyle(color: contentColor.withOpacity(0.86), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final xpText = Text(
                  '${profile.currentLevelXp}/${profile.xpForNextLevel} XP to Level ${profile.level + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: contentColor, fontWeight: FontWeight.w700),
                );
                final rankText = Text(
                  profile.nextRank == null ? 'Top Rank' : 'Next: ${profile.nextRank!.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: contentColor.withOpacity(0.88), fontWeight: FontWeight.w600),
                );
                if (constraints.maxWidth < 260) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      xpText,
                      const SizedBox(height: 2),
                      rankText,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: xpText),
                    const SizedBox(width: 8),
                    Flexible(child: Align(alignment: Alignment.centerRight, child: rankText)),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: profile.levelProgress.clamp(0.0, 1.0).toDouble(),
                minHeight: 10,
                color: contentColor,
                backgroundColor: contentColor.withOpacity(0.25),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              Text(
                onTap == null
                    ? 'Your productivity growth dashboard'
                    : 'Tap your profile to reflect on your day and track your growth journey.',
                style: TextStyle(color: contentColor.withOpacity(0.84), fontWeight: FontWeight.w600),
              ),
              if (onJourneyTap != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onJourneyTap,
                  icon: Icon(Icons.auto_stories, color: contentColor),
                  label: const Text('Open Journey Timeline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: contentColor,
                    side: BorderSide(color: contentColor.withOpacity(0.65)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RankMetric(label: 'Completed', value: '${profile.totalTasksCompleted}', contentColor: contentColor),
                  _RankMetric(label: 'Important', value: '${profile.importantTasksCompleted}', contentColor: contentColor),
                  _RankMetric(label: 'Active days', value: '${profile.totalActiveDays}', contentColor: contentColor),
                  _RankMetric(label: 'Score', value: '${profile.productivityScore}%', contentColor: contentColor),
                  _RankMetric(label: 'Journal', value: '${profile.journalEntries}', contentColor: contentColor),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditUsernameDialog(BuildContext context) async {
    final controller = TextEditingController(text: profile.username);
    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update profile username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Rohan Singh',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();

    if (username != null && username.trim().isNotEmpty) {
      await onUsernameChanged?.call(username.trim());
    }
  }
}

class _RankMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color contentColor;

  const _RankMetric({required this.label, required this.value, required this.contentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: contentColor.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: contentColor.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: contentColor, fontWeight: FontWeight.w900, fontSize: responsiveFont(context, 16))),
          Text(label, style: TextStyle(color: contentColor.withOpacity(0.82), fontSize: responsiveFont(context, 11))),
        ],
      ),
    );
  }
}
