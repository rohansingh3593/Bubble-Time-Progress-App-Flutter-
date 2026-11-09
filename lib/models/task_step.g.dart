// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_step.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskStepAdapter extends TypeAdapter<TaskStep> {
  @override
  final int typeId = 1;

  @override
  TaskStep read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskStep(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] == null ? '' : fields[2] as String,
      status: fields[3] == null ? 'Not Started' : fields[3] as String,
      minutes: fields[4] == null ? 15 : fields[4] as int,
      urgent: fields[5] == null ? false : fields[5] as bool,
      important: fields[6] == null ? false : fields[6] as bool,
      actualMinutes: fields[7] as int?,
      completedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskStep obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.minutes)
      ..writeByte(5)
      ..write(obj.urgent)
      ..writeByte(6)
      ..write(obj.important)
      ..writeByte(7)
      ..write(obj.actualMinutes)
      ..writeByte(8)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
