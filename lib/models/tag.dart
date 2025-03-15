import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

part 'tag.g.dart';

@HiveType(typeId: 2)
class Tag extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final Color color;

  @HiveField(2)
  final LogicalKeyboardKey shortcutKey;

  Tag({
    required this.name,
    required this.color,
    required this.shortcutKey,
  });
}
