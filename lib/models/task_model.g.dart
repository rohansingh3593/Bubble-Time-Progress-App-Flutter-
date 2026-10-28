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
      done: fields[1] == null ? false : fields[1] as bool,
      description: fields[2] == null ? '' : fields[2] as String,
      dueDate: fields[3] as DateTime?,
      priority: fields[4] == null ? 'Medium' : fields[4] as String,
      status: fields[5] == null ? 'Not Started' : fields[5] as String,
      category: fields[6] == null ? 'Personal' : fields[6] as String,
      delegatedTo: fields[7] as String?,
      repeatTask: fields[8] == null ? false : fields[8] as bool,
      repeatFrequency: fields[9] as String?,
      urgent: fields[10] == null ? false : fields[10] as bool,
      important: fields[11] == null ? false : fields[11] as bool,
      estimatedMinutes: fields[12] == null ? 0 : fields[12] as int,
      hourSlot: fields[13] as int?,
      colorValue: fields[14] == null ? 4280191205 : fields[14] as int,
      routineEnabled: fields[15] == null ? true : fields[15] as bool,
      id: fields[16] as String?,
      steps: (fields[17] as List?)?.cast<TaskStep>(),
      legacyCloudId: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(19)
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
      ..write(obj.hourSlot)
      ..writeByte(14)
      ..write(obj.colorValue)
      ..writeByte(15)
      ..write(obj.routineEnabled)
      ..writeByte(16)
      ..write(obj.id)
      ..writeByte(17)
      ..write(obj.steps)
      ..writeByte(18)
      ..write(obj.legacyCloudId);
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
