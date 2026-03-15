import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'quick_move_destination.g.dart';

// Hızlı taşıma hedefi modelini temsil eder. Hive ile saklanır.
// name: hedef adı
// path: hedef klasör yolu
// color: hedef rengi
// shortcutKey: kısayol tuşu
// id: benzersiz kimlik
@HiveType(typeId: 7)
class QuickMoveDestination extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String path;

  @HiveField(2)
  Color color;

  @HiveField(3)
  LogicalKeyboardKey shortcutKey;

  @HiveField(4)
  final String id;

  QuickMoveDestination({
    required this.name,
    required this.path,
    required this.color,
    required this.shortcutKey,
    String? id,
  }) : id = id ?? const Uuid().v4();
}
