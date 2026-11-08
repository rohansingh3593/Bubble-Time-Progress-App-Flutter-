import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:momentum/main.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/screens/journal_view.dart';
import 'package:momentum/screens/log_earn_view.dart';
import 'package:momentum/screens/home_views.dart';
import 'package:momentum/screens/task_screen.dart';
import 'package:momentum/widgets/quick_add_task_dialog.dart';
import 'package:momentum/widgets/task_row.dart';

void main() {
  late Directory directory;
  final service = HiveService.instance;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    directory = await Directory.systemTemp.createTemp('momentum_ux_');
    Hive.init(directory.path);
    await service.init();
  });
  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
  });

  Future<void> phone(WidgetTester tester, {double width = 390}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('quick add stores a changed date in its selected date bucket',
      (tester) async {
    final original = DateTime(2026, 10, 28);
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showQuickAddTaskDialog(context, original, service),
                    child: const Text('Create'))))));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Read API docs');
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('29').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(
        service
            .getTasksForDate(original)
            .where((t) => t.task == 'Read API docs'),
        isEmpty);
    expect(
        service
            .getTasksForDate(DateTime(2026, 10, 29))
            .where((t) => t.task == 'Read API docs'),
        hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('task and Log and Earn filters expose horizontal scrolling',
      (tester) async {
    await phone(tester, width: 320);
    await tester.pumpWidget(MaterialApp(
      home: TaskScreen(date: DateTime.now(), hiveService: service),
    ));
    expect(find.byType(Scrollbar), findsOneWidget);
    final routineFilter = find.widgetWithText(ChoiceChip, 'Routines');
    await tester.ensureVisible(routineFilter);
    await tester.tap(routineFilter);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(routineFilter).selected, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    await tester.pumpWidget(MaterialApp(
      home: LogEarnView(hiveService: service),
    ));
    expect(find.byType(Scrollbar), findsOneWidget);
    final pendingFilter = find.widgetWithText(ChoiceChip, 'Pending');
    await tester.ensureVisible(pendingFilter);
    await tester.tap(pendingFilter);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(pendingFilter).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new task capture keeps advanced fields collapsed by default',
      (tester) async {
    final date = DateUtils.dateOnly(DateTime.now());
    await phone(tester, width: 320);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showTaskFormDialog(context,
                        date: date, onSave: (_) async {}),
                    child: const Text('Create'))))));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Task Name *'), findsOneWidget);
    expect(find.textContaining('Due date:'), findsOneWidget);
    expect(find.text('Add time (optional)'), findsOneWidget);
    expect(find.text('Repeat and more options'), findsOneWidget);
    expect(find.text('Repeat Task'), findsNothing);

    await tester.tap(find.text('Repeat and more options'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat Task'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
  });

  testWidgets('failed task write retains the editor and permits retry',
      (tester) async {
    var attempts = 0;
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showTaskFormDialog(context,
                            date: DateTime.now(), onSave: (task) async {
                          attempts++;
                          if (attempts == 1)
                            throw StateError('disk unavailable');
                          await service.addTask(task.dueDate, task);
                        }),
                    child: const Text('Create'))))));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Keep my input');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Keep my input'), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
        service
            .getTasksForDate(DateTime.now())
            .where((t) => t.task == 'Keep my input'),
        hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('hour creation persists schedule placement', (tester) async {
    final date = DateTime.now();
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showTaskFormDialog(context,
                        date: date,
                        initialHourSlot: 9,
                        onSave: (task) => service.addTask(task.dueDate, task)),
                    child: const Text('Add at nine'))))));
    await tester.tap(find.text('Add at nine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Scheduled work');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    final task = service
        .getTasksForDate(date)
        .firstWhere((t) => t.task == 'Scheduled work');
    expect(task.hourSlot, 9);
    expect(task.description, contains('Schedule Start:'));
    expect(task.dueDate.hour, 9);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('journal preserves independent drafts across dates and reopening',
      (tester) async {
    final date = DateTime(2026, 10, 28);
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: JournalView(hiveService: service, initialDate: date)));
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), 'Wednesday thoughts');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() => tester.tap(find.byTooltip('Next day')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Wednesday thoughts'), findsNothing);
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), 'Thursday thoughts');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() => tester.tap(find.byTooltip('Previous day')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Wednesday thoughts'), findsOneWidget);
    expect(service.getJournalDraft(date.add(const Duration(days: 1)))?['text'],
        'Thursday thoughts');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
        home: JournalView(hiveService: service, initialDate: date)));
    expect(find.text('Wednesday thoughts'), findsOneWidget);
    expect(service.getJournalEntryForDate(date), isNull);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('saved journal stays saved after leaving and reopening',
      (tester) async {
    final date = DateTime(2026, 10, 28);
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => JournalView(
                                hiveService: service, initialDate: date))),
                    child: const Text('Open Journal'))))));

    await tester.tap(find.text('Open Journal'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), 'Saved reflection');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save reflection'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(service.getJournalEntryForDate(date), isNotNull);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Back'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Open Journal'), findsOneWidget);
    expect(service.getJournalDraft(date), isNull);

    await tester.tap(find.text('Open Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Entry saved'), findsOneWidget);
    expect(find.text('Draft restored'), findsNothing);
    expect(find.text('Saved reflection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('select all is read only until explicit bulk confirmation',
      (tester) async {
    final date = DateTime.now();
    final task = Task(task: 'Selectable work', dueDate: date);
    await tester.runAsync(() => service.addTask(date, task));
    await phone(tester);
    await tester
        .pumpWidget(MaterialApp(home: LogEarnView(hiveService: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(
        service.getTasksForDate(date).firstWhere((t) => t.id == task.id).done,
        isFalse);
    final complete = find.textContaining('Complete selected (');
    await tester.runAsync(() => tester.tap(complete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
        service.getTasksForDate(date).firstWhere((t) => t.id == task.id).done,
        isFalse);
    await tester.runAsync(() => tester.tap(complete));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Complete selected'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(
        service.getTasksForDate(date).firstWhere((t) => t.id == task.id).done,
        isTrue);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('task checkbox completes and reopens the same record',
      (tester) async {
    final date = DateTime.now();
    final task = Task(task: 'Checkbox task', dueDate: date);
    await tester.runAsync(() => service.addTask(date, task));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder(
                valueListenable: service.getBoxListenable(),
                builder: (context, _, __) => TaskRow(
                    task: service
                        .getTasksForDate(date)
                        .firstWhere((t) => t.id == task.id),
                    date: date,
                    service: service)))));
    await tester.runAsync(() async {
      await tester.tap(find.byType(Checkbox));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
        service.getTasksForDate(date).firstWhere((t) => t.id == task.id).done,
        isTrue);
    await tester.runAsync(() async {
      await tester.tap(find.byType(Checkbox));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
        service.getTasksForDate(date).firstWhere((t) => t.id == task.id).done,
        isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('small phone exposes all primary destinations and Settings',
      (tester) async {
    await phone(tester, width: 320);
    await tester.pumpWidget(MyApp(hiveService: service));
    await tester.pumpAndSettle();
    for (final label in ['Today', 'Plan', 'Progress', 'More']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Settings'), 350,
        scrollable: find
            .descendant(
                of: find.byType(MoreView), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
      'journal supports large text and an open keyboard on a small dark phone',
      (tester) async {
    await phone(tester, width: 320);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: JournalView(hiveService: service)));
    await tester.pumpAndSettle();
    expect(find.text('Save reflection'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
      'task form remains usable with keyboard and preserves a cancelled draft',
      (tester) async {
    await phone(tester, width: 320);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showTaskFormDialog(context, date: DateTime.now()),
                    child: const Text('Create'))))));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Unsaved task');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard task changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved task'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('task deletion can restore the same task identity',
      (tester) async {
    final task = Task(task: 'Recover this task', dueDate: DateTime.now());
    await tester.runAsync(() => service.addTask(task.dueDate, task));
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: TaskScreen(date: task.dueDate, hiveService: service)));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => tester.tap(find.byTooltip('Actions for Recover this task')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Delete')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(service.getTasksForDate(task.dueDate).where((t) => t.id == task.id),
        isEmpty);
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(service.getTasksForDate(task.dueDate).where((t) => t.id == task.id),
        hasLength(1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
      'Today refreshes its date and tasks when the app resumes after midnight',
      (tester) async {
    var now = DateTime(2026, 10, 28, 23, 59);
    final tomorrow =
        Task(task: 'Tomorrow task', dueDate: DateTime(2026, 10, 29));
    await tester.runAsync(() => service.addTask(tomorrow.dueDate, tomorrow));
    await tester.pumpWidget(
        MaterialApp(home: TodayView(service: service, now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow task'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 10, 29, 0, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow task'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('task search stays usable with a large history', (tester) async {
    final date = DateUtils.dateOnly(DateTime.now());
    final tasks =
        List.generate(250, (i) => Task(task: 'History item $i', dueDate: date));
    await tester.runAsync(() => Hive.box<List>('tasksBox').put(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        tasks));
    await phone(tester);
    await tester.pumpWidget(
        MaterialApp(home: TaskScreen(date: date, hiveService: service)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'History item 249');
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(TaskRow), matching: find.text('History item 249')),
        findsOneWidget);
    expect(find.byType(TaskRow), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('draft storage survives reopening and invalid spending is rejected',
      () async {
    final date = DateTime(2026, 10, 28);
    await service.saveJournalDraft(date, 'Persistent draft', 'Good');
    await service.setStartScreen(1);
    await Hive.close();
    await service.init();
    expect(service.getJournalDraft(date)?['text'], 'Persistent draft');
    expect(service.getStartScreen(), 1);
    await expectLater(
        service.withdrawRewardMoney(amountRupees: 0, reason: 'Invalid'),
        throwsArgumentError);
  });
}
