// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      task: fields[0] as String,
      done: fields[1] as bool? ?? false,
      description: fields[2] as String? ?? '',
      dueDate: fields[3] as DateTime? ?? DateTime.now(),
      priority: fields[4] as String? ?? 'Medium',
      status: fields[5] as String? ?? 'Not Started',
      category: fields[6] as String? ?? 'Personal',
      delegatedTo: fields[7] as String?,
      repeatTask: fields[8] as bool? ?? false,
      repeatFrequency: fields[9] as String?,
      urgent: fields[10] as bool? ?? false,
      important: fields[11] as bool? ?? false,
      estimatedMinutes: fields[12] as int? ?? 0,
      hourSlot: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.task)
      ..writeByte(1)
      ..write(obj.done)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.delegatedTo)
      ..writeByte(8)
      ..write(obj.repeatTask)
      ..writeByte(9)
      ..write(obj.repeatFrequency)
      ..writeByte(10)
      ..write(obj.urgent)
      ..writeByte(11)
      ..write(obj.important)
      ..writeByte(12)
      ..write(obj.estimatedMinutes)
      ..writeByte(13)
      ..write(obj.hourSlot);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
