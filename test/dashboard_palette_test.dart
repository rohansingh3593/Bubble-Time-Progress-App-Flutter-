import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/constants/dashboard_themes.dart';

void main() {
  const palettes = <DashboardPaletteType, String>{
    DashboardPaletteType.forestGlow: 'Forest Glow',
    DashboardPaletteType.emeraldGrey: 'Emerald Grey',
    DashboardPaletteType.oceanTeal: 'Ocean Teal',
    DashboardPaletteType.royalFocus: 'Royal Focus',
    DashboardPaletteType.purpleHaze: 'Purple Haze',
    DashboardPaletteType.roseBlush: 'Rose Blush',
    DashboardPaletteType.sunsetOrange: 'Sunset Orange',
    DashboardPaletteType.minimalCream: 'Minimal Cream',
    DashboardPaletteType.arcticBlue: 'Arctic Blue',
    DashboardPaletteType.oliveLuxe: 'Olive Luxe',
    DashboardPaletteType.mochaEarth: 'Mocha Earth',
    DashboardPaletteType.midnightNavy: 'Midnight Navy',
  };

  test('recommended palettes are the only picker and settings options', () {
    final recommendedPalettes = palettes.keys.toList();
    expect(DashboardPaletteType.values, recommendedPalettes);
    expect(dashboardThemePickerPalettes, recommendedPalettes);
    expect(dashboardThemes.map((theme) => theme.name).toList(),
        palettes.values.toList());
    for (final entry in palettes.entries) {
      expect(entry.key.label, entry.value);
      expect(dashboardPaletteTypeFromStorage(entry.key.storageKey), entry.key);
    }
  });

  test('removed palette preferences migrate to their recommended equivalent',
      () {
    const aliases = <String, DashboardPaletteType>{
      'seaCalm': DashboardPaletteType.oceanTeal,
      'springEnergy': DashboardPaletteType.forestGlow,
      'happyPurple': DashboardPaletteType.purpleHaze,
      'fieryOcean': DashboardPaletteType.royalFocus,
      'refreshingSummerFun': DashboardPaletteType.royalFocus,
      'earthyForestHues': DashboardPaletteType.forestGlow,
      'oliveGardenFeast': DashboardPaletteType.oliveLuxe,
      'aquaFocus': DashboardPaletteType.royalFocus,
      'vividNightfall': DashboardPaletteType.purpleHaze,
      'sunsetFusion': DashboardPaletteType.sunsetOrange,
      'neonPop': DashboardPaletteType.roseBlush,
      'oceanBlue': DashboardPaletteType.royalFocus,
      'roseGold': DashboardPaletteType.roseBlush,
      'forest': DashboardPaletteType.forestGlow,
    };
    for (final entry in aliases.entries) {
      expect(dashboardPaletteTypeFromStorage(entry.key), entry.value);
    }
    expect(
        dashboardPaletteTypeFromStorage(null), DashboardPaletteType.forestGlow);
    expect(dashboardPaletteTypeFromStorage('unknown'),
        DashboardPaletteType.forestGlow);
  });

  test('configured palettes resolve light and dark theme styles', () {
    for (final palette in palettes.keys) {
      expect(palette.colors, hasLength(8));
      final config = palette.config;
      if (config == null) continue;

      final light =
          DashboardThemeStyle.of(DashboardThemeType.light, palette: palette);
      final dark =
          DashboardThemeStyle.of(DashboardThemeType.dark, palette: palette);
      final gamified =
          DashboardThemeStyle.of(DashboardThemeType.gamified, palette: palette);

      if (palette == DashboardPaletteType.midnightNavy) {
        expect(light.dark, isTrue);
        expect(light.background, config.darkBackground);
      } else {
        expect(light.background, config.background);
        expect(light.textPrimary, config.text);
      }
      if (config.darkBackground != null &&
          palette != DashboardPaletteType.midnightNavy) {
        expect(dark.background, config.darkBackground);
        expect(dark.surface, config.darkSurface);
        expect(dark.textPrimary, config.darkText);
        expect(gamified.background, config.darkBackground);
      }
      expect(dark.dark, isTrue);
      expect(gamified.dark, isTrue);
    }
  });
}
