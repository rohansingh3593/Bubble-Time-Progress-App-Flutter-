import 'package:flutter/material.dart';

enum DashboardThemeType {
  light,
  dark,
  gamified,
  calm,
  minimal,
}

extension DashboardThemeTypeX on DashboardThemeType {
  String get storageKey => name;

  String get label {
    switch (this) {
      case DashboardThemeType.light:
        return 'Light';
      case DashboardThemeType.dark:
        return 'Dark';
      case DashboardThemeType.gamified:
        return 'Gamified';
      case DashboardThemeType.calm:
        return 'Calm';
      case DashboardThemeType.minimal:
        return 'Minimal';
    }
  }

  String get description {
    switch (this) {
      case DashboardThemeType.light:
        return 'Daily planning with soft blue/purple cards';
      case DashboardThemeType.dark:
        return 'Focus mode with neon contrast';
      case DashboardThemeType.gamified:
        return 'XP, rank glow, and motivational gradients';
      case DashboardThemeType.calm:
        return 'Journal-friendly cream, green, and orange tones';
      case DashboardThemeType.minimal:
        return 'Clean professional dashboard for work';
    }
  }

}

DashboardThemeType dashboardThemeTypeFromStorage(String? value) {
  return DashboardThemeType.values.firstWhere(
    (theme) => theme.storageKey == value,
    orElse: () => DashboardThemeType.dark,
  );
}

class DashboardThemeStyle {
  final DashboardThemeType type;
  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final List<Color> heroGradient;
  final bool dark;
  final bool animated;

  const DashboardThemeStyle({
    required this.type,
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.heroGradient,
    required this.dark,
    required this.animated,
  });

  static DashboardThemeStyle of(DashboardThemeType type) {
    switch (type) {
      case DashboardThemeType.light:
        return const DashboardThemeStyle(
          type: DashboardThemeType.light,
          background: Color(0xFFF7F9FF),
          surface: Colors.white,
          elevatedSurface: Color(0xFFF0F4FF),
          primary: Color(0xFF5B6CFF),
          secondary: Color(0xFF7B61FF),
          accent: Color(0xFF42A5F5),
          textPrimary: Color(0xFF10182F),
          textMuted: Color(0xFF5A6785),
          heroGradient: [Color(0xFF7B61FF), Color(0xFF2F80ED)],
          dark: false,
          animated: true,
        );
      case DashboardThemeType.dark:
        return const DashboardThemeStyle(
          type: DashboardThemeType.dark,
          background: Color(0xFF0B1020),
          surface: Color(0xFF121A31),
          elevatedSurface: Color(0xFF1A2442),
          primary: Color(0xFF6D7CFF),
          secondary: Color(0xFF8B5CF6),
          accent: Color(0xFF22D3EE),
          textPrimary: Colors.white,
          textMuted: Color(0xFFB9C6F3),
          heroGradient: [Color(0xFF6A54FF), Color(0xFF2D5BFF)],
          dark: true,
          animated: true,
        );
      case DashboardThemeType.gamified:
        return const DashboardThemeStyle(
          type: DashboardThemeType.gamified,
          background: Color(0xFF130B2E),
          surface: Color(0xFF211443),
          elevatedSurface: Color(0xFF2D1B5A),
          primary: Color(0xFFFFD86D),
          secondary: Color(0xFF8B5CF6),
          accent: Color(0xFFFF6A3D),
          textPrimary: Colors.white,
          textMuted: Color(0xFFE7D9FF),
          heroGradient: [Color(0xFFFF6A3D), Color(0xFF7C3AED), Color(0xFF2563EB)],
          dark: true,
          animated: true,
        );
      case DashboardThemeType.calm:
        return const DashboardThemeStyle(
          type: DashboardThemeType.calm,
          background: Color(0xFFFFF7EA),
          surface: Color(0xFFFFFCF5),
          elevatedSurface: Color(0xFFF3EBD8),
          primary: Color(0xFF4F8A6B),
          secondary: Color(0xFFE89A5B),
          accent: Color(0xFF9BBF8A),
          textPrimary: Color(0xFF2D241A),
          textMuted: Color(0xFF756B5D),
          heroGradient: [Color(0xFF4F8A6B), Color(0xFFE89A5B)],
          dark: false,
          animated: false,
        );
      case DashboardThemeType.minimal:
        return const DashboardThemeStyle(
          type: DashboardThemeType.minimal,
          background: Color(0xFFF3F4F6),
          surface: Color(0xFFFFFFFF),
          elevatedSurface: Color(0xFFE5E7EB),
          primary: Color(0xFF374151),
          secondary: Color(0xFF6B7280),
          accent: Color(0xFF2563EB),
          textPrimary: Color(0xFF111827),
          textMuted: Color(0xFF6B7280),
          heroGradient: [Color(0xFF4B5563), Color(0xFF111827)],
          dark: false,
          animated: false,
        );
    }
  }
}
