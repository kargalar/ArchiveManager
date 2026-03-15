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
      folderMenuWidth: fields[9] == null ? 250 : fields[9] as double,
      showNotes: fields[10] == null ? false : fields[10] as bool,
      fullscreenZenMode: fields[11] == null ? false : fields[11] as bool,
      itemSize: fields[12] == null ? 200.0 : fields[12] as double,
      gridAspectMode: fields[13] == null
          ? GridAspectMode.square
          : fields[13] as GridAspectMode,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.isFullscreen)
      ..writeByte(9)
      ..write(obj.folderMenuWidth)
      ..writeByte(10)
      ..write(obj.showNotes)
      ..writeByte(11)
      ..write(obj.fullscreenZenMode)
      ..writeByte(12)
      ..write(obj.itemSize)
      ..writeByte(13)
      ..write(obj.gridAspectMode);
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

class GridAspectModeAdapter extends TypeAdapter<GridAspectMode> {
  @override
  final int typeId = 6;

  @override
  GridAspectMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GridAspectMode.square;
      case 1:
        return GridAspectMode.portrait;
      case 2:
        return GridAspectMode.landscape;
      case 3:
        return GridAspectMode.wide;
      case 4:
        return GridAspectMode.video;
      case 5:
        return GridAspectMode.original;
      default:
        return GridAspectMode.square;
    }
  }

  @override
  void write(BinaryWriter writer, GridAspectMode obj) {
    switch (obj) {
      case GridAspectMode.square:
        writer.writeByte(0);
        break;
      case GridAspectMode.portrait:
        writer.writeByte(1);
        break;
      case GridAspectMode.landscape:
        writer.writeByte(2);
        break;
      case GridAspectMode.wide:
        writer.writeByte(3);
        break;
      case GridAspectMode.video:
        writer.writeByte(4);
        break;
      case GridAspectMode.original:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridAspectModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
