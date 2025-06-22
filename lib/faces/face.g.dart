// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'face.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FaceAdapter extends TypeAdapter<Face> {
  @override
  final int typeId = 7;

  @override
  Face read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Face(
      id: fields[0] as String,
      boundingBox: fields[1] as Rect,
      smileProbability: fields[2] as double?,
      leftEyeOpenProbability: fields[3] as double?,
      rightEyeOpenProbability: fields[4] as double?,
      label: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Face obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.boundingBox)
      ..writeByte(2)
      ..write(obj.smileProbability)
      ..writeByte(3)
      ..write(obj.leftEyeOpenProbability)
      ..writeByte(4)
      ..write(obj.rightEyeOpenProbability)
      ..writeByte(5)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
