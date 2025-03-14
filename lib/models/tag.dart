import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'tag.g.dart';

@HiveType(typeId: 2)
class Tag extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int color;

  @HiveField(2)
  final String shortcut;

  Tag({
    required this.name,
    required this.color,
    required this.shortcut,
  });

  Color get tagColor => Color(color);
}