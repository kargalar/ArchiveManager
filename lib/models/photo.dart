import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'tag.dart';

part 'photo.g.dart';

// Fotoğraf modelini temsil eder. Hive ile saklanır.
// path: fotoğraf dosya yolu
// isFavorite: favori mi
// rating: puan (0-9)
// isRecycled: geri dönüşümde mi
// tags: etiketler
// width: genişlik (piksel)
// height: yükseklik (piksel)
// dateModified: değiştirilme tarihi
@HiveType(typeId: 0)
class Photo extends HiveObject {
  @HiveField(0)
  String path;

  @HiveField(1)
  bool isFavorite;

  @HiveField(2)
  int rating;

  @HiveField(3)
  bool isRecycled;

  @HiveField(4)
  List<Tag> tags;

  @HiveField(5, defaultValue: 0)
  int width;

  @HiveField(6, defaultValue: 0)
  int height;

  @HiveField(7)
  DateTime? dateModified;

  @HiveField(8, defaultValue: false)
  bool dimensionsLoaded;

  // isSelected is a transient property (not stored in Hive)
  bool isSelected = false;

  Photo({
    required this.path,
    this.isFavorite = false,
    this.rating = 0,
    this.isRecycled = false,
    List<Tag>? tags,
    this.width = 0,
    this.height = 0,
    this.dateModified,
    this.dimensionsLoaded = false,
    this.isSelected = false,
  }) : tags = tags ?? [];

  // Calculate resolution (total pixels)
  int get resolution => width * height;

  void toggleFavorite() {
    isFavorite = !isFavorite;
    try {
      save();
      debugPrint('Photo.toggleFavorite: Favorite toggled to $isFavorite for photo: $path');
    } catch (e) {
      debugPrint('Photo.toggleFavorite ERROR: $e');
    }
  }

  void setRating(int value) {
    if (value >= 0 && value <= 9) {
      rating = value;
      try {
        save();
        debugPrint('Photo.setRating: Rating set to $rating for photo: $path');
      } catch (e) {
        debugPrint('Photo.setRating ERROR: $e');
      }
    } else {
      debugPrint('Photo.setRating: Invalid rating value: $value (must be 0-9)');
    }
  }
}
