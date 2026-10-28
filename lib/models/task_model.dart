import 'package:hive/hive.dart';
import '../utils/entity_id.dart';
import 'task_step.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class Task {
  @HiveField(0)
  String task;

  @HiveField(1, defaultValue: false)
  bool done;

  @HiveField(2, defaultValue: '')
  String description;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4, defaultValue: 'Medium')
  String priority;

  @HiveField(5, defaultValue: 'Not Started')
  String status;

  @HiveField(6, defaultValue: 'Personal')
  String category;

  @HiveField(7)
  String? delegatedTo;

  @HiveField(8, defaultValue: false)
  bool repeatTask;

  @HiveField(9)
  String? repeatFrequency;

  @HiveField(10, defaultValue: false)
  bool urgent;

  @HiveField(11, defaultValue: false)
  bool important;

  @HiveField(12, defaultValue: 0)
  int estimatedMinutes;

  @HiveField(13)
  int? hourSlot;

  @HiveField(14, defaultValue: 0xFF1E88E5)
  int colorValue;

  @HiveField(15, defaultValue: true)
  bool routineEnabled;

  @HiveField(16)
  final String id;

  /// Null means a legacy record; an empty list explicitly means no steps.
  @HiveField(17)
  final List<TaskStep>? steps;

  /// Frozen remote key for records created by the older slug-based client.
  @HiveField(18)
  final String? legacyCloudId;

  Task({
    required this.task,
    this.done = false,
    this.description = '',
    required DateTime? dueDate,
    this.priority = 'Medium',
    this.status = 'Not Started',
    this.category = 'Personal',
    this.delegatedTo,
    this.repeatTask = false,
    this.repeatFrequency,
    this.urgent = false,
    this.important = false,
    this.estimatedMinutes = 0,
    this.hourSlot,
    this.colorValue = 0xFF1E88E5,
    this.routineEnabled = true,
    String? id,
    List<TaskStep>? steps,
    this.legacyCloudId,
  })  : dueDate = dueDate ?? DateTime.now(),
        id = id == null || id.isEmpty ? newEntityId() : id,
        steps = steps == null ? null : List.unmodifiable(steps);

  Task copyWith({
    String? task,
    bool? done,
    String? description,
    DateTime? dueDate,
    String? priority,
    String? status,
    String? category,
    String? delegatedTo,
    bool? repeatTask,
    String? repeatFrequency,
    bool? urgent,
    bool? important,
    int? estimatedMinutes,
    int? hourSlot,
    int? colorValue,
    bool? routineEnabled,
    String? id,
    List<TaskStep>? steps,
    String? legacyCloudId,
    bool newOccurrence = false,
  }) {
    return Task(
      id: id ?? (newOccurrence ? newEntityId() : this.id),
      steps: steps ?? this.steps,
      legacyCloudId:
          legacyCloudId ?? (newOccurrence ? null : this.legacyCloudId),
      task: task ?? this.task,
      done: done ?? this.done,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      delegatedTo: delegatedTo ?? this.delegatedTo,
      repeatTask: repeatTask ?? this.repeatTask,
      repeatFrequency: repeatFrequency ?? this.repeatFrequency,
      urgent: urgent ?? this.urgent,
      important: important ?? this.important,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      hourSlot: hourSlot ?? this.hourSlot,
      colorValue: colorValue ?? this.colorValue,
      routineEnabled: routineEnabled ?? this.routineEnabled,
    );
  }
}
