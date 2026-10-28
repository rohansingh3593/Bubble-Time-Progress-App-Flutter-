import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/models/task_step.dart';
import 'package:momentum/models/voice_task_draft.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/services/voice_task_parser.dart';
import 'package:momentum/services/voice_task_service.dart';

void main() {
  final today = DateTime(2026, 10, 28, 14);
  final parser = VoiceTaskParser();
  test('English speech extracts an exact short duration, date and time', () {
    final draft = parser
        .parse('Add study Python tomorrow at 6 pm for ten minutes.', now: today)
        .single;
    expect(draft.title, 'study Python');
    expect(draft.date, DateTime(2026, 10, 29));
    expect(draft.hour, 18);
    expect(draft.minutes, 10);
  });
  test('Hindi and mixed Hindi-English commands preserve task text', () {
    final draft = parser
        .parse('कल शाम छह बजे Python पढ़ना दस मिनट के लिए जोड़ो।', now: today)
        .single;
    expect(draft.title, 'Python पढ़ना');
    expect(draft.date, DateTime(2026, 10, 29));
    expect(draft.hour, 18);
    expect(draft.minutes, 10);
    expect(
        parser
            .parse('आज सुबह ७ बजे योग ५ मिनट जोड़ो', now: today)
            .single
            .minutes,
        5);
    expect(
        parser
            .parse('Add walk kal for paanch minutes', now: today)
            .single
            .title,
        'walk');
  });
  test('explicit spoken steps and multiple commands are drafts only', () {
    final drafts = parser.parse(
        'Add launch project with steps plan, build, test; Add walk for five minutes',
        now: today);
    expect(drafts, hasLength(2));
    expect(drafts.first.steps, ['plan', 'build', 'test']);
    expect(drafts.last.minutes, 5);
    expect(drafts.first.id, isNot(drafts.last.id));
  });
  test('rename, duration edits and completion identify the intended target',
      () {
    final rename = parser
        .parse('Rename study Python to practise Python', now: today)
        .single;
    expect(rename.action, VoiceTaskAction.edit);
    expect(rename.target, 'study Python');
    expect(rename.title, 'practise Python');
    final edit = parser
        .parse('Edit practise Python for twenty five minutes', now: today)
        .single;
    expect(edit.target, 'practise Python');
    expect(edit.minutes, 25);
    expect(parser.parse('Python पढ़ना पूरा कर दो', now: today).single.target,
        'Python पढ़ना');
    expect(parser.parse('Mark study Python as done', now: today).single.target,
        'study Python');
  });
  test('invalid durations, dates, negations and empty input require correction',
      () {
    for (final text in [
      '',
      'Add run for zero minutes',
      'Add run for 2000 minutes',
      'Add run for -5 minutes',
      'Add run for 1.5 hours',
      'Add run for one hundred minutes',
      'Add run 2026-02-30',
      'Do not complete run',
      'Delete run',
      'run पूरा मत करो'
    ]) {
      expect(() => parser.parse(text, now: today), throwsFormatException,
          reason: text);
    }
    expect(() => parser.parse('Add walk at 29:00', now: today),
        throwsFormatException);
    expect(
        parser
            .parse('Add walk for twenty one minutes', now: today)
            .single
            .minutes,
        21);
  });

  group('voice review and local persistence', () {
    late Directory directory;
    final hive = HiveService.instance;
    late VoiceTaskService service;
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      directory = await Directory.systemTemp.createTemp('momentum_voice_');
      Hive.init(directory.path);
      await hive.init();
      service = VoiceTaskService(hive);
    });
    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    test('preview never writes and applying the same creation is idempotent',
        () async {
      final draft =
          parser.parse('Add project with steps plan, test', now: today).single;
      final preview = service.preview(draft, now: today);
      expect(service.tasks, isEmpty);
      expect(service.preview(draft, now: today).steps!.map((step) => step.id),
          preview.steps!.map((step) => step.id));
      await service.apply(draft, preview);
      await service.apply(draft, preview);
      expect(service.tasks, hasLength(1));
      expect(service.tasks.single.id, draft.id);
    });
    test('spoken total is preserved when creating steps', () {
      final draft = parser
          .parse('Add project for 25 minutes with steps plan, build, test',
              now: today)
          .single;
      final preview = service.preview(draft, now: today);
      expect(preview.steps!.map((step) => step.minutes), [9, 8, 8]);
      expect(preview.estimatedMinutes, 25);
      final tooShort = parser
          .parse('Add project for 2 minutes with steps plan, build, test',
              now: today)
          .single;
      expect(() => service.preview(tooShort, now: today), throwsStateError);
    });
    test(
        'unsupported project totals and routine scheduling are not silently ignored',
        () {
      final project = Task(
          task: 'Project', dueDate: today, steps: [TaskStep(name: 'Build')]);
      final duration =
          parser.parse('Edit project for 25 minutes', now: today).single;
      expect(() => service.preview(duration, source: project, now: today),
          throwsStateError);
      final routine =
          Task(task: 'Routine', dueDate: today, repeatTask: true, steps: []);
      final schedule = parser.parse('Edit routine at 6 pm', now: today).single;
      expect(() => service.preview(schedule, source: routine, now: today),
          throwsStateError);
    });
    test('duplicate names require a selected ID and stale edits are rejected',
        () async {
      final first = Task(task: 'Read', dueDate: today, steps: []);
      final second = Task(task: 'Read', dueDate: today, steps: []);
      await hive.addTask(today, first);
      await hive.addTask(today, second);
      expect(service.matches('read'), hasLength(2));
      final draft = parser.parse('Rename read to study', now: today).single;
      final fingerprint = service.fingerprint(second);
      final preview = service.preview(draft, source: second, now: today);
      await hive.updateTaskByReference(
          second, second.copyWith(task: 'Different'));
      await expectLater(
          service.apply(draft, preview,
              source: second, expectedFingerprint: fingerprint),
          throwsStateError);
      expect(service.tasks.first.task, 'Read');
      expect(service.tasks.last.task, 'Different');
    });
    test('reviewed completion preserves step IDs and updates their progress',
        () async {
      final task = Task(
          task: 'Project',
          dueDate: today,
          steps: [TaskStep(name: 'Test', minutes: 5)]);
      await hive.addTask(today, task);
      final source = service.tasks.single;
      final draft = parser.parse('Complete project', now: today).single;
      final preview = service.preview(draft, source: source, now: today);
      expect(service.tasks.single.done, isFalse);
      await service.apply(draft, preview,
          source: source, expectedFingerprint: service.fingerprint(source));
      expect(service.tasks.single.done, isTrue);
      expect(service.tasks.single.steps!.single.id, task.steps!.single.id);
      expect(service.tasks.single.steps!.single.actualMinutes, 5);
    });
    test('rescheduling moves the same task ID to the correct date bucket',
        () async {
      final task =
          Task(task: 'Read', dueDate: today, steps: [], estimatedMinutes: 5);
      await hive.addTask(today, task);
      final source = service.tasks.single;
      final draft =
          parser.parse('Reschedule read tomorrow at 6 pm', now: today).single;
      final preview = service.preview(draft, source: source, now: today);
      await service.apply(draft, preview,
          source: source, expectedFingerprint: service.fingerprint(source));
      final box = Hive.box<List>('tasksBox');
      expect(box.get('2026-10-28'), isEmpty);
      expect((box.get('2026-10-29')!.single as Task).id, task.id);
      expect(service.tasks.single.dueDate.hour, 18);
      expect(box.get('__pending_task_move__'), isNull);
    });
    test('startup replays an interrupted move without duplicating the task',
        () async {
      final task = Task(task: 'Read', dueDate: today, steps: []);
      await hive.addTask(today, task);
      final moved = task.copyWith(dueDate: DateTime(2026, 10, 29));
      final box = Hive.box<List>('tasksBox');
      await box
          .put('__pending_task_move__', ['2026-10-28', '2026-10-29', moved]);
      await box.put('2026-10-29', [moved]); // Crash after destination write.
      await Hive.close();
      await hive.init();
      expect(service.tasks, hasLength(1));
      expect(service.tasks.single.id, task.id);
      expect(service.tasks.single.dueDate, moved.dueDate);
      expect(Hive.box<List>('tasksBox').get('__pending_task_move__'), isNull);
    });
  });
}
