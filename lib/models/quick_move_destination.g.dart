// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_move_destination.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuickMoveDestinationAdapter extends TypeAdapter<QuickMoveDestination> {
  @override
  final int typeId = 7;

  @override
  QuickMoveDestination read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuickMoveDestination(
      name: fields[0] as String,
      path: fields[1] as String,
      color: fields[2] as Color,
      shortcutKey: fields[3] as LogicalKeyboardKey,
      id: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, QuickMoveDestination obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.color)
      ..writeByte(3)
      ..write(obj.shortcutKey)
      ..writeByte(4)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickMoveDestinationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
