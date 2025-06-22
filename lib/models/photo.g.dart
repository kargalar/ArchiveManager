// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoAdapter extends TypeAdapter<Photo> {
  @override
  final int typeId = 0;

  @override
  Photo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Photo(
      path: fields[0] as String,
      isFavorite: fields[1] as bool,
      rating: fields[2] as int,
      isRecycled: fields[3] as bool,
      tags: (fields[4] as List?)?.cast<Tag>(),
      width: fields[5] == null ? 0 : fields[5] as int,
      height: fields[6] == null ? 0 : fields[6] as int,
      dateModified: fields[7] as DateTime?,
      dimensionsLoaded: fields[8] == null ? false : fields[8] as bool,
      faceDetectionDone: fields[9] == null ? false : fields[9] as bool,
      faces: (fields[10] as List?)?.cast<Face>(),
      faceTrackingIds:
          fields[11] == null ? [] : (fields[11] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, Photo obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.isFavorite)
      ..writeByte(2)
      ..write(obj.rating)
      ..writeByte(3)
      ..write(obj.isRecycled)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.width)
      ..writeByte(6)
      ..write(obj.height)
      ..writeByte(7)
      ..write(obj.dateModified)
      ..writeByte(8)
      ..write(obj.dimensionsLoaded)
      ..writeByte(9)
      ..write(obj.faceDetectionDone)
      ..writeByte(10)
      ..write(obj.faces)
      ..writeByte(11)
      ..write(obj.faceTrackingIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
