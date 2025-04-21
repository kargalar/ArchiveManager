import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

// Hive için Color (renk) tipini saklamaya yarayan adapter
// Uygulama genelinde renklerin Hive ile kaydedilmesi için gereklidir.
class ColorAdapter extends TypeAdapter<Color> {
  @override
  final int typeId = 3;

  @override
  Color read(BinaryReader reader) {
    final colorValue = reader.readInt();
    return Color(colorValue);
  }

  @override
  void write(BinaryWriter writer, Color obj) {
    writer.writeInt(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ColorAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
