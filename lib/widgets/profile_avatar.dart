import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../utils/path_image.dart';

class ProfileAvatar extends StatelessWidget {
  final UserProfile profile;
  final double radius;
  final Color accentColor;
  final String? badge;
  final VoidCallback? onTap;
  final bool showGlow;

  const ProfileAvatar({
    super.key,
    required this.profile,
    this.radius = 28,
    required this.accentColor,
    this.badge,
    this.onTap,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final border = _borderColor(profile.avatarBorderStyle, accentColor);
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: profile.avatarBorderStyle == 'Golden Frame' ? 4 : 3),
        boxShadow: showGlow
            ? [BoxShadow(color: border.withOpacity(0.35), blurRadius: 18, spreadRadius: 1)]
            : null,
      ),
      child: ClipOval(child: _avatarContent()),
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          avatar,
          if (badge != null && badge!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 2),
              ),
              child: Text(badge!, style: TextStyle(fontSize: radius * 0.28)),
            ),
        ],
      ),
    );
  }

  Widget _avatarContent() {
    final path = profile.profilePhotoPath.trim();
    if (path.isEmpty) return _fallbackAvatar();

    return imageFromPath(
      path,
      fit: BoxFit.cover,
      fallback: _fallbackAvatar(),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: accentColor,
      alignment: Alignment.center,
      child: Text(
        profile.initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: radius * 0.64),
      ),
    );
  }

  Color _borderColor(String frame, Color fallback) {
    switch (frame) {
      case 'Blue Glow':
        return Colors.blueAccent;
      case 'Green Ring':
        return Colors.green;
      case 'Purple Aura':
        return Colors.purpleAccent;
      case 'Golden Frame':
        return const Color(0xFFFFC107);
      case 'Animated Rainbow':
        return Colors.pinkAccent;
      case 'Silver':
        return const Color(0xFFC0C0C0);
      default:
        return fallback;
    }
  }
}
