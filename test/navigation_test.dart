import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:momentum/main.dart';
import 'package:momentum/models/productivity_snapshot.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/screens/home_views.dart';
import 'package:momentum/screens/day_view.dart';
import 'package:momentum/screens/week_view.dart';
import 'package:momentum/screens/month_view.dart';
import 'package:momentum/screens/year_view.dart';
import 'package:momentum/screens/journal_view.dart';
import 'package:momentum/screens/journey_timeline_view.dart';
import 'package:momentum/screens/reward_money_history_view.dart';
import 'package:momentum/screens/streak_view.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/widgets/task_row.dart';
import 'package:momentum/widgets/dashboard_wallpaper_background.dart';

void main() {
  final service = HiveService.instance;
  late Directory directory;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('momentum_navigation_');
    Hive.init(directory.path);
    await service.init();
  });
  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
  });

  Future<void> launch(WidgetTester tester,
      {double width = 390,
      double scale = 1,
      ThemeData? theme,
      Widget? home}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: true, textScaler: TextScaler.linear(scale)),
          child: child!),
      home: home ?? MainScreen(hiveService: service),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> destination(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('detail routes keep navigation and independent back histories',
      (tester) async {
    await launch(tester);
    await destination(tester, 'More');
    await tester.tap(find.byTooltip('Open Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await destination(tester, 'Today');
    expect(find.byType(TodayView), findsOneWidget);
    await destination(tester, 'More');
    expect(find.byType(SettingsView), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsNothing);
    expect(find.text('Find a feature'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TodayView), findsOneWidget);
    await close(tester);
  });

  testWidgets('Today displays the selected wallpaper behind its app bar',
      (tester) async {
    await launch(tester);
    final wallpaper = dashboardWallpaperAssets[service.getDashboardPalette()]!;
    final image = find.byKey(ValueKey<String>(wallpaper));
    expect(image, findsOneWidget);

    final scaffold = tester.widget<Scaffold>(
        find.ancestor(of: image, matching: find.byType(Scaffold)).first);
    expect(scaffold.extendBodyBehindAppBar, isTrue);
    final appBar = tester.widget<AppBar>(
        find.ancestor(of: find.text('Today'), matching: find.byType(AppBar)));
    expect(appBar.backgroundColor, Colors.transparent);
    await close(tester);
  });

  testWidgets(
      'More searches descriptions, clears empty results, and restores search on back',
      (tester) async {
    await launch(tester, width: 320, scale: 2);
    await destination(tester, 'More');
    expect(find.text('Quick access'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Journal'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'appearance');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Tasks'), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('appearance'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no such feature');
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching features'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear feature search'));
    await tester.pumpAndSettle();
    expect(find.text('Plan and act'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
      'Today previews three tasks and keeps reflection above navigation',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.runAsync(() async {
      final yesterday = today.subtract(const Duration(days: 1));
      await service.addTask(
          yesterday, Task(task: 'Overdue item', dueDate: yesterday));
      for (var i = 1; i <= 6; i++) {
        await service.addTask(
            today, Task(task: 'Today item $i', dueDate: today));
      }
      await service.addTask(
          today,
          Task(
              task: 'Completed today',
              dueDate: today,
              done: true,
              status: 'Completed'));
    });
    await launch(tester);

    expect(find.byType(TaskRow), findsNWidgets(3));
    expect(find.text('Show 3 more tasks'), findsOneWidget);
    final progressSummary = find.text('1 of 7 tasks completed');
    expect(progressSummary, findsOneWidget);
    final reflectionButton =
        find.widgetWithText(OutlinedButton, 'Reflect on today');
    expect(reflectionButton, findsOneWidget);
    expect(tester.getTopLeft(find.text('Next up')).dy,
        lessThan(tester.getTopLeft(find.text('Overdue (1)')).dy));
    expect(tester.getTopLeft(find.text('Overdue (1)')).dy,
        lessThan(tester.getTopLeft(progressSummary).dy));
    expect(tester.getTopLeft(progressSummary).dy,
        lessThan(tester.getTopLeft(reflectionButton).dy));
    expect(tester.getRect(reflectionButton).bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy));

    await tester.ensureVisible(find.text('Show 3 more tasks'));
    await tester.tap(find.text('Show 3 more tasks'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskRow), findsNWidgets(6));
    await close(tester);
  });

  testWidgets(
      'Plan remembers scale and dates across destinations and calendar scales',
      (tester) async {
    await launch(tester);
    await destination(tester, 'Plan');
    await tester.tap(find.byTooltip('Choose a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '01/31/2030');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.widget<MonthView>(find.byType(MonthView)).initialDate,
        DateTime(2030, 1, 31));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    expect(find.text('1 Feb 2030'), findsOneWidget);
    await destination(tester, 'Today');
    await destination(tester, 'Plan');
    expect(find.byType(DayView), findsOneWidget);
    expect(find.text('1 Feb 2030'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Week'));
    await tester.pumpAndSettle();
    expect(tester.widget<WeekView>(find.byType(WeekView)).initialDate,
        DateTime(2030, 2, 1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Year'));
    await tester.pumpAndSettle();
    expect(tester.widget<YearView>(find.byType(YearView)).initialDate,
        DateTime(2030, 2, 1));
    await tester.tap(find.widgetWithText(TextButton, 'Today'));
    await tester.pumpAndSettle();
    expect(tester.widget<YearView>(find.byType(YearView)).initialDate,
        DateUtils.dateOnly(DateTime.now()));
    await close(tester);
  });

  testWidgets('Plan agenda opens the selected date and actions stay inline',
      (tester) async {
    final now = DateTime.now();
    final plannedDate = DateTime(now.year, now.month, 10);
    await tester.runAsync(() async {
      await service.addTask(
        plannedDate,
        Task(task: 'Agenda task', dueDate: plannedDate),
      );
    });
    await launch(tester);
    await destination(tester, 'Plan');

    expect(find.text('Agenda'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Week'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Month'));
    await tester.pumpAndSettle();
    final taskRow = find.ancestor(
      of: find.textContaining('Agenda task'),
      matching: find.byType(ListTile),
    );
    expect(taskRow, findsOneWidget);
    await tester.tap(taskRow);
    await tester.pumpAndSettle();
    expect(find.byType(DayView), findsOneWidget);
    expect(find.text('Agenda task'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Year and Journey actions are inline, not floating over content',
      (tester) async {
    await launch(
      tester,
      home: YearView(hiveService: service, initialDate: DateTime.now()),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
    await close(tester);

    await launch(
      tester,
      home: JourneyTimelineView(hiveService: service),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Log journey'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Streak activity can switch to a readable daily list',
      (tester) async {
    await launch(tester, home: StreakView(hiveService: service));
    final listButton = find.widgetWithText(TextButton, 'List');
    await tester.ensureVisible(listButton);
    await tester.tap(listButton);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Heatmap'), findsOneWidget);
    expect(find.textContaining('No activity recorded'), findsWidgets);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('resizing to a rail keeps the current route', (tester) async {
    await launch(tester);
    await destination(tester, 'More');
    await tester.tap(find.byTooltip('Open Settings'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1100, 844);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(SettingsView), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Today')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('More')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    await close(tester);
  });

  testWidgets('calendar navigation fits a small phone with large text',
      (tester) async {
    await launch(tester, width: 320, scale: 2);
    await destination(tester, 'Plan');
    for (final label in ['Day', 'Week', 'Month', 'Year']) {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Choose a date'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: '$label calendar at 2x text');
    }
    await close(tester);
  });

  testWidgets(
      'Day plan shows the complete task list without a floating action overlap',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.runAsync(() async {
      for (var i = 1; i <= 8; i++) {
        await service.addTask(today, Task(task: 'Day item $i', dueDate: today));
      }
      await service.addTask(
        today,
        Task(
          task: 'Scheduled item',
          dueDate: DateTime(today.year, today.month, today.day, 9),
          description:
              '⏰ Schedule Start: 09:00\n⏰ Schedule End: 10:00\n⏰ Schedule Bonus: 20',
        ),
      );
    });
    await launch(
      tester,
      width: 320,
      scale: 2,
      home: DayView(hiveService: service, initialDate: today),
    );

    expect(find.text('Add task'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(TaskRow), findsNWidgets(10));
    for (var i = 1; i <= 8; i++) {
      expect(find.text('Day item $i'), findsOneWidget);
    }
    await tester.ensureVisible(find.text('Schedule'));
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    final editTimeButton = find.byTooltip('Edit time').first;
    await tester.ensureVisible(editTimeButton);
    expect(find.byTooltip('Edit time'), findsAtLeastNWidgets(1));
    await tester.tap(editTimeButton);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('reward history leads with balance and recent activity',
      (tester) async {
    await launch(
      tester,
      home: RewardMoneyHistoryView(hiveService: service),
    );

    final balance = tester.getTopLeft(find.text('Available balance')).dy;
    final recent = tester.getTopLeft(find.text('Recent activity')).dy;
    final totalPoints = tester.getTopLeft(find.text('Total Points')).dy;
    expect(balance, lessThan(recent));
    expect(recent, lessThan(totalPoints));
    expect(
      tester.getTopLeft(find.text('Record spending')).dy,
      lessThan(recent),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Earned (personal tracking)'), findsOneWidget);
    expect(find.textContaining('Personal tracking only.'), findsOneWidget);
    await close(tester);
  });

  testWidgets('record spending saves and updates the visible history',
      (tester) async {
    final date = DateUtils.dateOnly(DateTime.now());
    final snapshot = ProductivitySnapshot(
      date: date,
      bothHours: 0,
      importantHours: 0,
      urgentHours: 0,
      neitherHours: 0,
      totalHours: 0,
      totalPoints: 100000,
      basePoints: 100000,
      streakBonusPoints: 0,
      productivityScore: 100,
      rating: 'Excellent',
      completedTasks: 1,
      routineCompletions: 0,
      projectPhasesCompleted: 0,
      completedTaskNames: const ['Seeded work'],
      pointEvents: const [],
    );
    await tester.runAsync(() async {
      await Hive.box<List>('tasksBox').put(
        '__productivity_snapshot__${date.toIso8601String().split('T').first}',
        snapshot.toStorageList(),
      );
    });
    final startingBalance = service.getRewardMoneySummary().availableRupees;
    await launch(
      tester,
      home: RewardMoneyHistoryView(hiveService: service),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Record spending'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.enterText(find.byType(TextFormField).at(1), 'Coffee');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save spending'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Spending recorded'), findsOneWidget);
    expect(
        service.getRewardMoneySummary().availableRupees, startingBalance - 10);
    expect(service.getRewardMoneySummary().withdrawnRupees, 10);
    expect(
      service.getRewardMoneySummary().ledger.map((entry) => entry.reason),
      contains('Coffee'),
    );
    await tester.scrollUntilVisible(
      find.textContaining('Reason: Coffee'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Reason: Coffee'), findsOneWidget);
    await close(tester);
  });

  testWidgets('reward status values use dark-theme semantic colors',
      (tester) async {
    final colors = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    await launch(
      tester,
      theme: ThemeData(useMaterial3: true, colorScheme: colors),
      home: RewardMoneyHistoryView(hiveService: service),
    );

    final valueColors = tester
        .widgetList<Text>(find.text('₹0'))
        .map((text) => text.style?.color)
        .toList();
    expect(
      valueColors,
      containsAll([colors.primary, colors.error, colors.tertiary]),
    );
    await close(tester);
  });

  testWidgets('Year agenda lists tasks by date and opens the Day plan',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.runAsync(() async {
      await service.addTask(today, Task(task: 'Agenda task', dueDate: today));
    });
    await launch(
      tester,
      width: 320,
      scale: 2,
      home: YearView(hiveService: service, initialDate: today),
    );

    await tester.ensureVisible(find.text('Browse dates and tasks'));
    await tester.tap(find.text('Browse dates and tasks'));
    await tester.pumpAndSettle();
    const monthLabels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = monthLabels[today.month - 1];
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text(month));
    await tester.pumpAndSettle();
    final dateLabel = '${today.day} $month';
    expect(find.text('Agenda Task'), findsOneWidget);
    final dateTile = find
        .ancestor(
          of: find.text(dateLabel),
          matching: find.byType(ListTile),
        )
        .first;
    final tile = tester.widget<ListTile>(dateTile);
    expect(tile.onTap, isNotNull);
    tile.onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(DayView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('Progress trend chart exposes a spoken summary', (tester) async {
    await launch(tester);
    await destination(tester, 'Progress');

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.toLowerCase().contains('productivity') ??
                false),
      ),
      findsOneWidget,
    );
    await close(tester);
  });

  testWidgets('a task dialog uses the root route and back protects edits',
      (tester) async {
    await launch(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Keep my task');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard task changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Keep my task'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TodayView), findsOneWidget);
    await close(tester);
  });

  testWidgets(
      'configured start destination is honored without building every tab',
      (tester) async {
    await tester.runAsync(() => service.setStartScreen(1));
    await launch(tester);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    expect(find.byType(TodayView, skipOffstage: false), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TodayView), findsOneWidget);
    await close(tester);
  });

  testWidgets('switching tabs keeps a journal draft and system back flushes it',
      (tester) async {
    await launch(tester);
    await tester
        .tap(find.byTooltip('Journal: write a reflection for this date'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.enterText(
          find.byType(TextField).first, 'Keep this reflection while I plan');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await destination(tester, 'More');
    await destination(tester, 'Today');
    expect(find.byType(JournalView), findsOneWidget);
    expect(find.text('Keep this reflection while I plan'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.binding.handlePopRoute();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(JournalView), findsNothing);
    expect(service.getJournalDraft(DateTime.now())?['text'],
        'Keep this reflection while I plan');
    await close(tester);
  });
}
