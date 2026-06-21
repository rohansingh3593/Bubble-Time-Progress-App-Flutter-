import 'package:flutter/material.dart';

enum AppFontFamily {
  modern,
  elegant,
  minimal,
  friendly,
  professional,
  premium,
  classic,
  reading,
  rounded,
  tech,
  luxury,
  futuristic,
}

extension AppFontFamilyX on AppFontFamily {
  String get storageKey => name;

  String get label {
    switch (this) {
      case AppFontFamily.modern:
        return 'Modern';
      case AppFontFamily.elegant:
        return 'Elegant';
      case AppFontFamily.minimal:
        return 'Minimal';
      case AppFontFamily.friendly:
        return 'Friendly';
      case AppFontFamily.professional:
        return 'Professional';
      case AppFontFamily.premium:
        return 'Premium';
      case AppFontFamily.classic:
        return 'Classic';
      case AppFontFamily.reading:
        return 'Reading';
      case AppFontFamily.rounded:
        return 'Rounded';
      case AppFontFamily.tech:
        return 'Tech';
      case AppFontFamily.luxury:
        return 'Luxury';
      case AppFontFamily.futuristic:
        return 'Futuristic';
    }
  }

  String get familyName {
    switch (this) {
      case AppFontFamily.modern:
        return 'Inter';
      case AppFontFamily.elegant:
        return 'Poppins';
      case AppFontFamily.minimal:
        return 'Manrope';
      case AppFontFamily.friendly:
        return 'Nunito';
      case AppFontFamily.professional:
        return 'Roboto';
      case AppFontFamily.premium:
        return 'Outfit';
      case AppFontFamily.classic:
        return 'Lato';
      case AppFontFamily.reading:
        return 'Merriweather';
      case AppFontFamily.rounded:
        return 'Quicksand';
      case AppFontFamily.tech:
        return 'Space Grotesk';
      case AppFontFamily.luxury:
        return 'Plus Jakarta Sans';
      case AppFontFamily.futuristic:
        return 'Sora';
    }
  }

  String get description {
    switch (this) {
      case AppFontFamily.modern:
        return 'Recommended default • clean and modern';
      case AppFontFamily.elegant:
        return 'Rounded headlines and friendly cards';
      case AppFontFamily.minimal:
        return 'Minimal professional dashboards';
      case AppFontFamily.friendly:
        return 'Soft habit and journal style';
      case AppFontFamily.professional:
        return 'Material Design compatibility';
      case AppFontFamily.premium:
        return 'Premium startup feeling';
      case AppFontFamily.classic:
        return 'Simple elegant long text';
      case AppFontFamily.reading:
        return 'Reading-focused notes and reflections';
      case AppFontFamily.rounded:
        return 'Playful habits and reflection';
      case AppFontFamily.tech:
        return 'Analytics, XP, and statistics';
      case AppFontFamily.luxury:
        return 'Luxury SaaS profile style';
      case AppFontFamily.futuristic:
        return 'Rank, XP, and hero cards';
    }
  }
}

AppFontFamily appFontFamilyFromStorage(String? value) {
  return AppFontFamily.values.firstWhere(
    (font) => font.storageKey == value,
    orElse: () => AppFontFamily.modern,
  );
}

enum AppFontScale { small, medium, large, extraLarge }

extension AppFontScaleX on AppFontScale {
  String get storageKey => name;
  String get label {
    switch (this) {
      case AppFontScale.small:
        return 'Small';
      case AppFontScale.medium:
        return 'Medium';
      case AppFontScale.large:
        return 'Large';
      case AppFontScale.extraLarge:
        return 'Extra Large';
    }
  }

  double get scale {
    switch (this) {
      case AppFontScale.small:
        return 0.90;
      case AppFontScale.medium:
        return 1.0;
      case AppFontScale.large:
        return 1.08;
      case AppFontScale.extraLarge:
        return 1.15;
    }
  }
}

AppFontScale appFontScaleFromStorage(String? value) {
  return AppFontScale.values.firstWhere(
    (scale) => scale.storageKey == value,
    orElse: () => AppFontScale.medium,
  );
}

enum AppFontWeightChoice { light, regular, medium, semiBold, bold, extraBold }

extension AppFontWeightChoiceX on AppFontWeightChoice {
  String get storageKey => name;
  String get label {
    switch (this) {
      case AppFontWeightChoice.light:
        return 'Light';
      case AppFontWeightChoice.regular:
        return 'Regular';
      case AppFontWeightChoice.medium:
        return 'Medium';
      case AppFontWeightChoice.semiBold:
        return 'SemiBold';
      case AppFontWeightChoice.bold:
        return 'Bold';
      case AppFontWeightChoice.extraBold:
        return 'ExtraBold';
    }
  }

  FontWeight get weight {
    switch (this) {
      case AppFontWeightChoice.light:
        return FontWeight.w300;
      case AppFontWeightChoice.regular:
        return FontWeight.w400;
      case AppFontWeightChoice.medium:
        return FontWeight.w500;
      case AppFontWeightChoice.semiBold:
        return FontWeight.w600;
      case AppFontWeightChoice.bold:
        return FontWeight.w700;
      case AppFontWeightChoice.extraBold:
        return FontWeight.w800;
    }
  }
}

AppFontWeightChoice appFontWeightFromStorage(String? value) {
  return AppFontWeightChoice.values.firstWhere(
    (weight) => weight.storageKey == value,
    orElse: () => AppFontWeightChoice.semiBold,
  );
}

enum DashboardLayoutStyle { classic, modern, glass, minimal, cards, compact }

extension DashboardLayoutStyleX on DashboardLayoutStyle {
  String get storageKey => name;

  String get label {
    switch (this) {
      case DashboardLayoutStyle.classic:
        return 'Classic';
      case DashboardLayoutStyle.modern:
        return 'Modern';
      case DashboardLayoutStyle.glass:
        return 'Glass';
      case DashboardLayoutStyle.minimal:
        return 'Minimal';
      case DashboardLayoutStyle.cards:
        return 'Cards';
      case DashboardLayoutStyle.compact:
        return 'Compact';
    }
  }
}

DashboardLayoutStyle dashboardLayoutStyleFromStorage(String? value) {
  return DashboardLayoutStyle.values.firstWhere(
    (layout) => layout.storageKey == value,
    orElse: () => DashboardLayoutStyle.modern,
  );
}

enum DashboardCardAnimationStyle { fade, slide, scale, bounce, flip, none }

extension DashboardCardAnimationStyleX on DashboardCardAnimationStyle {
  String get storageKey => name;

  String get label {
    switch (this) {
      case DashboardCardAnimationStyle.fade:
        return 'Fade';
      case DashboardCardAnimationStyle.slide:
        return 'Slide';
      case DashboardCardAnimationStyle.scale:
        return 'Scale';
      case DashboardCardAnimationStyle.bounce:
        return 'Bounce';
      case DashboardCardAnimationStyle.flip:
        return 'Flip';
      case DashboardCardAnimationStyle.none:
        return 'None';
    }
  }
}

DashboardCardAnimationStyle dashboardCardAnimationStyleFromStorage(String? value) {
  return DashboardCardAnimationStyle.values.firstWhere(
    (animation) => animation.storageKey == value,
    orElse: () => DashboardCardAnimationStyle.fade,
  );
}

enum DashboardAnimationSpeed { slow, normal, fast, instant }

extension DashboardAnimationSpeedX on DashboardAnimationSpeed {
  String get storageKey => name;

  String get label {
    switch (this) {
      case DashboardAnimationSpeed.slow:
        return 'Slow';
      case DashboardAnimationSpeed.normal:
        return 'Normal';
      case DashboardAnimationSpeed.fast:
        return 'Fast';
      case DashboardAnimationSpeed.instant:
        return 'Instant';
    }
  }

  Duration get duration {
    switch (this) {
      case DashboardAnimationSpeed.slow:
        return const Duration(milliseconds: 500);
      case DashboardAnimationSpeed.normal:
        return const Duration(milliseconds: 350);
      case DashboardAnimationSpeed.fast:
        return const Duration(milliseconds: 180);
      case DashboardAnimationSpeed.instant:
        return Duration.zero;
    }
  }
}

DashboardAnimationSpeed dashboardAnimationSpeedFromStorage(String? value) {
  return DashboardAnimationSpeed.values.firstWhere(
    (speed) => speed.storageKey == value,
    orElse: () => DashboardAnimationSpeed.normal,
  );
}

enum DashboardChartStyle { flat, gradient, glass, minimal, animated }

extension DashboardChartStyleX on DashboardChartStyle {
  String get storageKey => name;

  String get label {
    switch (this) {
      case DashboardChartStyle.flat:
        return 'Flat';
      case DashboardChartStyle.gradient:
        return 'Gradient';
      case DashboardChartStyle.glass:
        return 'Glass';
      case DashboardChartStyle.minimal:
        return 'Minimal';
      case DashboardChartStyle.animated:
        return 'Animated';
    }
  }
}

DashboardChartStyle dashboardChartStyleFromStorage(String? value) {
  return DashboardChartStyle.values.firstWhere(
    (chart) => chart.storageKey == value,
    orElse: () => DashboardChartStyle.gradient,
  );
}

enum DashboardIconPack { outlined, filled, rounded, minimal, material }

extension DashboardIconPackX on DashboardIconPack {
  String get storageKey => name;

  String get label {
    switch (this) {
      case DashboardIconPack.outlined:
        return 'Outlined';
      case DashboardIconPack.filled:
        return 'Filled';
      case DashboardIconPack.rounded:
        return 'Rounded';
      case DashboardIconPack.minimal:
        return 'Minimal';
      case DashboardIconPack.material:
        return 'Material';
    }
  }
}

DashboardIconPack dashboardIconPackFromStorage(String? value) {
  return DashboardIconPack.values.firstWhere(
    (pack) => pack.storageKey == value,
    orElse: () => DashboardIconPack.rounded,
  );
}

enum DashboardPaletteType {
  seaCalm,
  emeraldGrey,
  springEnergy,
  happyPurple,
  royalFocus,
  minimalCream,
  fieryOcean,
  refreshingSummerFun,
  earthyForestHues,
  oliveGardenFeast,
  aquaFocus,
  vividNightfall,
  midnightNavy,
  sunsetOrange,
  oceanBlue,
  roseGold,
  forest,
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
      case DashboardPaletteType.royalFocus:
        return 'Royal Focus';
      case DashboardPaletteType.minimalCream:
        return 'Minimal Cream';
      case DashboardPaletteType.fieryOcean:
        return 'Fiery Ocean';
      case DashboardPaletteType.refreshingSummerFun:
        return 'Refreshing Summer Fun';
      case DashboardPaletteType.earthyForestHues:
        return 'Earthy Forest Hues';
      case DashboardPaletteType.oliveGardenFeast:
        return 'Olive Garden Feast';
      case DashboardPaletteType.aquaFocus:
        return 'Aqua Focus';
      case DashboardPaletteType.vividNightfall:
        return 'Vivid Nightfall';
      case DashboardPaletteType.midnightNavy:
        return 'Midnight Navy';
      case DashboardPaletteType.sunsetOrange:
        return 'Sunset Orange';
      case DashboardPaletteType.oceanBlue:
        return 'Ocean Blue';
      case DashboardPaletteType.roseGold:
        return 'Rose Gold';
      case DashboardPaletteType.forest:
        return 'Forest';
    }
  }

  List<Color> get colors {
    switch (this) {
      case DashboardPaletteType.seaCalm:
        return const [Color(0xFF0F8F83), Color(0xFF2EC4B6), Color(0xFFFFD166), Color(0xFFEAFBF7), Color(0xFFFFFFFF), Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF5EEAD4)];
      case DashboardPaletteType.emeraldGrey:
        return const [Color(0xFF047857), Color(0xFF10B981), Color(0xFFA7F3D0), Color(0xFFF3F7F5), Color(0xFFFFFFFF), Color(0xFF065F46), Color(0xFF047857), Color(0xFF34D399)];
      case DashboardPaletteType.springEnergy:
        return const [Color(0xFF16A34A), Color(0xFF84CC16), Color(0xFFFB923C), Color(0xFFF7FEE7), Color(0xFFFFFFFF), Color(0xFF16A34A), Color(0xFF65A30D), Color(0xFFFACC15)];
      case DashboardPaletteType.happyPurple:
        return const [Color(0xFF7C3AED), Color(0xFFA78BFA), Color(0xFFF472B6), Color(0xFFF5F3FF), Color(0xFFFFFFFF), Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFFC084FC)];
      case DashboardPaletteType.royalFocus:
        return const [Color(0xFF2563EB), Color(0xFF38BDF8), Color(0xFFF59E0B), Color(0xFFEFF6FF), Color(0xFFFFFFFF), Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF60A5FA)];
      case DashboardPaletteType.minimalCream:
        return const [Color(0xFF92400E), Color(0xFFD97706), Color(0xFFFBBF24), Color(0xFFFFFBEB), Color(0xFFFFFFFF), Color(0xFF92400E), Color(0xFFD97706), Color(0xFFFBBF24)];
      case DashboardPaletteType.fieryOcean:
        return fieryOcean.paletteColors;
      case DashboardPaletteType.refreshingSummerFun:
        return refreshingSummerFun.paletteColors;
      case DashboardPaletteType.earthyForestHues:
        return earthyForestHues.paletteColors;
      case DashboardPaletteType.oliveGardenFeast:
        return oliveGardenFeast.paletteColors;
      case DashboardPaletteType.aquaFocus:
        return aquaFocus.paletteColors;
      case DashboardPaletteType.vividNightfall:
        return vividNightfall.paletteColors;
      case DashboardPaletteType.midnightNavy:
        return const [Color(0xFF2563EB), Color(0xFF38BDF8), Color(0xFF22C55E), Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF38BDF8)];
      case DashboardPaletteType.sunsetOrange:
        return const [Color(0xFFEA580C), Color(0xFFFB923C), Color(0xFFFACC15), Color(0xFFFFF7ED), Color(0xFFFFFFFF), Color(0xFFC2410C), Color(0xFFEA580C), Color(0xFFFB923C)];
      case DashboardPaletteType.oceanBlue:
        return const [Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFF7DD3FC), Color(0xFFF0F9FF), Color(0xFFFFFFFF), Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)];
      case DashboardPaletteType.roseGold:
        return const [Color(0xFFDB2777), Color(0xFFF472B6), Color(0xFFFB7185), Color(0xFFFFF1F2), Color(0xFFFFFFFF), Color(0xFFBE185D), Color(0xFFDB2777), Color(0xFFF472B6)];
      case DashboardPaletteType.forest:
        return const [Color(0xFF166534), Color(0xFF22C55E), Color(0xFFA3E635), Color(0xFFF0FDF4), Color(0xFFFFFFFF), Color(0xFF14532D), Color(0xFF166534), Color(0xFF22C55E)];
    }
  }

  Color get primary => colors[0];
  Color get secondary => colors[1];
  Color get accent => colors[2];
  Color get background => colors[3];
  Color get surface => colors[4];
  List<Color> get heroGradient => [colors[5], colors[6], colors[7]];

  DashboardThemeConfig? get config {
    switch (this) {
      case DashboardPaletteType.seaCalm:
        return seaCalmTheme;
      case DashboardPaletteType.emeraldGrey:
        return emeraldGreyTheme;
      case DashboardPaletteType.springEnergy:
        return springEnergyTheme;
      case DashboardPaletteType.happyPurple:
        return happyPurpleTheme;
      case DashboardPaletteType.royalFocus:
        return royalFocusTheme;
      case DashboardPaletteType.minimalCream:
        return minimalCreamTheme;
      case DashboardPaletteType.fieryOcean:
        return fieryOcean;
      case DashboardPaletteType.refreshingSummerFun:
        return refreshingSummerFun;
      case DashboardPaletteType.earthyForestHues:
        return earthyForestHues;
      case DashboardPaletteType.oliveGardenFeast:
        return oliveGardenFeast;
      case DashboardPaletteType.aquaFocus:
        return aquaFocus;
      case DashboardPaletteType.vividNightfall:
        return vividNightfall;
      case DashboardPaletteType.midnightNavy:
      case DashboardPaletteType.sunsetOrange:
      case DashboardPaletteType.oceanBlue:
      case DashboardPaletteType.roseGold:
      case DashboardPaletteType.forest:
        return null;
    }
  }
}


DashboardPaletteType dashboardPaletteTypeFromStorage(String? value) {
  return DashboardPaletteType.values.firstWhere(
    (palette) => palette.storageKey == value,
    orElse: () => DashboardPaletteType.seaCalm,
  );
}


class DashboardThemeConfig {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color cardTint;
  final Color text;
  final Color mutedText;
  final Color success;
  final Color warning;
  final Color danger;

  const DashboardThemeConfig({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.cardTint,
    required this.text,
    required this.mutedText,
    required this.success,
    required this.warning,
    required this.danger,
  });

  List<Color> get paletteColors => [primary, secondary, accent, background, surface, primary, secondary, accent];
}

const seaCalmTheme = DashboardThemeConfig(id: 'sea_calm', name: 'Sea Calm', primary: Color(0xFF0F8F83), secondary: Color(0xFF2EC4B6), accent: Color(0xFFFFD166), background: Color(0xFFEAFBF7), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFDDF6F1), text: Color(0xFF0F172A), mutedText: Color(0xFF335C67), success: Color(0xFF22C55E), warning: Color(0xFFF59E0B), danger: Color(0xFFEF4444));
const emeraldGreyTheme = DashboardThemeConfig(id: 'emerald_grey', name: 'Emerald Grey', primary: Color(0xFF047857), secondary: Color(0xFF10B981), accent: Color(0xFFA7F3D0), background: Color(0xFFF3F7F5), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFE7F4EF), text: Color(0xFF111827), mutedText: Color(0xFF4B5F55), success: Color(0xFF22C55E), warning: Color(0xFFF59E0B), danger: Color(0xFFEF4444));
const springEnergyTheme = DashboardThemeConfig(id: 'spring_energy', name: 'Spring Energy', primary: Color(0xFF16A34A), secondary: Color(0xFF84CC16), accent: Color(0xFFFB923C), background: Color(0xFFF7FEE7), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFECFCCB), text: Color(0xFF1F2937), mutedText: Color(0xFF4D5F2F), success: Color(0xFF22C55E), warning: Color(0xFFFB923C), danger: Color(0xFFEF4444));
const happyPurpleTheme = DashboardThemeConfig(id: 'happy_purple', name: 'Happy Purple', primary: Color(0xFF7C3AED), secondary: Color(0xFFA78BFA), accent: Color(0xFFF472B6), background: Color(0xFFF5F3FF), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFEDE9FE), text: Color(0xFF2E1065), mutedText: Color(0xFF5B4B8A), success: Color(0xFF22C55E), warning: Color(0xFFF59E0B), danger: Color(0xFFEF4444));
const royalFocusTheme = DashboardThemeConfig(id: 'royal_focus', name: 'Royal Focus', primary: Color(0xFF2563EB), secondary: Color(0xFF38BDF8), accent: Color(0xFFF59E0B), background: Color(0xFFEFF6FF), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFDBEAFE), text: Color(0xFF111827), mutedText: Color(0xFF31586A), success: Color(0xFF22C55E), warning: Color(0xFFF59E0B), danger: Color(0xFFEF4444));
const minimalCreamTheme = DashboardThemeConfig(id: 'minimal_cream', name: 'Minimal Cream', primary: Color(0xFF92400E), secondary: Color(0xFFD97706), accent: Color(0xFFFBBF24), background: Color(0xFFFFFBEB), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFFEF3C7), text: Color(0xFF2D241A), mutedText: Color(0xFF756B5D), success: Color(0xFF22C55E), warning: Color(0xFFD97706), danger: Color(0xFFEF4444));
const fieryOcean = DashboardThemeConfig(id: 'fiery_ocean', name: 'Fiery Ocean', primary: Color(0xFFC1121F), secondary: Color(0xFF003049), accent: Color(0xFFFDF0D5), background: Color(0xFFFFF7F1), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFFDF0D5), text: Color(0xFF111827), mutedText: Color(0xFF555555), success: Color(0xFF16A34A), warning: Color(0xFFBC6C25), danger: Color(0xFFC1121F));
const refreshingSummerFun = DashboardThemeConfig(id: 'refreshing_summer_fun', name: 'Refreshing Summer Fun', primary: Color(0xFF219EBC), secondary: Color(0xFF8ECAE6), accent: Color(0xFFFFB703), background: Color(0xFFEAF8FF), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFDDF6FF), text: Color(0xFF023047), mutedText: Color(0xFF31586A), success: Color(0xFF22C55E), warning: Color(0xFFFFB703), danger: Color(0xFFEF4444));
const earthyForestHues = DashboardThemeConfig(id: 'earthy_forest_hues', name: 'Earthy Forest Hues', primary: Color(0xFF588157), secondary: Color(0xFFA3B18A), accent: Color(0xFF344E41), background: Color(0xFFF4F6EF), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFE9F0E3), text: Color(0xFF1F2937), mutedText: Color(0xFF4B5F55), success: Color(0xFF588157), warning: Color(0xFFDDA15E), danger: Color(0xFFB91C1C));
const oliveGardenFeast = DashboardThemeConfig(id: 'olive_garden_feast', name: 'Olive Garden Feast', primary: Color(0xFF606C38), secondary: Color(0xFFDDA15E), accent: Color(0xFFBC6C25), background: Color(0xFFFFFCF0), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFFEFAE0), text: Color(0xFF283618), mutedText: Color(0xFF5F5F45), success: Color(0xFF606C38), warning: Color(0xFFDDA15E), danger: Color(0xFFB91C1C));
const aquaFocus = DashboardThemeConfig(id: 'aqua_focus', name: 'Aqua Focus', primary: Color(0xFF0096C7), secondary: Color(0xFF48CAE4), accent: Color(0xFF023E8A), background: Color(0xFFEAFBFF), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFDDF8FF), text: Color(0xFF03045E), mutedText: Color(0xFF335C67), success: Color(0xFF22C55E), warning: Color(0xFFFFB703), danger: Color(0xFFEF4444));
const vividNightfall = DashboardThemeConfig(id: 'vivid_nightfall', name: 'Vivid Nightfall', primary: Color(0xFF7B2CBF), secondary: Color(0xFF9D4EDD), accent: Color(0xFF5A189A), background: Color(0xFFF8F0FF), surface: Color(0xFFFFFFFF), cardTint: Color(0xFFF1E4FF), text: Color(0xFF10002B), mutedText: Color(0xFF4C3575), success: Color(0xFF22C55E), warning: Color(0xFFF59E0B), danger: Color(0xFFEF4444));

final List<DashboardThemeConfig> dashboardThemes = [
  seaCalmTheme,
  emeraldGreyTheme,
  springEnergyTheme,
  happyPurpleTheme,
  royalFocusTheme,
  minimalCreamTheme,
  fieryOcean,
  refreshingSummerFun,
  earthyForestHues,
  oliveGardenFeast,
  aquaFocus,
  vividNightfall,
];

const List<DashboardPaletteType> dashboardThemePickerPalettes = [
  DashboardPaletteType.seaCalm,
  DashboardPaletteType.emeraldGrey,
  DashboardPaletteType.springEnergy,
  DashboardPaletteType.happyPurple,
  DashboardPaletteType.royalFocus,
  DashboardPaletteType.minimalCream,
  DashboardPaletteType.fieryOcean,
  DashboardPaletteType.refreshingSummerFun,
  DashboardPaletteType.earthyForestHues,
  DashboardPaletteType.oliveGardenFeast,
  DashboardPaletteType.aquaFocus,
  DashboardPaletteType.vividNightfall,
];

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
  final Color? success;
  final Color? warning;
  final Color? danger;
  final Color? cardTint;
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
    this.success,
    this.warning,
    this.danger,
    this.cardTint,
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
    final primary = palette.primary;
    final secondary = palette.secondary;
    final accent = palette.accent;
    final base = palette.background;
    final paletteSurface = palette.surface;
    final paletteHero = palette.heroGradient;
    final config = palette.config;

    DashboardThemeStyle build({
      required Color background,
      required Color surface,
      required Color elevatedSurface,
      required Color textPrimary,
      required Color textMuted,
      required List<Color> heroGradient,
      required bool dark,
      Color? success,
      Color? warning,
      Color? danger,
      Color? cardTint,
      bool animated = true,
    }) {
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
        success: success,
        warning: warning,
        danger: danger,
        cardTint: cardTint,
        heroGradient: heroGradient,
        dark: dark,
        animated: animated,
      );
    }

    if (palette == DashboardPaletteType.midnightNavy) {
      return DashboardThemeStyle(
        type: type,
        background: base,
        surface: paletteSurface,
        elevatedSurface: _tint(paletteSurface, secondary, 0.16),
        primary: primary,
        secondary: secondary,
        accent: accent,
        textPrimary: Colors.white,
        textMuted: _tint(secondary, Colors.white, 0.42),
        success: config?.success,
        warning: config?.warning,
        danger: config?.danger,
        cardTint: config?.cardTint,
        heroGradient: paletteHero,
        dark: true,
        animated: true,
      );
    }

    if (type == DashboardThemeType.calm || type == DashboardThemeType.light || type == DashboardThemeType.minimal) {
      return DashboardThemeStyle(
        type: type,
        background: base,
        surface: paletteSurface,
        elevatedSurface: _tint(base, primary, 0.08),
        primary: primary,
        secondary: secondary,
        accent: accent,
        textPrimary: config?.text ?? _readableTextOn(base),
        textMuted: config?.mutedText ?? Color.lerp(primary, Colors.black54, 0.56)!,
        success: config?.success,
        warning: config?.warning,
        danger: config?.danger,
        cardTint: config?.cardTint,
        heroGradient: paletteHero,
        dark: false,
        animated: type != DashboardThemeType.calm && type != DashboardThemeType.minimal,
      );
    }

    switch (type) {
      case DashboardThemeType.light:
        final background = _tint(base, Colors.white, 0.36);
        return build(
          background: background,
          surface: _tint(base, Colors.white, 0.68),
          elevatedSurface: _tint(accent, Colors.white, 0.62),
          textPrimary: _readableTextOn(background),
          textMuted: Color.lerp(primary, Colors.black54, 0.56)!,
          heroGradient: [secondary, accent, primary],
          dark: false,
        );
      case DashboardThemeType.dark:
        return build(
          background: _tint(primary, Colors.black, 0.74),
          surface: _tint(primary, Colors.black, 0.58),
          elevatedSurface: _tint(secondary, Colors.black, 0.52),
          textPrimary: Colors.white,
          textMuted: _tint(accent, Colors.white, 0.38),
          heroGradient: [_tint(primary, Colors.black, 0.18), _tint(secondary, Colors.black, 0.20), _tint(accent, Colors.black, 0.26)],
          dark: true,
        );
      case DashboardThemeType.gamified:
        return build(
          background: _tint(secondary, Colors.black, 0.68),
          surface: _tint(secondary, Colors.black, 0.46),
          elevatedSurface: _tint(accent, Colors.black, 0.34),
          textPrimary: Colors.white,
          textMuted: _tint(base, Colors.white, 0.18),
          heroGradient: [primary, secondary, accent],
          dark: true,
        );
      case DashboardThemeType.calm:
        final background = _tint(base, const Color(0xFFFFF7EA), 0.46);
        return build(
          background: background,
          surface: _tint(base, Colors.white, 0.74),
          elevatedSurface: _tint(accent, const Color(0xFFFFF7EA), 0.60),
          textPrimary: const Color(0xFF2D241A),
          textMuted: Color.lerp(primary, const Color(0xFF756B5D), 0.58)!,
          heroGradient: [primary, _tint(secondary, const Color(0xFFE89A5B), 0.35)],
          dark: false,
          animated: false,
        );
      case DashboardThemeType.minimal:
        return build(
          background: _tint(base, const Color(0xFFF3F4F6), 0.72),
          surface: _tint(base, Colors.white, 0.88),
          elevatedSurface: _tint(accent, const Color(0xFFE5E7EB), 0.74),
          textPrimary: const Color(0xFF111827),
          textMuted: const Color(0xFF6B7280),
          heroGradient: [_tint(primary, const Color(0xFF4B5563), 0.42), _tint(secondary, const Color(0xFF111827), 0.28)],
          dark: false,
          animated: false,
        );
    }
  }

  static Color _tint(Color color, Color mix, double amount) {
    return Color.lerp(color, mix, amount) ?? color;
  }

  static Color _readableTextOn(Color color) {
    return color.computeLuminance() < 0.45 ? Colors.white : const Color(0xFF14211E);
  }

}



class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color cardDark;
  final Color primary;
  final Color primarySoft;
  final Color secondary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color buttonBackground;
  final Color buttonText;
  final Color selectedBackground;
  final Color selectedBorder;
  final Color chipBackground;
  final Color chipText;
  final Color shadow;
  final List<Color> chartColors;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.cardDark,
    required this.primary,
    required this.primarySoft,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.buttonBackground,
    required this.buttonText,
    required this.selectedBackground,
    required this.selectedBorder,
    required this.chipBackground,
    required this.chipText,
    required this.shadow,
    required this.chartColors,
  });

  factory AppThemeColors.fromDashboardStyle(DashboardThemeStyle style) {
    final card = style.cardTint ??
        (style.dark
            ? DashboardThemeStyle._tint(style.surface, style.primary, 0.16)
            : DashboardThemeStyle._tint(style.elevatedSurface, style.surface, 0.24));
    final cardDark = style.dark
        ? DashboardThemeStyle._tint(style.surface, style.primary, 0.26)
        : DashboardThemeStyle._tint(style.primary, style.elevatedSurface, 0.72);
    final selectedBackground = style.primary;
    final chipBackground = style.surface;
    final success = style.success ?? Color.lerp(style.primary, style.accent, 0.42)!;
    final warning = style.warning ?? Color.lerp(const Color(0xFFFACC15), style.secondary, style.dark ? 0.22 : 0.08)!;
    final danger = style.danger ?? Color.lerp(style.secondary, style.primary, 0.22)!;
    return AppThemeColors(
      background: style.background,
      surface: style.surface,
      surfaceVariant: style.elevatedSurface,
      card: card,
      cardDark: cardDark,
      primary: style.primary,
      primarySoft: Color.lerp(style.surface, style.primary, style.dark ? 0.30 : 0.18)!,
      secondary: style.secondary,
      accent: style.accent,
      success: success,
      warning: warning,
      danger: danger,
      border: Color.lerp(style.textMuted, style.primary, 0.32)!.withOpacity(style.dark ? 0.38 : 0.26),
      divider: Color.lerp(style.surface, style.textMuted, style.dark ? 0.30 : 0.18)!,
      textPrimary: style.textPrimary,
      textSecondary: style.textMuted,
      textMuted: style.textMuted,
      buttonBackground: style.primary,
      buttonText: readableTextOn(style.primary, style),
      selectedBackground: selectedBackground,
      selectedBorder: style.accent,
      chipBackground: chipBackground,
      chipText: readableTextOn(chipBackground, style),
      shadow: style.primary.withOpacity(style.dark ? 0.36 : 0.24),
      chartColors: [style.primary, style.secondary, style.accent, success, warning, danger],
    );
  }

  Color get secondaryBackground => surfaceVariant;
  Color get dialogBackground => surface;
  Color get sheetBackground => surface;
  Color get primaryCard => card;
  Color get secondaryCard => surfaceVariant;
  Color get elevatedCard => surfaceVariant;
  Color get disabledCard => surfaceVariant.withOpacity(0.62);
  Color get selectedCard => selectedBackground;
  Color get cardTint => primarySoft;
  Color get filledButton => buttonBackground;
  Color get outlinedButton => primary;
  Color get ghostButton => primarySoft;
  Color get disabledButton => disabledCard;
  Color get dangerButton => danger;
  Color get successButton => success;
  Color get heading => textPrimary;
  Color get subtitle => textSecondary;
  Color get body => textPrimary;
  Color get caption => textMuted;
  Color get hint => textMuted;
  Color get disabledText => textMuted.withOpacity(0.64);
  Color get inverseText => buttonText;
  Color get progress => primary;
  Color get track => surfaceVariant;
  Color get completed => success;
  Color get pending => warning;
  Color get overdue => danger;
  Color get disabled => textMuted;
  Color get instruction => primary;
  Color get goal => secondary;
  Color get reward => accent;
  Color get skipped => textMuted;
  Color get bonus => success;
  Color get coins => accent;
  Color get xp => secondary;
  Color get muted => textMuted;
  Color get mutedSurface => surfaceVariant.withOpacity(0.70);
  Color get primaryLight => primarySoft;
  Color get successLight => success.withOpacity(0.18);
  Color get neutral => secondary;
  Color get primaryGlow => primary.withOpacity(0.08);

  static Color readableTextOn(Color background, DashboardThemeStyle style) {
    return background.computeLuminance() < 0.45 ? (style.dark ? style.textPrimary : style.surface) : style.textPrimary;
  }

  @override
  AppThemeColors copyWith() => this;

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) => this;
}



extension DashboardThemeContext on BuildContext {
  AppThemeColors get dashboardTheme => Theme.of(this).extension<AppThemeColors>() ??
      AppThemeColors.fromDashboardStyle(DashboardThemeStyle.of(DashboardThemeType.light));
}
