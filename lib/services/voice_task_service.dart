import 'dart:convert';

import '../models/task_model.dart';
import '../models/task_step.dart';
import '../models/voice_task_draft.dart';
import '../utils/task_time_utils.dart';
import 'hive_service.dart';

class VoiceTaskService {
  final HiveService store;
  VoiceTaskService(this.store);

  List<Task> get tasks => store
      .getAllTasksByDate()
      .values
      .expand((tasks) => tasks)
      .where((task) => !task.id.startsWith('journal:'))
      .toList();

  List<Task> matches(String title) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return tasks
        .where((task) => normalize(task.task) == normalize(title))
        .toList();
  }

  Task preview(VoiceTaskDraft draft, {Task? source, required DateTime now}) {
    if (draft.action != VoiceTaskAction.add && source == null) {
      throw StateError('Select the task to change.');
    }
    if (draft.action == VoiceTaskAction.complete) {
      return source!.copyWith(
          done: true,
          status: 'Completed',
          steps: taskSteps(source)
              .map((step) => step.isCompleted
                  ? step
                  : step.copyWith(
                      status: 'Completed',
                      actualMinutes: step.actualMinutes ?? step.minutes,
                      completedAt: now))
              .toList());
    }
    final base = source?.dueDate ?? DateTime(now.year, now.month, now.day);
    final date = draft.date ?? base;
    final due = DateTime(
        date.year,
        date.month,
        date.day,
        draft.hour ?? base.hour,
        draft.hour == null ? base.minute : draft.minute);
    if (draft.steps.isNotEmpty &&
        draft.minutes != null &&
        draft.minutes! < draft.steps.length) {
      throw StateError(
          'Allow at least one minute per step, or review the steps without a total duration.');
    }
    if (source != null &&
        taskSteps(source).isNotEmpty &&
        draft.minutes != null) {
      throw StateError(
          'This project uses individual step times. Change those times in the task editor instead of replacing its total duration.');
    }
    final steps = draft.steps.isEmpty
        ? (source == null ? <TaskStep>[] : taskSteps(source))
        : [
            if (source != null) ...taskSteps(source),
            for (var i = 0; i < draft.steps.length; i++)
              TaskStep(
                  id: '${draft.id}:step:$i',
                  name: draft.steps[i],
                  minutes: draft.minutes == null
                      ? 15
                      : draft.minutes! ~/ draft.steps.length +
                          (i < draft.minutes! % draft.steps.length ? 1 : 0)),
          ];
    if (source == null) {
      return Task(
          id: draft.id,
          task: draft.title,
          dueDate: due,
          steps: steps,
          estimatedMinutes: draft.minutes ?? 15,
          hourSlot: draft.hour);
    }
    if (source.repeatTask && (draft.date != null || draft.hour != null)) {
      throw StateError(
          'Routine scheduling uses its recurrence settings. Use a duration or rename command for a routine.');
    }
    return source.copyWith(
        task: draft.title.isEmpty ? source.task : draft.title,
        dueDate: due,
        estimatedMinutes: draft.minutes,
        hourSlot: draft.hour,
        steps: steps);
  }

  /// Capture before opening the editor, then compare again immediately before save.
  String fingerprint(Task task) => jsonEncode([
        task.id,
        task.task,
        task.description,
        task.dueDate.toIso8601String(),
        task.done,
        task.status,
        task.priority,
        task.category,
        task.delegatedTo,
        task.repeatTask,
        task.repeatFrequency,
        task.urgent,
        task.important,
        task.estimatedMinutes,
        task.hourSlot,
        task.colorValue,
        task.routineEnabled,
        taskSteps(task).map((step) => step.toMap()).toList(),
      ]);

  Future<void> apply(VoiceTaskDraft draft, Task reviewed,
      {Task? source, String? expectedFingerprint}) async {
    if (draft.action == VoiceTaskAction.add) {
      await store.addTask(reviewed.dueDate, reviewed);
      return;
    }
    final current = tasks.where((task) => task.id == source?.id).toList();
    if (current.length != 1 ||
        fingerprint(current.single) != expectedFingerprint) {
      throw StateError(
          'This task changed while you were reviewing it. Analyse the command again before saving.');
    }
    final original = current.single;
    if (original.repeatTask) {
      if (draft.action == VoiceTaskAction.complete) {
        await store.setTaskOccurrenceCompleted(original, DateTime.now(), true);
      } else {
        await store.updateRecurringTaskSeriesByReference(original, reviewed);
      }
    } else if (!await store.updateTaskByReference(original, reviewed)) {
      throw StateError('The selected task is no longer available.');
    }
  }
}
