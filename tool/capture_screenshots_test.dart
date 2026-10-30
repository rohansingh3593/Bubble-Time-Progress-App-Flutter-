// Explicit capture tool; production UI/data are not modified.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:momentum/main.dart';
import 'package:momentum/constants/dashboard_themes.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/models/task_step.dart';
import 'package:momentum/models/instruction.dart';
import 'package:momentum/models/journal_entry.dart';
import 'package:momentum/models/journey_entry.dart';
import 'package:momentum/models/motivation_motto.dart';
import 'package:momentum/models/reward_money.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/services/offline_voice_service.dart';
import 'package:momentum/screens/dashboard_view.dart';
import 'package:momentum/screens/year_view.dart';
import 'package:momentum/screens/month_view.dart';
import 'package:momentum/screens/week_view.dart';
import 'package:momentum/screens/day_view.dart';
import 'package:momentum/screens/task_screen.dart';
import 'package:momentum/screens/streak_view.dart';
import 'package:momentum/screens/instruction_dashboard_view.dart';
import 'package:momentum/screens/goal_dashboard_view.dart';
import 'package:momentum/screens/reward_money_history_view.dart';
import 'package:momentum/screens/motivation_motto_dashboard_view.dart';
import 'package:momentum/screens/productivity_timeline_view.dart';
import 'package:momentum/screens/log_earn_view.dart';
import 'package:momentum/screens/journal_view.dart';
import 'package:momentum/screens/journey_timeline_view.dart';
import 'package:momentum/screens/voice_tasks_screen.dart';
import 'package:momentum/widgets/quick_add_task_dialog.dart';
import 'package:momentum/widgets/routine_occurrence_dialog.dart';

const outputPath = String.fromEnvironment('CAPTURE_OUTPUT');
const fontPath = String.fromEnvironment('CAPTURE_FONTS');
const captureTheme =
    String.fromEnvironment('CAPTURE_THEME', defaultValue: 'light');
const onlyScreen = String.fromEnvironment('CAPTURE_SCREEN');

// The reference screen never opens the real microphone/native recorder.
class ReferenceCapture implements VoiceCapture {
  @override
  final ValueNotifier<double> level = ValueNotifier(0);
  @override
  Future<void> start() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<String> stopAndTranscribe({String language = ''}) async =>
      'Add prepare presentation tomorrow for thirty minutes';
  @override
  Future<void> dispose() async {
    level.dispose();
  }
}

Future<void> seed(HiveService hive) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  await hive.setUsername('Sample User');
  await hive.setAppFontFamily(AppFontFamily.modern);
  await hive.setDashboardTheme(captureTheme == 'dark'
      ? DashboardThemeType.dark
      : DashboardThemeType.light);
  await hive.saveMottoReminderSettings(
      const MottoReminderSettings(popupEnabled: false));
  for (var ago = 6; ago >= 0; ago--) {
    final day = today.subtract(Duration(days: ago));
    await hive.addTask(
        day,
        Task(
            id: 'sample-read-$ago',
            task: 'Read for twenty minutes',
            dueDate: day,
            category: 'Personal',
            estimatedMinutes: 20,
            important: true,
            done: ago > 0,
            status: ago > 0 ? 'Completed' : 'Not Started',
            steps: [
              TaskStep(
                  id: 'read-step-$ago',
                  name: 'Read one chapter',
                  minutes: 20,
                  status: ago > 0 ? 'Completed' : 'Not Started')
            ]));
  }
  await hive.addTask(
      today,
      Task(
          id: 'sample-project',
          task: 'Prepare project presentation',
          dueDate: today,
          category: 'Work',
          priority: 'High',
          status: 'In Progress',
          estimatedMinutes: 60,
          important: true,
          urgent: true,
          description: 'Prepare a short update for the team.\n'
              '⏰ Schedule Start: 10:00\n⏰ Schedule End: 11:00\n⏰ Schedule Bonus: 20 points',
          steps: [
            TaskStep(
                id: 'outline',
                name: 'Outline the main ideas',
                minutes: 20,
                status: 'Completed',
                actualMinutes: 20,
                completedAt: now),
            TaskStep(id: 'slides', name: 'Create the slides', minutes: 40)
          ]));
  await hive.addTask(
      today,
      Task(
          id: 'sample-walk',
          task: 'Morning walk',
          dueDate: today,
          category: 'Health',
          repeatTask: true,
          repeatFrequency: 'Daily',
          estimatedMinutes: 30,
          important: true,
          colorValue: 0xFF43A047,
          description:
              '⏰ Schedule Start: 07:00\n⏰ Schedule End: 07:30\n⏰ Schedule Bonus: 20 points'));
  for (final frequency in ['Weekly', 'Monthly', 'Yearly']) {
    await hive.addTask(
        today,
        Task(
            id: 'sample-$frequency',
            task: '$frequency planning review',
            dueDate: today,
            category: 'Personal',
            repeatTask: true,
            repeatFrequency: frequency,
            estimatedMinutes: 30));
  }
  await hive.saveInstruction(InstructionRule(
      id: 'sample-instruction',
      name: 'Daily wellbeing checklist',
      createdAt: now,
      description: 'Small actions that support a steady day.',
      options: const [
        InstructionOption(
            id: 'water',
            name: 'Drink water',
            bonusPoints: 10,
            pointsEarned: 5,
            emoji: '💧'),
        InstructionOption(
            id: 'stretch',
            name: 'Stretch',
            bonusPoints: 10,
            pointsEarned: 5,
            emoji: '🌿')
      ]));
  await hive.saveRewardGoal(RewardGoal(
      id: 'sample-goal',
      name: 'Weekend nature trip',
      targetAmountRupees: 5000,
      savedAmountRupees: 1250,
      createdAt: now,
      category: 'Travel',
      description: 'A personal reward for consistent progress.',
      deadline: today.add(const Duration(days: 60))));
  await hive.saveMotivationMotto(MotivationMotto(
      id: 'sample-motto',
      quote: 'Small steps count. Keep showing up.',
      title: 'One step at a time',
      category: 'Focus',
      createdAt: now,
      pinned: true));
  await hive.saveJournalEntry(JournalEntry(
      date: today,
      mood: 'Good',
      reflection: 'I made time for a walk and started the presentation. '
          'Tomorrow I want to begin with the most important task.',
      completedTasks: 1,
      totalTasks: 5,
      productivityScore: 20));
  await hive.saveJourneyEntry(JourneyEntry(
      id: 'sample-journey',
      date: today,
      type: 'Milestone',
      title: 'A consistent week',
      description: 'Made space for reading every day.',
      colorValue: 0xFF1E88E5));
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture phone reference screens', (tester) async {
    if (outputPath.isEmpty || fontPath.isEmpty) {
      fail(
          'Use capture_screenshots.ps1 to supply output and cached font paths.');
    }
    final output = Directory('$outputPath/$captureTheme')
      ..createSync(recursive: true);
    final temp = Directory.systemTemp.createTempSync('momentum_capture_');
    final hive = HiveService.instance;
    final boundaryKey = GlobalKey();
    final captures = <Map<String, Object?>>[];
    final issues = <Map<String, String>>[];
    var activeScreen = 'startup';
    final previousErrorHandler = FlutterError.onError;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1;
    GoogleFonts.config.allowRuntimeFetching = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => fontPath);
    // Real glyphs for text that does not inherit Google Fonts. Font binaries
    // remain in the existing system/cache directories, never in the repository.
    await tester.runAsync(() async {
      print('Capture setup: loading fonts');
      final regular = Directory(fontPath)
          .listSync()
          .whereType<File>()
          .firstWhere(
              (f) => f.uri.pathSegments.last.startsWith('Inter_regular_'));
      for (final family in ['Ahem', 'Roboto']) {
        final loader = FontLoader(family)
          ..addFont(
              Future.value(ByteData.sublistView(regular.readAsBytesSync())));
        for (final fallback in [
          'C:/Windows/Fonts/seguiemj.ttf',
          'C:/Windows/Fonts/Nirmala.ttc'
        ]) {
          if (File(fallback).existsSync()) {
            loader.addFont(Future.value(
                ByteData.sublistView(File(fallback).readAsBytesSync())));
          }
        }
        await loader.load();
      }
      for (final weight in [
        FontWeight.w300,
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
        FontWeight.w900
      ]) {
        GoogleFonts.inter(fontWeight: weight);
      }
      await GoogleFonts.pendingFonts();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      for (final font in {
        'CaptureEmoji': 'C:/Windows/Fonts/seguiemj.ttf',
        'CaptureHindi': 'C:/Windows/Fonts/Nirmala.ttc'
      }.entries) {
        if (File(font.value).existsSync()) {
          await (FontLoader(font.key)
                ..addFont(Future.value(
                    ByteData.sublistView(File(font.value).readAsBytesSync()))))
              .load();
        }
      }
      print('Capture setup: opening isolated storage');
      Hive.init(temp.path);
      await hive.init();
      print('Capture setup: adding sample data');
      await seed(hive);
      print('Capture setup: ready');
    });
    FlutterError.onError = (details) {
      // Preserve defects in the image and report; this is not a passing-layout assertion.
      issues
          .add({'screen': activeScreen, 'error': details.exceptionAsString()});
    };
    Future<void> pump() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> screenshot(String name, int page, {String note = ''}) async {
      await pump();
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final filename = '$name-${page.toString().padLeft(2, '0')}.png';
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('PNG encoding failed');
          await File('${output.path}/$filename').writeAsBytes(bytes.buffer
              .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        } finally {
          image.dispose();
        }
      });
      captures.add({
        'file': '$captureTheme/$filename',
        'screen': name,
        'page': page,
        'theme': captureTheme,
        'note': note
      });
    }

    Future<void> capturePages(String name, {bool scroll = true}) async {
      activeScreen = name;
      await screenshot(name, 1);
      if (!scroll) return;
      final dialogs = find.byType(AlertDialog);
      final scrollFinder = dialogs.evaluate().isEmpty
          ? find.byType(Scrollable)
          : find.descendant(
              of: dialogs.last, matching: find.byType(Scrollable));
      final states = tester
          .stateList<ScrollableState>(scrollFinder)
          .where((s) =>
              s.widget.axisDirection == AxisDirection.down &&
              s.position.hasContentDimensions &&
              s.position.maxScrollExtent > 1)
          .toList()
        ..sort((a, b) => b.position.viewportDimension
            .compareTo(a.position.viewportDimension));
      if (states.isEmpty) return;
      final position = states.first.position;
      for (var page = 2; page <= 18; page++) {
        final next = (position.pixels + position.viewportDimension * .85)
            .clamp(0.0, position.maxScrollExtent)
            .toDouble();
        if (next <= position.pixels + 1) break;
        position.jumpTo(next);
        await screenshot(name, page,
            note: 'Continuation of main vertical scroll');
        if (position.pixels >= position.maxScrollExtent - 1) break;
        if (page == 18)
          issues.add(
              {'screen': name, 'error': 'Scroll capture capped at 18 pages.'});
      }
      position.jumpTo(0);
      await pump();
    }

    try {
      print('Capture: mounting app');
      await tester.pumpWidget(
          RepaintBoundary(key: boundaryKey, child: MyApp(hiveService: hive)));
      // Reuse the production theme/home, with explicit glyph fallbacks for the
      // headless renderer and without the development-only DEBUG banner.
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: app.theme!.copyWith(
                textTheme: app.theme!.textTheme.apply(
                    fontFamilyFallback: const [
                  'CaptureEmoji',
                  'CaptureHindi'
                ])),
            home: app.home,
            debugShowCheckedModeBanner: false,
          )));
      print('Capture: rendering');
      await pump();
      if (onlyScreen.isEmpty || onlyScreen == '00-app-shell') {
        await capturePages('00-app-shell', scroll: false);
        await tester.tapAt(const Offset(5, 420));
        await pump();
        await capturePages('00-navigation', scroll: false);
        await tester.tapAt(const Offset(370, 420));
        await pump();
      }
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      final screens = <String, Widget>{
        '01-dashboard': DashboardView(hiveService: hive),
        '02-year': YearView(hiveService: hive),
        '03-month': MonthView(hiveService: hive),
        '04-week': WeekView(hiveService: hive),
        '05-day': DayView(hiveService: hive),
        '06-tasks': TaskScreen(date: DateTime.now(), hiveService: hive),
        '07-streak': StreakView(hiveService: hive),
        '08-instructions': InstructionDashboardView(hiveService: hive),
        '09-goals': GoalDashboardView(hiveService: hive),
        '10-money': RewardMoneyHistoryView(hiveService: hive),
        '11-motivation': MotivationMottoDashboardView(hiveService: hive),
        '12-progress-reports': ProductivityTimelineView(hiveService: hive),
        '13-log-earn': LogEarnView(hiveService: hive),
        '14-journal': JournalView(hiveService: hive),
        '15-journey': JourneyTimelineView(hiveService: hive),
        '16-voice':
            VoiceTasksScreen(hiveService: hive, capture: ReferenceCapture()),
      };
      for (final entry in screens.entries) {
        if (onlyScreen.isNotEmpty && onlyScreen != entry.key) continue;
        activeScreen = entry.key;
        navigator.push(MaterialPageRoute<void>(builder: (_) => entry.value));
        await pump();
        try {
          await capturePages(entry.key);
          if (entry.key == '01-dashboard') {
            final controller = DefaultTabController.of(
                tester.element(find.byType(TabBar).first));
            final names = [
              'overview',
              'productivity',
              'tasks',
              'goals',
              'instructions',
              'growth'
            ];
            for (var index = 1; index < names.length; index++) {
              controller.animateTo(index);
              await pump();
              await capturePages('01-dashboard-${names[index]}');
            }
          }
          final labels = <String, String>{
            '08-instructions': 'Add Instruction',
            '09-goals': 'Add Goal',
            '10-money': 'Withdraw / Use Money',
            '11-motivation': 'Add Motivation Motto',
            '15-journey': 'Log journey'
          };
          final label = labels[entry.key];
          if (label != null) {
            final button = find.text(label).last;
            await tester.ensureVisible(button);
            await tester.tap(button);
            await pump();
            await capturePages('${entry.key}-form');
            navigator.pop();
            await pump();
          }
          if (entry.key == '06-tasks') {
            final context = tester.element(find.byType(TaskScreen).first);
            showTaskFormDialog(context, date: DateTime.now());
            await pump();
            await capturePages('06-task-create-form');
            navigator.pop();
            await pump();
            final routine = hive
                .getAllTasksByDate()
                .values
                .expand((t) => t)
                .firstWhere((t) => t.id == 'sample-walk');
            showTaskFormDialog(context,
                date: routine.dueDate,
                initialTask: routine,
                title: 'Edit Routine Details',
                actionLabel: 'Save Routine');
            await pump();
            await capturePages('06-routine-edit-form');
            navigator.pop();
            await pump();
            showRoutineOccurrenceDialog(
                context: context, task: routine, hiveService: hive);
            await pump();
            await capturePages('06-routine-occurrence');
            navigator.pop();
            await pump();
          }
        } catch (error, stack) {
          issues.add({'screen': entry.key, 'error': '$error\n$stack'});
          navigator.popUntil((route) => route.isFirst);
          await pump();
          continue;
        }
        navigator.pop();
        await pump();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      FlutterError.onError = previousErrorHandler;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), null);
      await tester.runAsync(() async {
        await Hive.close();
        await temp.delete(
            recursive: true); // exact directory created by this run
      });
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
      File('${output.path}/manifest.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'capturedAt': DateTime.now().toIso8601String(),
        'viewport': {'width': 390, 'height': 844, 'pixelRatio': 2},
        'data': 'Synthetic sample data in temporary Hive storage',
        'method': 'Production Flutter widgets in widget-test renderer',
        'theme': captureTheme,
        'captures': captures,
        'issues': issues,
        'limitations': [
          'Reference captures, not physical-device screenshots.',
          'Microphone adapter stubbed; no native audio or permissions tested.',
          'No OS status bar, system keyboard, camera or permission dialogs.',
          'Individual screens opened as routes under the actual app theme.',
          'Inter from local font cache; default fallback uses Inter/Windows glyph fonts.',
          'Reports duplicates Progress, captured once.',
          'Settings is not reachable through current active UI; not captured.',
          'Main vertical scroll paginated; nested lists not exhaustively scrolled.',
          'Representative states/forms, not every interaction combination.'
        ],
      }));
      // ignore: avoid_print
      print(
          'CAPTURE RESULT: ${captures.length} images; ${issues.length} recorded issues; ${output.path}');
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
