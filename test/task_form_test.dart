import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/models/task_step.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/widgets/quick_add_task_dialog.dart';

void main() {
  late Directory directory;
  final day = DateTime(2026, 10, 28);

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('momentum_task_form_');
    Hive.init(directory.path);
    await HiveService.instance.init();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> openEditor(
      WidgetTester tester, Task task, void Function(Task?) save) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => save(await showTaskFormDialog(context,
            date: day, initialTask: task, actionLabel: 'Save Task')),
        child: const Text('Edit'),
      ),
    ))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  testWidgets('editing and reordering keeps completion attached to step IDs',
      (tester) async {
    final completed = TaskStep(
        name: 'Same',
        description: 'First | detail\nSecond line',
        minutes: 5,
        status: 'Completed',
        actualMinutes: 0,
        completedAt: day);
    final pending = TaskStep(name: 'Same', minutes: 10);
    final task = Task(
        task: 'Project',
        dueDate: day,
        description: 'Plain notes',
        steps: [completed, pending]);
    Task? result;
    await openEditor(tester, task, (value) => result = value);
    final titleField = find.widgetWithText(TextField, 'Project');
    await tester.enterText(titleField, 'Renamed Project');
    final down = find.widgetWithText(TextButton, 'Down').first;
    await tester.ensureVisible(down);
    await tester.tap(down);
    await tester.pumpAndSettle();
    final renamedStepField = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Phase 2 Name');
    await tester.ensureVisible(renamedStepField);
    await tester.enterText(renamedStepField, 'Renamed Step');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Task'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(result, isNotNull);
    expect(result!.id, task.id);
    expect(result!.task, 'Renamed Project');
    expect(result!.steps!.map((step) => step.id), [pending.id, completed.id]);
    expect(result!.steps!.map((step) => step.minutes), [10, 5]);
    expect(result!.steps!.last.name, 'Renamed Step');
    expect(result!.steps!.last.description, completed.description);
    expect(result!.steps!.last.actualMinutes, 0);
    expect(result!.steps!.last.completedAt, day);
    expect(result!.steps!.first.isCompleted, isFalse);
    expect(result!.description, 'Plain notes');
    expect(result!.estimatedMinutes, 15);
  });

  testWidgets('reopening a step clears its recorded completion data',
      (tester) async {
    final step = TaskStep(
        name: 'Finished',
        minutes: 10,
        status: 'Completed',
        actualMinutes: 5,
        completedAt: day);
    final task = Task(task: 'Project', dueDate: day, steps: [step]);
    Task? result;
    await openEditor(tester, task, (value) => result = value);
    final status = find.byWidgetPredicate((widget) =>
        widget is DropdownButton<String> && widget.value == 'Completed');
    await tester.ensureVisible(status);
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Progress').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Task'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result!.steps!.single.id, step.id);
    expect(result!.steps!.single.status, 'In Progress');
    expect(result!.steps!.single.actualMinutes, isNull);
    expect(result!.steps!.single.completedAt, isNull);
  });

  for (final minutes in [5, 10, 25]) {
    testWidgets(
        'opening and saving a $minutes minute routine preserves its duration',
        (tester) async {
      final task = Task(
          task: 'Routine',
          dueDate: day,
          repeatTask: true,
          repeatFrequency: 'Daily',
          estimatedMinutes: minutes,
          steps: []);
      Task? result;
      await openEditor(tester, task, (value) => result = value);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Task'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(result!.id, task.id);
      expect(result!.estimatedMinutes, minutes);
    });
  }
}
