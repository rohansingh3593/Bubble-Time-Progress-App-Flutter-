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

  Task({
    required this.task,
    this.done = false,
    this.description = '',
    required this.dueDate,
    this.priority = 'Medium',
    this.status = 'Not Started',
    this.category = 'Personal',
    this.delegatedTo,
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
    );
  }
}
