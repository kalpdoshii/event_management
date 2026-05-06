// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 0;

  @override
  Event read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return Event(
      id: fields[0] as String,
      name: fields[1] as String,
      dateTime: fields[2] as DateTime,
      maxCapacity: fields[3] as int,
      checkedIn: fields[4] as bool,
      checkedInAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dateTime)
      ..writeByte(3)
      ..write(obj.maxCapacity)
      ..writeByte(4)
      ..write(obj.checkedIn)
      ..writeByte(5)
      ..write(obj.checkedInAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
