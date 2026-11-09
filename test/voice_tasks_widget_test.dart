import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/screens/voice_tasks_screen.dart';
import 'package:momentum/models/task_model.dart';
import 'package:momentum/models/voice_task_draft.dart';
import 'package:momentum/services/hive_service.dart';
import 'package:momentum/services/offline_voice_service.dart';
import 'package:momentum/services/voice_task_service.dart';

class FakeCapture implements VoiceCapture {
  @override
  final ValueNotifier<double> level = ValueNotifier<double>(0);
  String transcript =
      'Please remind me to study Python next Friday at six pm for ten minutes';
  Object? startError;
  bool disposed = false;
  @override
  Future<void> start() async {
    if (startError != null) throw startError!;
  }

  @override
  Future<String> stopAndTranscribe({String language = ''}) async => transcript;
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    level.dispose();
  }
}

class MemoryVoiceTasks extends VoiceTaskService {
  MemoryVoiceTasks(super.store);
  final saved = <Task>[];
  @override
  List<Task> get tasks => saved;
  @override
  Future<void> apply(VoiceTaskDraft draft, Task reviewed,
      {Task? source, String? expectedFingerprint}) async {
    saved.add(reviewed);
  }
}

void main() {
  late Directory directory;
  final hive = HiveService.instance;
  late MemoryVoiceTasks taskService;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('momentum_voice_widget_');
    Hive.init(directory.path);
    await hive.init();
    taskService = MemoryVoiceTasks(hive);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, FakeCapture capture) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: VoiceTasksScreen(
            hiveService: hive, capture: capture, taskService: taskService)));
  }

  testWidgets(
      'recording and analysis cannot save until the review is confirmed',
      (tester) async {
    await open(tester, FakeCapture());
    await tester.tap(find.text('Record a command'));
    await tester.pump();
    await tester.tap(find.text('Stop recording (maximum 30 seconds)'));
    await tester.pumpAndSettle();
    expect(find.text('Review voice add'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Date interpreted as')),
        findsOneWidget);
    expect(find.widgetWithText(TextField, 'study Python'), findsOneWidget);
    expect(taskService.tasks, isEmpty);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save task'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final task = taskService.tasks.single;
    expect(task.task, 'study Python');
    expect(task.estimatedMinutes, 10);
    expect(task.dueDate.hour, 18);
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('microphone denial keeps typed commands available',
      (tester) async {
    final capture = FakeCapture()
      ..startError = StateError('Microphone permission is needed.');
    await open(tester, capture);
    await tester.tap(find.text('Record a command'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone permission is needed.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Add walk for five minutes');
    await tester.tap(find.text('Analyse command'));
    await tester.pumpAndSettle();
    expect(find.text('ADD: walk'), findsOneWidget);
    expect(taskService.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(capture.disposed, isTrue);
  });

  testWidgets('listening trace follows microphone levels and stops on cancel',
      (tester) async {
    final capture = FakeCapture();
    await open(tester, capture);
    expect(find.text('Listening...'), findsNothing);
    await tester.tap(find.text('Record a command'));
    await tester.pump();
    expect(find.text('Listening...'), findsOneWidget);
    expect(find.text('Speak now...'), findsOneWidget);
    capture.level.value = 0.8;
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Sound detected'), findsOneWidget);
    final meter = tester.widget<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.label == 'Microphone sound level'));
    expect(meter.properties.value, '80 percent');
    capture.level.value = 0;
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Speak now...'), findsOneWidget);
    await tester.tap(find.text('Cancel recording'));
    await tester.pumpAndSettle();
    expect(find.text('Listening...'), findsNothing);
    expect(taskService.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
