// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'participant.dart';

class ParticipantAdapter extends TypeAdapter<Participant> {
  @override
  final int typeId = 1;

  @override
  Participant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return Participant(
      id: fields[0] as String,
      name: fields[1] as String,
      eventId: fields[2] as String,
      isCheckedIn: fields[3] as bool,
      checkInTime: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Participant obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.eventId)
      ..writeByte(3)
      ..write(obj.isCheckedIn)
      ..writeByte(4)
      ..write(obj.checkInTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParticipantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
