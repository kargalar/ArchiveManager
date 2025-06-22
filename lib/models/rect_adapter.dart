import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

// Hive için Rect tipini saklamaya yarayan adapter
class RectAdapter extends TypeAdapter<Rect> {
  @override
  final int typeId = 8;

  @override
  Rect read(BinaryReader reader) {
    final left = reader.readDouble();
    final top = reader.readDouble();
    final right = reader.readDouble();
    final bottom = reader.readDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  void write(BinaryWriter writer, Rect obj) {
    writer.writeDouble(obj.left);
    writer.writeDouble(obj.top);
    writer.writeDouble(obj.right);
    writer.writeDouble(obj.bottom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RectAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
