import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/task_model.dart';
import 'services/hive_service.dart';
import 'screens/dashboard_view.dart';
import 'screens/year_view.dart';
import 'screens/month_view.dart';
import 'screens/week_view.dart';
import 'screens/day_view.dart';
import 'screens/streak_view.dart';
import 'constants/colors.dart';
import 'constants/dashboard_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TaskAdapter());
  }

  await HiveService.instance.init();

  runApp(MyApp(hiveService: HiveService.instance));
}

class MyApp extends StatelessWidget {
  final HiveService hiveService;

  const MyApp({super.key, required this.hiveService});

  TextTheme _textThemeFor(DashboardThemeStyle style) {
    final base = ThemeData(brightness: style.dark ? Brightness.dark : Brightness.light).textTheme;
    final isGamified = style.type == DashboardThemeType.gamified;
    final isMinimal = style.type == DashboardThemeType.minimal;
    final isCalm = style.type == DashboardThemeType.calm;
    return base.apply(
      bodyColor: style.textPrimary,
      displayColor: style.textPrimary,
      fontFamily: isMinimal ? 'monospace' : null,
    ).copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        color: style.textPrimary,
        fontWeight: isGamified ? FontWeight.w900 : FontWeight.w800,
        letterSpacing: isGamified ? 0.8 : isMinimal ? 1.2 : 0,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: style.textPrimary,
        fontWeight: FontWeight.w900,
        letterSpacing: isCalm ? 0.4 : isMinimal ? 1.0 : 0,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: style.textPrimary,
        fontWeight: isGamified ? FontWeight.w900 : FontWeight.w700,
        letterSpacing: isMinimal ? 0.8 : 0,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: style.textPrimary,
        fontWeight: isGamified ? FontWeight.w600 : FontWeight.normal,
      ),
      bodySmall: base.bodySmall?.copyWith(color: style.textMuted),
      labelLarge: base.labelLarge?.copyWith(
        color: style.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: isMinimal ? 0.7 : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final dashboardStyle = DashboardThemeStyle.of(hiveService.getDashboardTheme(), palette: hiveService.getDashboardPalette());
        return MaterialApp(
          title: 'Bubble Time Progress',
          theme: ThemeData(
            brightness: dashboardStyle.dark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: dashboardStyle.primary,
              primary: dashboardStyle.primary,
              secondary: dashboardStyle.secondary,
              surface: dashboardStyle.surface,
              onPrimary: Colors.white,
              onSecondary: dashboardStyle.dark ? Colors.white : AppColors.textPrimary,
              onSurface: dashboardStyle.textPrimary,
              brightness: dashboardStyle.dark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: dashboardStyle.background,
            textTheme: _textThemeFor(dashboardStyle),
            primaryTextTheme: _textThemeFor(dashboardStyle).apply(bodyColor: Colors.white, displayColor: Colors.white),
            appBarTheme: AppBarTheme(
              backgroundColor: dashboardStyle.primary,
              foregroundColor: Colors.white,
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
              foregroundColor: Colors.white,
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
                backgroundColor: dashboardStyle.accent,
                foregroundColor: Colors.white,
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2; // Default to Month view (index 2)

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardView(hiveService: widget.hiveService, onGoToDashboard: _goToDashboardTab),
      YearView(hiveService: widget.hiveService),
      MonthView(hiveService: widget.hiveService),
      WeekView(hiveService: widget.hiveService),
      DayView(hiveService: widget.hiveService),
      StreakView(hiveService: widget.hiveService, onGoToDashboard: _goToDashboardTab),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _goToDashboardTab() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final dashboardStyle = DashboardThemeStyle.of(widget.hiveService.getDashboardTheme(), palette: widget.hiveService.getDashboardPalette());
        return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens.asMap().entries.map((entry) {
          return HeroMode(
            enabled: entry.key == _selectedIndex,
            child: entry.value,
          );
        }).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: dashboardStyle.surface,
        selectedItemColor: dashboardStyle.primary,
        unselectedItemColor: dashboardStyle.textMuted,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
            tooltip: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Year',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_month),
            label: 'Month',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_week),
            label: 'Week',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Day',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department),
            label: 'Streak',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
      },
    );
  }
}
