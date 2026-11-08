import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/screens/home_views.dart';
import 'package:momentum/screens/day_view.dart';
import 'package:momentum/screens/task_screen.dart';
import 'package:momentum/widgets/quick_add_task_dialog.dart';
import 'package:momentum/widgets/task_row.dart';

void main() {
  final service = HiveService.instance;
  late Directory directory;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory =
        await Directory.systemTemp.createTemp('momentum_task_usability_');
    Hive.init(directory.path);
    await service.init();
  });
  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
  });

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: true, alwaysUse24HourFormat: true),
            child: child!),
        home: child));
    await tester.pumpAndSettle();
  }

  Future<void> editor(WidgetTester tester,
      {Task? initial, Future<void> Function(Task)? save}) async {
    await mount(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showTaskFormDialog(context,
                        date: DateTime.now(),
                        initialTask: initial,
                        actionLabel: 'Save task',
                        onSave: save),
                    child: const Text('Create')))));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save task'));
      await Future<void>.delayed(const Duration(milliseconds: 450));
    });
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Task scheduled(String name, String start, {DateTime? date}) => Task(
      task: name,
      dueDate: date ?? DateTime.now(),
      hourSlot: int.parse(start.split(':').first),
      description:
          'Notes to keep\n⏰ Schedule Start: $start\n⏰ Schedule End: 10:20\n⏰ Schedule Bonus: 0');

  testWidgets(
      'editing keeps precise schedule and duration; removing time clears it',
      (tester) async {
    final original = scheduled('Read API notes', '09:35');
    Task? result;
    await editor(tester,
        initial: original, save: (task) async => result = task);
    expect(find.text('Time: 09:35'), findsOneWidget);
    await save(tester);
    expect(result!.id, original.id);
    expect(result!.description, contains('Schedule Start: 09:35'));
    expect(result!.description, contains('Schedule End: 10:20'));
    expect(result!.description, contains('Notes to keep'));
    await editor(tester, initial: result, save: (task) async => result = task);
    await tester.tap(find.byTooltip('Remove time'));
    await save(tester);
    expect(result!.hourSlot, isNull);
    expect(result!.description, isNot(contains('Schedule Start:')));
    expect(service.getTaskScheduledStartMinutes(result!), isNull);
    await finish(tester);
  });

  testWidgets(
      'quick date and optional time persist the selected day and minutes',
      (tester) async {
    await editor(tester, save: (task) => service.addTask(task.dueDate, task));
    await tester.enterText(find.byType(TextField).first, 'Prepare API demo');
    await tester.tap(find.widgetWithText(ActionChip, 'Tomorrow'));
    await tester.tap(find.text('Add time (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '09');
    await tester.enterText(find.byType(TextFormField).at(1), '35');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await save(tester);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final task = service
        .getTasksForDate(tomorrow)
        .singleWhere((t) => t.task == 'Prepare API demo');
    expect(task.dueDate.minute, 35);
    expect(service.getTaskScheduledStartMinutes(task), 575);
    await finish(tester);
  });

  testWidgets('retry after a partial save reuses the same task identity',
      (tester) async {
    final ids = <String>[];
    await editor(tester, save: (task) async {
      ids.add(task.id);
      await service.addTask(task.dueDate, task);
      if (ids.length == 1) throw StateError('post-write failure');
    });
    await tester.enterText(find.byType(TextField).first, 'One task only');
    await save(tester);
    expect(find.textContaining('Could not save'), findsOneWidget);
    await save(tester);
    expect(ids, hasLength(2));
    expect(ids[0], ids[1]);
    expect(
        service
            .getTasksForDate(DateTime.now())
            .where((t) => t.task == 'One task only'),
        hasLength(1));
    await finish(tester);
  });

  testWidgets('Today orders exact times and exposes overdue tasks for review',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final earlier = scheduled('Earlier task', '09:10', date: today);
    final later = scheduled('Later task', '09:50', date: today);
    final overdue = Task(
        task: 'Carry forward',
        dueDate: today.subtract(const Duration(days: 2)));
    await tester.runAsync(() async {
      for (final task in [later, earlier, overdue]) {
        await service.addTask(task.dueDate, task);
      }
    });
    await mount(tester, TodayView(service: service));
    expect(tester.getTopLeft(find.text('Earlier task')).dy,
        lessThan(tester.getTopLeft(find.text('Later task')).dy));
    expect(find.text('Overdue (1)'), findsOneWidget);
    await tester.tap(find.text('Overdue (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Carry forward'), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
      'move-to-today keeps identity and schedule and clears the overdue bucket',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final task = scheduled('Move this task', '09:35',
        date: today.subtract(const Duration(days: 1)));
    await tester.runAsync(() => service.addTask(task.dueDate, task));
    await mount(
        tester,
        TaskScreen(
            date: today, hiveService: service, initialFilter: 'Overdue'));
    await tester.runAsync(
        () => tester.tap(find.byTooltip('Actions for Move this task')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Move to today'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.byType(TaskRow), findsNothing);
    expect(service.getTasksForDate(task.dueDate).where((t) => t.id == task.id),
        isEmpty);
    final moved =
        service.getTasksForDate(today).singleWhere((t) => t.id == task.id);
    expect(moved.description, task.description);
    expect(service.getTaskScheduledStartMinutes(moved), 575);
    await finish(tester);
  });

  testWidgets(
      'calendar edit retains input when its record can no longer be saved',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final task = Task(task: 'Keep calendar edits', dueDate: today);
    await tester.runAsync(() => service.addTask(today, task));
    await mount(tester, DayView(hiveService: service, initialDate: today));
    await tester.tap(find.text('Keep calendar edits').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'Edited calendar task');
    await tester.runAsync(() async {
      await service.deleteTaskByReference(task);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Task'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Edited calendar task'), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('calendar editor deletion closes and Undo restores the same task',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final task = Task(task: 'Recover calendar task', dueDate: today);
    await tester.runAsync(() => service.addTask(today, task));
    await mount(tester, DayView(hiveService: service, initialDate: today));
    await tester
        .runAsync(() => tester.tap(find.text('Recover calendar task').first));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Delete Task')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await Future<void>.delayed(const Duration(milliseconds: 450));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
        service.getTasksForDate(today).where((t) => t.id == task.id), isEmpty);
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(service.getTasksForDate(today).where((t) => t.id == task.id),
        hasLength(1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await finish(tester);
  });
}
