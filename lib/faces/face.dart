import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'face.g.dart';

@HiveType(typeId: 7)
class Face {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Rect boundingBox;

  @HiveField(2)
  final double? smileProbability;

  @HiveField(3)
  final double? leftEyeOpenProbability;

  @HiveField(4)
  final double? rightEyeOpenProbability;

  @HiveField(5)
  final String? label; // User-assigned name for this face

  Face({
    required this.id,
    required this.boundingBox,
    this.smileProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.label,
  });
}
