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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final dashboardStyle = DashboardThemeStyle.of(hiveService.getDashboardTheme());
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
      DashboardView(hiveService: widget.hiveService),
      YearView(hiveService: widget.hiveService),
      MonthView(hiveService: widget.hiveService),
      WeekView(hiveService: widget.hiveService),
      DayView(hiveService: widget.hiveService),
      StreakView(hiveService: widget.hiveService),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.hiveService.getBoxListenable(),
      builder: (context, box, _) {
        final dashboardStyle = DashboardThemeStyle.of(widget.hiveService.getDashboardTheme());
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
            label: 'Dashboard',
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
