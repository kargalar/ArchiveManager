import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

part 'tag.g.dart';

@HiveType(typeId: 2)
class Tag extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  int get colorValue => color.value;
  set colorValue(int value) => color = Color(value);

  @HiveField(2)
  int get shortcutKeyId => shortcutKey.keyId;
  set shortcutKeyId(int value) => shortcutKey = LogicalKeyboardKey(value);

  Color color;
  LogicalKeyboardKey shortcutKey;

  Tag({
    required this.name,
    required this.color,
    required this.shortcutKey,
  });
}
