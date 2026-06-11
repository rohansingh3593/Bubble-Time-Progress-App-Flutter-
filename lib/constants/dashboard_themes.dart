import 'package:flutter/material.dart';


enum DashboardPaletteType {
  seaCalm,
  emeraldGrey,
  springEnergy,
  happyPurple,
  pastelSky,
  neonPastel,
}

extension DashboardPaletteTypeX on DashboardPaletteType {
  String get storageKey => name;

  String get label {
    switch (this) {
      case DashboardPaletteType.seaCalm:
        return 'Sea Calm';
      case DashboardPaletteType.emeraldGrey:
        return 'Emerald Grey';
      case DashboardPaletteType.springEnergy:
        return 'Spring Energy';
      case DashboardPaletteType.happyPurple:
        return 'Happy Purple';
      case DashboardPaletteType.pastelSky:
        return 'Pastel Sky';
      case DashboardPaletteType.neonPastel:
        return 'Neon Pastel';
    }
  }

  List<Color> get colors {
    switch (this) {
      case DashboardPaletteType.seaCalm:
        return const [Color(0xFF1A312C), Color(0xFF428475), Color(0xFF89D7B7), Color(0xFFFFF4E1)];
      case DashboardPaletteType.emeraldGrey:
        return const [Color(0xFFEEEEEE), Color(0xFF6FCF97), Color(0xFF2FA084), Color(0xFF1F6F5F)];
      case DashboardPaletteType.springEnergy:
        return const [Color(0xFFF72C5B), Color(0xFFFF748B), Color(0xFFA7D477), Color(0xFFE4F1AC)];
      case DashboardPaletteType.happyPurple:
        return const [Color(0xFFFBF5A7), Color(0xFFFF97D0), Color(0xFFFF62BB), Color(0xFFB331F1)];
      case DashboardPaletteType.pastelSky:
        return const [Color(0xFF9FA1FF), Color(0xFFB5BAFF), Color(0xFFAEE2FF), Color(0xFFD9F9DF)];
      case DashboardPaletteType.neonPastel:
        return const [Color(0xFF45FFCA), Color(0xFFFEFFAC), Color(0xFFFFB6D9), Color(0xFFD67BFF)];
    }
  }

  Color get primary => colors[0];
  Color get secondary => colors[1];
  Color get accent => colors[2];
  Color get background => colors[3];
}

DashboardPaletteType dashboardPaletteTypeFromStorage(String? value) {
  return DashboardPaletteType.values.firstWhere(
    (palette) => palette.storageKey == value,
    orElse: () => DashboardPaletteType.seaCalm,
  );
}

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

  static DashboardThemeStyle of(DashboardThemeType type, {DashboardPaletteType? palette}) {
    if (palette != null) return _fromPalette(type, palette);
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

  static DashboardThemeStyle _fromPalette(DashboardThemeType type, DashboardPaletteType palette) {
    final colors = palette.colors;
    final background = _tint(colors[3], Colors.white, 0.28);
    final surface = _tint(colors[3], Colors.white, 0.58);
    final elevatedSurface = _tint(colors[2], Colors.white, 0.54);
    final primary = colors[0];
    final secondary = colors[1];
    final accent = colors[2];
    final textPrimary = _readableTextOn(background);
    final textMuted = textPrimary == Colors.white ? const Color(0xFFD7E8E2) : Color.lerp(primary, Colors.black54, 0.55)!;
    final dark = background.computeLuminance() < 0.35;
    return DashboardThemeStyle(
      type: type,
      background: background,
      surface: surface,
      elevatedSurface: elevatedSurface,
      primary: primary,
      secondary: secondary,
      accent: accent,
      textPrimary: textPrimary,
      textMuted: textMuted,
      heroGradient: [primary, secondary, accent],
      dark: dark,
      animated: true,
    );
  }

  static Color _tint(Color color, Color mix, double amount) {
    return Color.lerp(color, mix, amount) ?? color;
  }

  static Color _readableTextOn(Color color) {
    return color.computeLuminance() < 0.45 ? Colors.white : const Color(0xFF14211E);
  }

}
