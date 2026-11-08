import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';

const dashboardWallpaperAssets = <DashboardPaletteType, String>{
  DashboardPaletteType.forestGlow:
      'assets/wallpapers/19_Forest_Glow_Version_2.png',
  DashboardPaletteType.emeraldGrey: 'assets/wallpapers/02_Emerald_Grey.png',
  DashboardPaletteType.oceanTeal: 'assets/wallpapers/23_Ocean_Teal.png',
  DashboardPaletteType.royalFocus:
      'assets/wallpapers/05_Royal_Focus_Wider_Coastline.png',
  DashboardPaletteType.purpleHaze:
      'assets/wallpapers/18_Purple_Haze_Version_2.png',
  DashboardPaletteType.roseBlush: 'assets/wallpapers/21_Rose_Blush.png',
  DashboardPaletteType.sunsetOrange:
      'assets/wallpapers/14_Sunset_Orange_Version_2.png',
  DashboardPaletteType.minimalCream: 'assets/wallpapers/06_Minimal_Cream.png',
  DashboardPaletteType.arcticBlue: 'assets/wallpapers/22_Arctic_Blue.png',
  DashboardPaletteType.oliveLuxe: 'assets/wallpapers/25_Olive_Luxe.png',
  DashboardPaletteType.mochaEarth: 'assets/wallpapers/26_Mocha_Earth.png',
  DashboardPaletteType.midnightNavy:
      'assets/wallpapers/13_Midnight_Navy_Version_2.png',
};

class DashboardWallpaperBackground extends StatelessWidget {
  const DashboardWallpaperBackground({
    super.key,
    required this.palette,
    required this.style,
    required this.child,
  });

  final DashboardPaletteType palette;
  final DashboardThemeStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final asset = dashboardWallpaperAssets[palette];
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 300);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: style.background),
        if (asset != null)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: duration,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild
                ],
              ),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Image.asset(
                asset,
                key: ValueKey(asset),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: style.background),
              ),
            ),
          ),
        ColoredBox(
          color: (style.dark ? Colors.black : Colors.white)
              .withValues(alpha: style.dark ? 0.45 : 0.22),
        ),
        child,
      ],
    );
  }
}
