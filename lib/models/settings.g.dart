// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 5;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      photosPerRow: fields[0] as int,
      showImageInfo: fields[1] as bool,
      fullscreenAutoNext: fields[2] as bool,
      dividerPosition: fields[3] as double,
      windowWidth: fields[4] as double?,
      windowHeight: fields[5] as double?,
      windowLeft: fields[6] as double?,
      windowTop: fields[7] as double?,
      isFullscreen: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.photosPerRow)
      ..writeByte(1)
      ..write(obj.showImageInfo)
      ..writeByte(2)
      ..write(obj.fullscreenAutoNext)
      ..writeByte(3)
      ..write(obj.dividerPosition)
      ..writeByte(4)
      ..write(obj.windowWidth)
      ..writeByte(5)
      ..write(obj.windowHeight)
      ..writeByte(6)
      ..write(obj.windowLeft)
      ..writeByte(7)
      ..write(obj.windowTop)
      ..writeByte(8)
      ..write(obj.isFullscreen);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
