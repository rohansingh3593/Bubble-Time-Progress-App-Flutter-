import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/task_model.dart';
import 'models/motivation_motto.dart';
import 'services/hive_service.dart';
import 'screens/dashboard_view.dart';
import 'screens/year_view.dart';
import 'screens/month_view.dart';
import 'screens/week_view.dart';
import 'screens/day_view.dart';
import 'screens/streak_view.dart';
import 'screens/task_screen.dart';
import 'screens/instruction_dashboard_view.dart';
import 'screens/goal_dashboard_view.dart';
import 'screens/reward_money_history_view.dart';
import 'screens/motivation_motto_dashboard_view.dart';
import 'screens/productivity_timeline_view.dart';
import 'models/rank_profile.dart';
import 'constants/dashboard_themes.dart';
import 'utils/text_formatters.dart';
import 'widgets/app_text.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureFlutterFrameworkErrorFiltering();
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TaskAdapter());
  }

  await HiveService.instance.init();

  runApp(MyApp(hiveService: HiveService.instance));
}


void _configureFlutterFrameworkErrorFiltering() {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final library = details.library?.toLowerCase() ?? '';
    final isWindowsAltKeyFrameworkNoise = library.contains('services') &&
        message.contains('Attempted to send a key down event') &&
        message.contains('keysPressed');

    if (isWindowsAltKeyFrameworkNoise) return;

    defaultOnError?.call(details);
  };
}

class MyApp extends StatelessWidget {
  final HiveService hiveService;

  const MyApp({super.key, required this.hiveService});

  TextTheme _googleFontTextTheme(AppFontFamily fontFamily, TextTheme base) {
    switch (fontFamily) {
      case AppFontFamily.modern:
        return GoogleFonts.interTextTheme(base);
      case AppFontFamily.elegant:
        return GoogleFonts.poppinsTextTheme(base);
      case AppFontFamily.minimal:
        return GoogleFonts.manropeTextTheme(base);
      case AppFontFamily.friendly:
        return GoogleFonts.nunitoTextTheme(base);
      case AppFontFamily.professional:
        return GoogleFonts.robotoTextTheme(base);
      case AppFontFamily.premium:
        return GoogleFonts.outfitTextTheme(base);
      case AppFontFamily.classic:
        return GoogleFonts.latoTextTheme(base);
      case AppFontFamily.reading:
        return GoogleFonts.merriweatherTextTheme(base);
      case AppFontFamily.rounded:
        return GoogleFonts.quicksandTextTheme(base);
      case AppFontFamily.tech:
        return GoogleFonts.spaceGroteskTextTheme(base);
      case AppFontFamily.luxury:
        return GoogleFonts.plusJakartaSansTextTheme(base);
      case AppFontFamily.futuristic:
        return GoogleFonts.soraTextTheme(base);
    }
  }

  FontWeight _strongerWeight(FontWeight weight, int steps) {
    final nextIndex = (weight.index + steps).clamp(0, FontWeight.values.length - 1).toInt();
    return FontWeight.values[nextIndex];
  }

  TextTheme _textThemeFor(
    DashboardThemeStyle style, {
    required AppFontFamily fontFamily,
    required AppFontScale fontScale,
    required AppFontWeightChoice fontWeight,
  }) {
    final baseMaterial = ThemeData(brightness: style.dark ? Brightness.dark : Brightness.light).textTheme;
    final base = _googleFontTextTheme(fontFamily, baseMaterial);
    final scale = fontScale.scale;
    final selectedWeight = fontWeight.weight;
    final isGamified = style.type == DashboardThemeType.gamified;
    final isMinimal = style.type == DashboardThemeType.minimal;
    final isCalm = style.type == DashboardThemeType.calm;

    TextStyle? themed(TextStyle? source, {FontWeight? weight, double letterSpacing = 0}) {
      if (source == null) return null;
      return source.copyWith(
        color: style.textPrimary,
        fontSize: source.fontSize == null ? null : source.fontSize! * scale,
        fontWeight: weight ?? selectedWeight,
        letterSpacing: letterSpacing,
      );
    }

    return base.apply(
      bodyColor: style.textPrimary,
      displayColor: style.textPrimary,
    ).copyWith(
      displayLarge: themed(base.displayLarge, weight: isGamified ? FontWeight.w900 : _strongerWeight(selectedWeight, 2)),
      displayMedium: themed(base.displayMedium, weight: isGamified ? FontWeight.w900 : _strongerWeight(selectedWeight, 2)),
      headlineSmall: themed(
        base.headlineSmall,
        weight: isGamified ? FontWeight.w900 : _strongerWeight(selectedWeight, 2),
        letterSpacing: isGamified ? 0.8 : isMinimal ? 1.2 : 0,
      ),
      titleLarge: themed(
        base.titleLarge,
        weight: _strongerWeight(selectedWeight, 3),
        letterSpacing: isCalm ? 0.4 : isMinimal ? 1.0 : 0,
      ),
      titleMedium: themed(
        base.titleMedium,
        weight: isGamified ? FontWeight.w900 : _strongerWeight(selectedWeight, 1),
        letterSpacing: isMinimal ? 0.8 : 0,
      ),
      bodyLarge: themed(base.bodyLarge),
      bodyMedium: themed(base.bodyMedium, weight: isGamified ? FontWeight.w600 : selectedWeight),
      bodySmall: themed(base.bodySmall, weight: selectedWeight)?.copyWith(color: style.textMuted),
      labelLarge: themed(
        base.labelLarge,
        weight: _strongerWeight(selectedWeight, 2),
        letterSpacing: isMinimal ? 0.7 : 0,
      ),
      labelMedium: themed(base.labelMedium, weight: selectedWeight),
      labelSmall: themed(base.labelSmall, weight: selectedWeight)?.copyWith(color: style.textMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final dashboardStyle = DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
        final appTextTheme = _textThemeFor(
          dashboardStyle,
          fontFamily: hiveService.getAppFontFamily(),
          fontScale: hiveService.getAppFontScale(),
          fontWeight: hiveService.getAppFontWeight(),
        );
        final dashboardTheme = AppThemeColors.fromDashboardStyle(dashboardStyle);
        return MaterialApp(
          title: 'Bubble Time Progress',
          theme: ThemeData(
            brightness: dashboardStyle.dark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: dashboardStyle.primary,
              primary: dashboardStyle.primary,
              secondary: dashboardStyle.secondary,
              surface: dashboardStyle.surface,
              onPrimary: dashboardTheme.inverseText,
              onSecondary: AppThemeColors.readableTextOn(dashboardStyle.secondary, dashboardStyle),
              onSurface: dashboardStyle.textPrimary,
              brightness: dashboardStyle.dark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: dashboardStyle.background,
            textTheme: appTextTheme,
            primaryTextTheme: appTextTheme.apply(bodyColor: dashboardTheme.inverseText, displayColor: dashboardTheme.inverseText),
            extensions: [dashboardTheme],
            appBarTheme: AppBarTheme(
              backgroundColor: dashboardStyle.primary,
              foregroundColor: dashboardTheme.inverseText,
              elevation: dashboardStyle.dark ? 0 : 2,
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: dashboardStyle.surface,
              selectedItemColor: dashboardStyle.primary,
              unselectedItemColor: dashboardStyle.textMuted,
            ),
            cardTheme: CardThemeData(
              color: dashboardStyle.surface,
              surfaceTintColor: dashboardStyle.elevatedSurface,
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: dashboardStyle.primary,
              linearTrackColor: dashboardStyle.elevatedSurface,
              circularTrackColor: dashboardStyle.elevatedSurface,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: dashboardStyle.primary,
              foregroundColor: dashboardTheme.inverseText,
            ),
            chipTheme: ChipThemeData(
              selectedColor: dashboardStyle.primary.withOpacity(0.18),
              backgroundColor: dashboardStyle.elevatedSurface,
              labelStyle: TextStyle(color: dashboardStyle.textPrimary),
              secondaryLabelStyle: TextStyle(color: dashboardStyle.primary, fontWeight: FontWeight.w800),
              side: BorderSide(color: dashboardStyle.primary.withOpacity(0.18)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: dashboardTheme.filledButton,
                foregroundColor: dashboardTheme.buttonText,
              ),
            ),
          ),
          home: MainScreen(hiveService: hiveService),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final HiveService hiveService;

  const MainScreen({super.key, required this.hiveService});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 2; // Default to Month view (index 2)
  Timer? _mottoTimer;
  bool _mottoDialogOpen = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Listenable? _mottoStorageListenable;
  String? _mottoReminderSignature;
  bool _sidebarExpanded = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mottoStorageListenable = widget.hiveService.getBoxListenable()..addListener(_handleMottoStorageChanged);
    _screens = [
      DashboardView(hiveService: widget.hiveService, onGoToDashboard: _goToDashboardTab),
      YearView(hiveService: widget.hiveService),
      MonthView(hiveService: widget.hiveService),
      WeekView(hiveService: widget.hiveService),
      DayView(hiveService: widget.hiveService),
      StreakView(hiveService: widget.hiveService, onGoToDashboard: _goToDashboardTab),
      TaskScreen(date: DateTime.now(), hiveService: widget.hiveService),
      InstructionDashboardView(hiveService: widget.hiveService),
      GoalDashboardView(hiveService: widget.hiveService),
      RewardMoneyHistoryView(hiveService: widget.hiveService),
      MotivationMottoDashboardView(hiveService: widget.hiveService),
      ProductivityTimelineView(hiveService: widget.hiveService),
      ProductivityTimelineView(hiveService: widget.hiveService),
    ];
    _scheduleMottoReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mottoStorageListenable?.removeListener(_handleMottoStorageChanged);
    _mottoTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) _scheduleMottoReminder();
  }

  void _handleMottoStorageChanged() {
    final signature = _currentMottoReminderSignature();
    if (signature == _mottoReminderSignature) return;
    _scheduleMottoReminder();
  }

  String _currentMottoReminderSignature() {
    final settings = widget.hiveService.getMottoReminderSettings();
    final activeMottoIds = widget.hiveService.getMotivationMottos().where((motto) => motto.enabled).map((motto) => motto.id).join(',');
    return '${settings.popupEnabled}|${settings.frequencyMinutes}|${settings.activeOnly}|$activeMottoIds';
  }

  void _scheduleMottoReminder() {
    _mottoTimer?.cancel();
    _mottoReminderSignature = _currentMottoReminderSignature();
    final settings = widget.hiveService.getMottoReminderSettings();
    if (!settings.popupEnabled || widget.hiveService.getNextMotivationMotto() == null) return;
    final interval = settings.frequencyMinutes <= 0
        ? const Duration(seconds: 30)
        : Duration(minutes: settings.frequencyMinutes);
    _mottoTimer = Timer(interval, _showMottoReminderIfReady);
  }

  Future<void> _showMottoReminderIfReady() async {
    final settings = widget.hiveService.getMottoReminderSettings();
    if (!mounted || !settings.popupEnabled) return;
    if (settings.activeOnly && _lifecycleState != AppLifecycleState.resumed) {
      _scheduleMottoReminder();
      return;
    }
    final motto = widget.hiveService.getNextMotivationMotto();
    if (motto == null || _mottoDialogOpen) {
      _scheduleMottoReminder();
      return;
    }
    _mottoDialogOpen = true;
    await _showMottoDialog(motto);
    _mottoDialogOpen = false;
    _scheduleMottoReminder();
  }

  Future<void> _showMottoDialog(MotivationMotto initialMotto) async {
    MotivationMotto current = initialMotto;
    await widget.hiveService.markMotivationMottoShown(current.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dashboardStyle = DashboardThemeStyle.of(widget.hiveService.getDashboardTheme(), palette: widget.hiveService.getDashboardPalette());
          return AlertDialog(
          title: const Text('💡 Daily Motivation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(toTitleCase(current.quote), style: TextStyle(color: dashboardStyle.textPrimary, fontSize: responsiveFont(context, 18), fontWeight: FontWeight.w700, height: 1.2)),
              if (current.author.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('— ${toTitleCase(current.author.trim())}', style: TextStyle(color: dashboardStyle.textMuted, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 12),
              Text(toTitleCaseMetadata([current.category, current.enabled ? 'Active' : 'Disabled']), style: TextStyle(color: dashboardStyle.textMuted, fontSize: responsiveFont(context, 12), fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            TextButton(
              onPressed: () async {
                final next = widget.hiveService.getNextMotivationMotto(excludeId: current.id);
                if (next == null) return;
                await widget.hiveService.markMotivationMottoShown(next.id);
                setDialogState(() => current = next);
              },
              child: const Text('Next Quote'),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Got It')),
          ],
        );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _sidebarExpanded = false;
    });
  }

  void _goToDashboardTab() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  Widget _buildAnimatedSidebar(DashboardThemeStyle style, RankProfile profile) {
    final items = <_SidebarNavItem>[
      _SidebarNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selectedIndex: 0),
      _SidebarNavItem(icon: Icons.calendar_today_rounded, label: 'Year', selectedIndex: 1),
      _SidebarNavItem(icon: Icons.calendar_view_month_rounded, label: 'Month', selectedIndex: 2),
      _SidebarNavItem(icon: Icons.view_week_rounded, label: 'Week', selectedIndex: 3),
      _SidebarNavItem(icon: Icons.today_rounded, label: 'Day', selectedIndex: 4),
      _SidebarNavItem(icon: Icons.local_fire_department_rounded, label: 'Streak', selectedIndex: 5),
      _SidebarNavItem(icon: Icons.task_alt_rounded, label: 'Tasks', selectedIndex: 6),
      _SidebarNavItem(icon: Icons.rule_folder_rounded, label: 'Instructions', selectedIndex: 7),
      _SidebarNavItem(icon: Icons.flag_circle_rounded, label: 'Goals', selectedIndex: 8),
      _SidebarNavItem(icon: Icons.account_balance_wallet_rounded, label: 'Money', selectedIndex: 9),
      _SidebarNavItem(icon: Icons.lightbulb_rounded, label: 'Motivation', selectedIndex: 10),
      _SidebarNavItem(icon: Icons.insert_chart_outlined_rounded, label: 'Progress', selectedIndex: 11),
      _SidebarNavItem(icon: Icons.analytics_rounded, label: 'Reports', selectedIndex: 12),
    ];
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;
    final collapsedWidth = isMobile ? 64.0 : 72.0;
    final expandedWidth = isMobile ? screenWidth * 0.68 : isTablet ? 220.0 : 260.0;
    final canExpand = !isMobile;
    final expanded = canExpand && _sidebarExpanded;
    final sidebarWidth = (expanded ? expandedWidth.clamp(64.0, 260.0) : collapsedWidth).toDouble();
    return MouseRegion(
      onEnter: (_) {
        if (canExpand) setState(() => _sidebarExpanded = true);
      },
      onExit: (_) {
        if (canExpand) setState(() => _sidebarExpanded = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canExpand ? () => setState(() => _sidebarExpanded = !_sidebarExpanded) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: style.surface,
            border: Border(right: BorderSide(color: style.primary.withOpacity(0.12))),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(expanded ? 14 : 8, 14, expanded ? 14 : 8, 14),
              child: Column(
                crossAxisAlignment: expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  if (expanded) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Momentum', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textPrimary, fontSize: responsiveFont(context, 22), fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(profile.currentRank.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.textMuted, fontSize: responsiveFont(context, 14), fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ] else
                    const SizedBox(height: 4),
                  ...items.map((item) => _buildSidebarNavTile(style, item, expanded, sidebarWidth)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNavTile(DashboardThemeStyle style, _SidebarNavItem item, bool expanded, double sidebarWidth) {
    final selected = item.selectedIndex != null && item.selectedIndex == _selectedIndex;
    final foreground = selected ? style.primary : style.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          if (item.selectedIndex != null) {
            _onItemTapped(item.selectedIndex!);
          } else {
            item.onTap?.call();
          }
        },
        child: Container(
          width: expanded ? (sidebarWidth - 28).clamp(120.0, 232.0).toDouble() : (sidebarWidth - 16).clamp(44.0, 56.0).toDouble(),
          padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? style.primary.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showLabel = expanded && constraints.maxWidth >= 96;
              final icon = Icon(item.icon, color: foreground, size: 21);
              if (!showLabel) {
                return Tooltip(
                  message: item.label,
                  waitDuration: const Duration(milliseconds: 350),
                  child: Semantics(label: item.label, button: true, child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: icon))),
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontWeight: selected ? FontWeight.w900 : FontWeight.w800, fontSize: responsiveFont(context, 15)))),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final dashboardStyle = DashboardThemeStyle.of(widget.hiveService.getDashboardTheme(), palette: widget.hiveService.getDashboardPalette());
        final allByDate = widget.hiveService.getAllTasksByDate();
        final profile = RankProfile.calculate(
          username: widget.hiveService.getUsername(),
          allTasksByDate: allByDate,
          journalEntries: widget.hiveService.getAllJournalEntries(),
          lifetimeStats: widget.hiveService.getLifetimeProductivityStats(),
        );
        final screenWidth = MediaQuery.of(context).size.width;
        final collapsedSidebarWidth = screenWidth < 600 ? 64.0 : 72.0;
        final content = IndexedStack(
          index: _selectedIndex,
          children: _screens.asMap().entries.map((entry) {
            return HeroMode(
              enabled: entry.key == _selectedIndex,
              child: entry.value,
            );
          }).toList(),
        );
        return Scaffold(
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: collapsedSidebarWidth),
                child: content,
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _buildAnimatedSidebar(dashboardStyle, profile),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _SidebarNavItem {
  final IconData icon;
  final String label;
  final int? selectedIndex;
  final VoidCallback? onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    this.selectedIndex,
    this.onTap,
  });
}
