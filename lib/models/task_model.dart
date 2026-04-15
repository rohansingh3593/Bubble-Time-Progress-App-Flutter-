import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class Task {
  @HiveField(0)
  String task;

  @HiveField(1)
  bool done;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  String priority;

  @HiveField(5)
  String status;

  @HiveField(6)
  String category;

  @HiveField(7)
  String? delegatedTo;


  @HiveField(8)
  bool repeatTask;

  @HiveField(9)
  String? repeatFrequency;

  @HiveField(10)
  bool urgent;

  @HiveField(11)
  bool important;

  @HiveField(12)
  int estimatedMinutes;

  @HiveField(13)
  int? hourSlot;

  Task({
    required this.task,
    this.done = false,
    this.description = '',
    required this.dueDate,
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
  });

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
  }) {
    return Task(
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
    );
  }
}
