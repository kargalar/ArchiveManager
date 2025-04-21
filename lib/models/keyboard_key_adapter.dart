import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

// Hive için LogicalKeyboardKey tipini saklamaya yarayan adapter
// Kısayol tuşlarının Hive ile kaydedilmesi için gereklidir.
class LogicalKeyboardKeyAdapter extends TypeAdapter<LogicalKeyboardKey> {
  @override
  final int typeId = 4;

  @override
  LogicalKeyboardKey read(BinaryReader reader) {
    final keyCode = reader.readInt();
    return LogicalKeyboardKey(keyCode);
  }

  @override
  void write(BinaryWriter writer, LogicalKeyboardKey obj) {
    writer.writeInt(obj.keyId);
  }
}
