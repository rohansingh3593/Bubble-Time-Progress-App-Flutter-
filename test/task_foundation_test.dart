import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/models/task_step.dart';
import 'package:momentum/services/api_client.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/utils/task_time_utils.dart';

final day = DateTime(2026, 10, 28);
const dateKey = '2026-10-28';
const legacyDescription = 'Keep these notes\n---PHASES---\n'
    'Setup | install tools | Completed | 5 | true | false | 0 | 2026-10-28T10:00:00\n'
    'Tests | write tests | In Progress | 10 | false | true | |\n'
    'Old format | details | Not Started\n'
    'This malformed row must remain intact | recover me\n'
    'Invalid | minutes | Completed | -5 | false | false | |';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('identity survives renaming and reordering, including equal titles', () {
    final first = TaskStep(
        name: 'Same', minutes: 5, status: 'Completed', actualMinutes: 3);
    final second = TaskStep(name: 'Same', minutes: 10);
    final task = Task(task: 'Same', dueDate: day, steps: [first, second]);
    final edited = task.copyWith(
        task: 'Renamed', steps: [second, first.copyWith(name: 'New name')]);
    expect(edited.id, task.id);
    expect(edited.steps!.map((step) => step.id), [second.id, first.id]);
    expect(edited.steps!.last.actualMinutes, 3);
    expect(edited.steps!.first.isCompleted, isFalse);
    expect(Task(task: 'Same', dueDate: day).id, isNot(task.id));
    expect(() => edited.steps!.clear(), throwsUnsupportedError);
    expect(task.copyWith(newOccurrence: true).id, isNot(task.id));
  });

  test('positive durations are exact; only legacy unspecified values default',
      () {
    for (final minutes in [1, 5, 10, 17, 25, 120, 180, 1440]) {
      expect(normalizeTaskDuration(minutes), minutes);
      expect(taskDurationChoices(minutes), contains(minutes));
      expect(
          taskPlannedMinutes(
              Task(task: 'Task', dueDate: day, estimatedMinutes: minutes)),
          minutes);
    }
    expect(normalizeTaskDuration(null), 15);
    expect(normalizeTaskDuration(0), 15);
    expect(() => normalizeTaskDuration(-1), throwsArgumentError);
    expect(() => TaskStep(name: 'Invalid', minutes: 0), throwsArgumentError);
    expect(() => TaskStep(name: 'Invalid', actualMinutes: -1),
        throwsArgumentError);
  });

  test(
      'typed steps override description, retain text delimiters and actual zero',
      () {
    final step = TaskStep(
        name: 'Plan | build',
        description: 'Line one\nLine two | café',
        minutes: 5,
        status: 'Completed',
        actualMinutes: 0);
    final task = Task(
        task: 'Task',
        dueDate: day,
        description: legacyDescription,
        steps: [step]);
    expect(taskSteps(task).single.id, step.id);
    expect(taskPlannedMinutes(task), 5);
    expect(taskRecordedMinutesForDay(task), 0);
    expect(taskSteps(task.copyWith(steps: [])), isEmpty);
    final restored = TaskStep.fromMap(
        jsonDecode(jsonEncode(step.toMap())) as Map<String, dynamic>);
    expect(restored.toMap(), step.toMap());
  });

  test('legacy parser accepts old fields without changing short durations', () {
    final task =
        Task(task: 'Task', dueDate: day, description: legacyDescription);
    final steps = taskSteps(task);
    expect(steps.map((step) => step.minutes), [5, 10, 15]);
    expect(steps.first.actualMinutes, 0);
    expect(steps.first.completedAt, DateTime(2026, 10, 28, 10));
    expect(
        taskSteps(task).map((step) => step.id), steps.map((step) => step.id));
    expect(taskDescriptionForEditing(task),
        contains('This malformed row must remain intact | recover me'));
    expect(taskDescriptionForEditing(task), contains('Invalid | minutes'));
    expect(task.description, legacyDescription);
  });

  test(
      'cloud payload round trips IDs, typed steps, durations and frozen remote keys',
      () {
    for (final remoteAlias in [null, '2026-10-28-personal-old-name']) {
      final task = Task(
          task: 'Original',
          dueDate: day,
          estimatedMinutes: 5,
          legacyCloudId: remoteAlias,
          steps: [
            TaskStep(name: 'Test | ü', description: 'a\nb', minutes: 10)
          ]);
      final edited = task.copyWith(
          task: 'Renamed', dueDate: day.add(const Duration(days: 1)));
      final payload = jsonDecode(jsonEncode(ApiClient.taskToPayload(edited)))
          as Map<String, dynamic>;
      final restored = ApiClient.taskFromPayload(payload);
      expect(restored.id, task.id);
      expect(ApiClient.taskCloudId(restored), remoteAlias ?? task.id);
      expect(restored.steps!.single.toMap(), task.steps!.single.toMap());
      expect(restored.estimatedMinutes, 5);
    }
  });

  group('persisted migration and identity operations', () {
    late Directory directory;
    final service = HiveService.instance;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('momentum_foundation_');
      Hive.init(directory.path);
      Hive.registerAdapter(TaskAdapter(), override: true);
      Hive.registerAdapter(TaskStepAdapter(), override: true);
    });

    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('reads actual pre-ID Hive bytes and migrates once without losing data',
        () async {
      // This writer deliberately omits fields 16+, exactly as the old app did.
      Hive.registerAdapter(_LegacyTaskWriter(), override: true);
      final box = await Hive.openBox<List>('tasksBox');
      await box.put('__meta_schema_version__', [1]);
      await box.put('__meta_username__', ['Existing user']);
      await box.put('__unrelated_metadata__', ['untouched', 42]);
      final original = Task(
          task: 'Legacy Project',
          dueDate: day,
          description: legacyDescription,
          estimatedMinutes: 5,
          priority: 'High',
          category: 'Work',
          delegatedTo: 'Alex',
          urgent: true,
          hourSlot: 9,
          colorValue: 0xFF43A047);
      await box.put(dateKey, [
        original,
        original.copyWith(
            task: 'Plain Task', description: 'Just notes', estimatedMinutes: 10)
      ]);
      await Hive.close();
      Hive.registerAdapter(TaskAdapter(), override: true);

      await service.init();
      final migratedBox = Hive.box<List>('tasksBox');
      final tasks = migratedBox.get(dateKey)!.cast<Task>();
      final migrated = tasks.first;
      expect(migrated.id, isNot(original.id)); // Old bytes contained no ID.
      expect(tasks.map((task) => task.id).toSet(), hasLength(2));
      expect(migrated.description, legacyDescription);
      expect(migrated.dueDate, original.dueDate);
      expect(migrated.priority, 'High');
      expect(migrated.category, 'Work');
      expect(migrated.delegatedTo, 'Alex');
      expect(migrated.urgent, isTrue);
      expect(migrated.hourSlot, 9);
      expect(migrated.colorValue, 0xFF43A047);
      expect(migrated.estimatedMinutes, 5);
      expect(migrated.steps!.map((step) => step.minutes), [5, 10, 15]);
      expect(migrated.steps!.first.actualMinutes, 0);
      expect(tasks.last.estimatedMinutes, 10);
      expect(tasks.last.steps, isEmpty);
      expect(migrated.legacyCloudId, ApiClient.legacyTaskCloudId(original));
      expect(migratedBox.get('__meta_schema_version__'), [3]);
      expect(migratedBox.get('__meta_username__'), ['Existing user']);
      expect(migratedBox.get('__unrelated_metadata__'), ['untouched', 42]);
      final taskIds = tasks.map((task) => task.id).toList();
      final stepIds = migrated.steps!.map((step) => step.id).toList();
      await Hive.close();
      await service.init();
      final reloaded = Hive.box<List>('tasksBox').get(dateKey)!.cast<Task>();
      expect(reloaded.map((task) => task.id), taskIds);
      expect(reloaded.first.steps!.map((step) => step.id), stepIds);
      expect(reloaded.first.description, legacyDescription);
    });

    test(
        'migration retry preserves committed IDs and repairs duplicate identities',
        () async {
      final box = await Hive.openBox<List>('tasksBox');
      final step = TaskStep(name: 'Typed | step', minutes: 17);
      final task = Task(
          task: 'Same',
          dueDate: day,
          steps: [step],
          legacyCloudId: 'existing-remote-id');
      await box.put('__meta_schema_version__',
          [1]); // Simulate interruption before the version write.
      await box.put(dateKey, [task, task.copyWith()]);
      await service.init();
      final tasks = box.get(dateKey)!.cast<Task>();
      expect(tasks.first.id, task.id);
      expect(tasks.first.steps!.single.id, step.id);
      expect(tasks.first.legacyCloudId, 'existing-remote-id');
      expect(tasks.last.id, isNot(task.id));
      expect(tasks.last.steps!.single.id, isNot(step.id));
      expect(tasks.last.steps!.single.minutes, 17);
      final ids = tasks.map((task) => task.id).toList();
      await box.put('__meta_schema_version__', [1]);
      await service.init();
      expect(box.get(dateKey)!.cast<Task>().map((task) => task.id), ids);
    });

    test('same-name tasks survive stale indexes, rename, reload and deletion',
        () async {
      await service.init();
      final first = Task(task: 'Same', dueDate: day, steps: []);
      final second = Task(task: 'Same', dueDate: day, steps: []);
      await service.addTask(day, first);
      await service.addTask(day, second);
      expect(
          service.getMasterTaskOccurrencesForDate(
              day.add(const Duration(days: 1))),
          hasLength(2));
      await service.updateTask(day, 0,
          second.copyWith(task: 'Renamed', done: true, status: 'Completed'));
      final tasks = Hive.box<List>('tasksBox').get(dateKey)!.cast<Task>();
      expect(tasks.first.id, first.id);
      expect(tasks.first.task, 'Same');
      expect(tasks.last.id, second.id);
      expect(tasks.last.task, 'Renamed');
      await Hive.close();
      await service.init();
      expect(
          await service.updateTaskByReference(
              second, second.copyWith(task: 'Renamed Again')),
          isTrue);
      expect(await service.deleteTaskByReference(second), isTrue);
      expect(Hive.box<List>('tasksBox').get(dateKey)!.cast<Task>().single.id,
          first.id);
    });

    test('typed and legacy completed phases produce equal productivity rewards',
        () async {
      await service.init();
      final task = Task(
          task: 'Project',
          dueDate: day,
          description:
              '---PHASES---\nDone | details | Completed | 30 | true | true | 20 | 2026-10-28T10:00:00');
      final box = Hive.box<List>('tasksBox');
      await box.put(dateKey, [task]);
      final before = service.calculateProductivitySnapshotForDate(day);
      await box.put(dateKey,
          [task.copyWith(description: 'Plain notes', steps: taskSteps(task))]);
      final after = service.calculateProductivitySnapshotForDate(day);
      expect(after.toStorageList(), before.toStorageList());
      expect(after.projectPhasesCompleted, 1);
      expect(after.totalHours, closeTo(20 / 60, 0.00001));
    });

    test(
        'recurring occurrences retain distinct IDs through completion and edits',
        () async {
      await service.init();
      final routine = Task(
          task: 'Routine',
          dueDate: day,
          repeatTask: true,
          repeatFrequency: 'Daily',
          estimatedMinutes: 5,
          steps: []);
      await service.addTask(day, routine);
      final tomorrow = day.add(const Duration(days: 1));
      final projection =
          service.getMasterTaskOccurrencesForDate(tomorrow).single;
      expect(projection.id, isNot(routine.id));
      expect(service.getMasterTaskOccurrencesForDate(tomorrow).single.id,
          projection.id);
      await service.setTaskOccurrenceCompleted(projection, tomorrow, true);
      expect(service.getMasterTaskOccurrencesForDate(tomorrow).single.id,
          projection.id);
      await service.setTaskOccurrenceCompleted(projection, tomorrow, false);
      expect(service.getMasterTaskOccurrencesForDate(tomorrow).single.id,
          projection.id);
      expect(
          service.getMasterTaskOccurrencesForDate(day).single.id, routine.id);
      await service.updateRecurringTaskSeriesByReference(
          routine, routine.copyWith(task: 'Renamed Routine'));
      expect(
          service.getMasterTaskOccurrencesForDate(day).single.id, routine.id);
      expect(service.getMasterTaskOccurrencesForDate(tomorrow).single.id,
          projection.id);
      expect(service.getMasterTaskOccurrencesForDate(tomorrow).single.task,
          'Renamed Routine');
    });
  });
}

class _LegacyTaskWriter extends TypeAdapter<Task> {
  @override
  int get typeId => 0;

  @override
  Task read(BinaryReader reader) => TaskAdapter().read(reader);

  @override
  void write(BinaryWriter writer, Task task) {
    final fields = [
      task.task,
      task.done,
      task.description,
      task.dueDate,
      task.priority,
      task.status,
      task.category,
      task.delegatedTo,
      task.repeatTask,
      task.repeatFrequency,
      task.urgent,
      task.important,
      task.estimatedMinutes,
      task.hourSlot,
      task.colorValue,
      task.routineEnabled
    ];
    writer.writeByte(fields.length);
    for (var index = 0; index < fields.length; index++) {
      writer.writeByte(index);
      writer.write(fields[index]);
    }
  }
}
