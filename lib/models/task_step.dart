import 'package:hive/hive.dart';

import '../utils/entity_id.dart';

part 'task_step.g.dart';

/// A persisted task phase. List position controls display order, never identity.
@HiveType(typeId: 1)
class TaskStep {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2, defaultValue: '')
  final String description;
  @HiveField(3, defaultValue: 'Not Started')
  final String status;
  @HiveField(4, defaultValue: 15)
  final int minutes;
  @HiveField(5, defaultValue: false)
  final bool urgent;
  @HiveField(6, defaultValue: false)
  final bool important;
  @HiveField(7)
  final int? actualMinutes;
  @HiveField(8)
  final DateTime? completedAt;

  TaskStep({
    String? id,
    required this.name,
    this.description = '',
    this.status = 'Not Started',
    this.minutes = 15,
    this.urgent = false,
    this.important = false,
    this.actualMinutes,
    this.completedAt,
  }) : id = id == null || id.isEmpty ? newEntityId() : id {
    if (minutes <= 0) {
      throw ArgumentError.value(minutes, 'minutes', 'Must be positive');
    }
    if (actualMinutes != null && actualMinutes! < 0) {
      throw ArgumentError.value(
          actualMinutes, 'actualMinutes', 'Cannot be negative');
    }
  }

  bool get isCompleted => status.trim().toLowerCase() == 'completed';
  int get recordedMinutes => actualMinutes ?? minutes;

  TaskStep copyWith({
    String? id,
    String? name,
    String? description,
    String? status,
    int? minutes,
    bool? urgent,
    bool? important,
    int? actualMinutes,
    DateTime? completedAt,
    bool clearCompletion = false,
  }) =>
      TaskStep(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        status: status ?? this.status,
        minutes: minutes ?? this.minutes,
        urgent: urgent ?? this.urgent,
        important: important ?? this.important,
        actualMinutes:
            clearCompletion ? null : actualMinutes ?? this.actualMinutes,
        completedAt: clearCompletion ? null : completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'status': status,
        'minutes': minutes,
        'urgent': urgent,
        'important': important,
        'actual_minutes': actualMinutes,
        'completed_at': completedAt?.toIso8601String(),
      };

  factory TaskStep.fromMap(Map<String, dynamic> map) => TaskStep(
        id: map['id'] as String?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        status: map['status'] as String? ?? 'Not Started',
        minutes: map['minutes'] as int? ?? 15,
        urgent: map['urgent'] as bool? ?? false,
        important: map['important'] as bool? ?? false,
        actualMinutes: map['actual_minutes'] as int?,
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.parse(map['completed_at'] as String),
      );
}
