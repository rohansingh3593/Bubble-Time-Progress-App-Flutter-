import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/task_model.dart';
import 'models/motivation_motto.dart';
import 'services/hive_service.dart';
import 'screens/productivity_timeline_view.dart';
import 'constants/dashboard_themes.dart';
import 'utils/text_formatters.dart';
import 'widgets/app_text.dart';
import 'screens/home_views.dart';

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
  final String? fontFamilyOverride;

  const MyApp({super.key, required this.hiveService, this.fontFamilyOverride});

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
    final nextIndex =
        (weight.index + steps).clamp(0, FontWeight.values.length - 1).toInt();
    return FontWeight.values[nextIndex];
  }

  TextTheme _textThemeFor(
    DashboardThemeStyle style, {
    required AppFontFamily fontFamily,
    required AppFontScale fontScale,
    required AppFontWeightChoice fontWeight,
  }) {
    final baseMaterial =
        ThemeData(brightness: style.dark ? Brightness.dark : Brightness.light)
            .textTheme;
    final base = fontFamilyOverride == null
        ? _googleFontTextTheme(fontFamily, baseMaterial)
        : baseMaterial.apply(fontFamily: fontFamilyOverride);
    const scale = 1.0;
    final selectedWeight = fontWeight.weight;
    final isGamified = style.type == DashboardThemeType.gamified;
    final isMinimal = style.type == DashboardThemeType.minimal;
    final isCalm = style.type == DashboardThemeType.calm;

    TextStyle? themed(TextStyle? source,
        {FontWeight? weight, double letterSpacing = 0}) {
      if (source == null) return null;
      return source.copyWith(
        color: style.textPrimary,
        fontSize: source.fontSize == null ? null : source.fontSize! * scale,
        fontWeight: weight ?? selectedWeight,
        letterSpacing: letterSpacing,
      );
    }

    return base
        .apply(
          bodyColor: style.textPrimary,
          displayColor: style.textPrimary,
        )
        .copyWith(
          displayLarge: themed(base.displayLarge,
              weight: isGamified
                  ? FontWeight.w900
                  : _strongerWeight(selectedWeight, 2)),
          displayMedium: themed(base.displayMedium,
              weight: isGamified
                  ? FontWeight.w900
                  : _strongerWeight(selectedWeight, 2)),
          headlineSmall: themed(
            base.headlineSmall,
            weight: isGamified
                ? FontWeight.w900
                : _strongerWeight(selectedWeight, 2),
            letterSpacing: isGamified
                ? 0.8
                : isMinimal
                    ? 1.2
                    : 0,
          ),
          titleLarge: themed(
            base.titleLarge,
            weight: _strongerWeight(selectedWeight, 3),
            letterSpacing: isCalm
                ? 0.4
                : isMinimal
                    ? 1.0
                    : 0,
          ),
          titleMedium: themed(
            base.titleMedium,
            weight: isGamified
                ? FontWeight.w900
                : _strongerWeight(selectedWeight, 1),
            letterSpacing: isMinimal ? 0.8 : 0,
          ),
          bodyLarge: themed(base.bodyLarge),
          bodyMedium: themed(base.bodyMedium,
              weight: isGamified ? FontWeight.w600 : selectedWeight),
          bodySmall: themed(base.bodySmall, weight: selectedWeight)
              ?.copyWith(color: style.textMuted),
          labelLarge: themed(
            base.labelLarge,
            weight: _strongerWeight(selectedWeight, 2),
            letterSpacing: isMinimal ? 0.7 : 0,
          ),
          labelMedium: themed(base.labelMedium, weight: selectedWeight),
          labelSmall: themed(base.labelSmall, weight: selectedWeight)
              ?.copyWith(color: style.textMuted),
        );
  }

  @override
  Widget build(BuildContext context) {
    MediaQuery.platformBrightnessOf(context);
    return ValueListenableBuilder(
      valueListenable: hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final dashboardStyle = DashboardThemeStyle.of(
            hiveService.getDashboardTheme(),
            palette: hiveService.getDashboardPalette());
        final appTextTheme = _textThemeFor(
          dashboardStyle,
          fontFamily: hiveService.getAppFontFamily(),
          fontScale: hiveService.getAppFontScale(),
          fontWeight: hiveService.getAppFontWeight(),
        );
        final dashboardTheme =
            AppThemeColors.fromDashboardStyle(dashboardStyle);
        return MaterialApp(
          title: 'Momentum',
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: _AppTextScaler(MediaQuery.textScalerOf(context),
                      hiveService.getAppFontScale().scale)),
              child: child!),
          theme: ThemeData(
            useMaterial3: true,
            visualDensity: VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16)),
            filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48))),
            outlinedButtonTheme: OutlinedButtonThemeData(
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48))),
            brightness:
                dashboardStyle.dark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: dashboardStyle.primary,
              primary: dashboardStyle.primary,
              secondary: dashboardStyle.secondary,
              surface: dashboardStyle.surface,
              onPrimary: dashboardTheme.inverseText,
              onSecondary: AppThemeColors.readableTextOn(
                  dashboardStyle.secondary, dashboardStyle),
              onSurface: dashboardStyle.textPrimary,
              brightness:
                  dashboardStyle.dark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: dashboardStyle.background,
            textTheme: appTextTheme,
            primaryTextTheme: appTextTheme.apply(
                bodyColor: dashboardTheme.inverseText,
                displayColor: dashboardTheme.inverseText),
            extensions: [dashboardTheme],
            appBarTheme: AppBarTheme(
              backgroundColor: dashboardStyle.primary,
              foregroundColor: dashboardStyle.primary.computeLuminance() > 0.179
                  ? Colors.black
                  : Colors.white,
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
              labelStyle: appTextTheme.labelLarge
                  ?.copyWith(color: dashboardStyle.textPrimary),
              secondaryLabelStyle: appTextTheme.labelLarge
                  ?.copyWith(color: dashboardStyle.textPrimary),
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
  int _selectedIndex = 0;
  final _navigators = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _visited = <int>{};
  final _canGoBack = List.filled(4, false);
  Timer? _mottoTimer;
  bool _mottoDialogOpen = false;
  DateTime? _mottoSnoozedUntil;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Listenable? _mottoStorageListenable;
  String? _mottoReminderSignature;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mottoStorageListenable = widget.hiveService.getBoxListenable()
      ..addListener(_handleMottoStorageChanged);
    _selectedIndex = widget.hiveService.getStartScreen();
    _visited.add(_selectedIndex);
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
    final activeMottoIds = widget.hiveService
        .getMotivationMottos()
        .where((motto) => motto.enabled)
        .map((motto) => motto.id)
        .join(',');
    return '${settings.popupEnabled}|${settings.frequencyMinutes}|${settings.activeOnly}|$activeMottoIds';
  }

  void _scheduleMottoReminder() {
    _mottoTimer?.cancel();
    _mottoReminderSignature = _currentMottoReminderSignature();
    final settings = widget.hiveService.getMottoReminderSettings();
    if (!settings.popupEnabled ||
        widget.hiveService.getNextMotivationMotto() == null) return;
    var interval = Duration(minutes: settings.frequencyMinutes.clamp(15, 120));
    final snooze = _mottoSnoozedUntil?.difference(DateTime.now());
    if (snooze != null && snooze > interval) interval = snooze;
    _mottoTimer = Timer(interval, _showMottoReminderIfReady);
  }

  Future<void> _showMottoReminderIfReady() async {
    final settings = widget.hiveService.getMottoReminderSettings();
    if (!mounted || !settings.popupEnabled) return;
    if (_lifecycleState != AppLifecycleState.resumed ||
        _canGoBack[_selectedIndex] ||
        ModalRoute.of(context)?.isCurrent != true ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null) {
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
          final dashboardStyle = DashboardThemeStyle.of(
              widget.hiveService.getDashboardTheme(),
              palette: widget.hiveService.getDashboardPalette());
          return AlertDialog(
            title: const Text('💡 Daily Motivation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(current.quote,
                    style: TextStyle(
                        color: dashboardStyle.textPrimary,
                        fontSize: responsiveFont(context, 18),
                        fontWeight: FontWeight.w700,
                        height: 1.2)),
                if (current.author.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('— ${toTitleCase(current.author.trim())}',
                      style: TextStyle(
                          color: dashboardStyle.textMuted,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 12),
                Text(
                    toTitleCaseMetadata([
                      current.category,
                      current.enabled ? 'Active' : 'Disabled'
                    ]),
                    style: TextStyle(
                        color: dashboardStyle.textMuted,
                        fontSize: responsiveFont(context, 12),
                        fontWeight: FontWeight.w500)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              TextButton(
                onPressed: () async {
                  final next = widget.hiveService
                      .getNextMotivationMotto(excludeId: current.id);
                  if (next == null) return;
                  await widget.hiveService.markMotivationMottoShown(next.id);
                  setDialogState(() => current = next);
                },
                child: const Text('Next Quote'),
              ),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got It')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _selectedIndex,
      children: List.generate(
          4,
          (index) => !_visited.contains(index)
              ? const SizedBox.shrink()
              : TickerMode(
                  enabled: index == _selectedIndex,
                  child: NotificationListener<NavigationNotification>(
                    onNotification: (notification) {
                      if (mounted &&
                          _canGoBack[index] != notification.canHandlePop) {
                        setState(() =>
                            _canGoBack[index] = notification.canHandlePop);
                      }
                      return true;
                    },
                    child: Navigator(
                      key: _navigators[index],
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => switch (index) {
                          0 => TodayView(service: widget.hiveService),
                          1 => PlanView(service: widget.hiveService),
                          2 => ProductivityTimelineView(
                              hiveService: widget.hiveService),
                          _ => MoreView(service: widget.hiveService),
                        },
                      ),
                    ),
                  ),
                )),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840;
      return PopScope(
          canPop: _selectedIndex == 0 && !_canGoBack[0],
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final navigator = _navigators[_selectedIndex].currentState;
            if (_canGoBack[_selectedIndex]) {
              // maybePop respects an editor's own draft/save guard.
              await navigator?.maybePop();
            } else {
              _selectDestination(0);
            }
          },
          child: Scaffold(
            body: Row(children: [
              wide
                  ? NavigationRail(
                      selectedIndex: _selectedIndex,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: _selectDestination,
                      destinations: const [
                          NavigationRailDestination(
                              icon: Icon(Icons.today_outlined),
                              label: Text('Today')),
                          NavigationRailDestination(
                              icon: Icon(Icons.calendar_month_outlined),
                              label: Text('Plan')),
                          NavigationRailDestination(
                              icon: Icon(Icons.insights_outlined),
                              label: Text('Progress')),
                          NavigationRailDestination(
                              icon: Icon(Icons.grid_view), label: Text('More')),
                        ])
                  : const SizedBox.shrink(),
              Expanded(child: content),
            ]),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectDestination,
                    destinations: const [
                        NavigationDestination(
                            icon: Icon(Icons.today_outlined), label: 'Today'),
                        NavigationDestination(
                            icon: Icon(Icons.calendar_month_outlined),
                            label: 'Plan'),
                        NavigationDestination(
                            icon: Icon(Icons.insights_outlined),
                            label: 'Progress'),
                        NavigationDestination(
                            icon: Icon(Icons.grid_view), label: 'More'),
                      ]),
          ));
    });
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });
  }
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.platform, this.factor);
  final TextScaler platform;
  final double factor;
  @override
  double scale(double fontSize) => platform.scale(fontSize) * factor;
  @override
  double get textScaleFactor => platform.textScaleFactor * factor;
}
