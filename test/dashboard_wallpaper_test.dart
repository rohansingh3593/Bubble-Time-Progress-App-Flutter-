import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/constants/dashboard_themes.dart';
import 'package:momentum/widgets/dashboard_wallpaper_background.dart';

void main() {
  test('every selectable palette has an explicit wallpaper mapping', () {
    expect(dashboardWallpaperAssets.keys.toSet(),
        dashboardThemePickerPalettes.toSet());
  });

  testWidgets('all mapped wallpaper assets are bundled', (tester) async {
    for (final entry in dashboardWallpaperAssets.entries) {
      final asset = await rootBundle.load(entry.value);
      expect(asset.lengthInBytes, greaterThan(0), reason: entry.key.label);
      final dimensions = await tester.runAsync(() async {
        final codec =
            await ui.instantiateImageCodec(asset.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final dimensions =
            Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
        codec.dispose();
        return dimensions;
      });
      expect(dimensions, isNotNull, reason: entry.key.label);
      expect(dimensions!.width, greaterThan(0), reason: entry.key.label);
      expect(dimensions.height, greaterThan(0), reason: entry.key.label);
    }
  });

  testWidgets('palette changes select the corresponding wallpaper',
      (tester) async {
    Widget buildDashboard(DashboardPaletteType palette) {
      final style = DashboardThemeStyle.of(
        DashboardThemeType.light,
        palette: palette,
      );
      return MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: DashboardWallpaperBackground(
              palette: palette,
              style: style,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    const firstPalette = DashboardPaletteType.forestGlow;
    const nextPalette = DashboardPaletteType.oceanTeal;
    final firstAsset = dashboardWallpaperAssets[firstPalette]!;
    final nextAsset = dashboardWallpaperAssets[nextPalette]!;
    await tester.pumpWidget(buildDashboard(firstPalette));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>(firstAsset)), findsOneWidget);

    await tester.pumpWidget(buildDashboard(nextPalette));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>(nextAsset)), findsOneWidget);
    expect(find.byKey(ValueKey<String>(firstAsset)), findsNothing);
  });
}
