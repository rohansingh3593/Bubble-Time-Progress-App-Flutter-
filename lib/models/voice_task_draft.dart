import '../utils/entity_id.dart';

enum VoiceTaskAction { add, edit, complete }

/// A proposal only. Recognition and parsing never write to task storage.
class VoiceTaskDraft {
  final String id;
  final VoiceTaskAction action;
  final String title;
  final String target;
  final DateTime? date;
  final int? hour;
  final int minute;
  final int? minutes;
  final List<String> steps;
  final List<String> notes;

  VoiceTaskDraft({
    String? id,
    required this.action,
    this.title = '',
    this.target = '',
    this.date,
    this.hour,
    this.minute = 0,
    this.minutes,
    List<String> steps = const [],
    List<String> notes = const [],
  })  : id = id ?? newEntityId(),
        steps = List.unmodifiable(steps),
        notes = List.unmodifiable(notes);
}
