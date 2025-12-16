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

  // Whether the photo has been viewed (clicked or opened fullscreen)
  @HiveField(9, defaultValue: false)
  bool isViewed;

  // User notes for the photo
  @HiveField(10, defaultValue: '')
  String note;

  // Dominant color category analysis for filtering.
  // null: not analyzed yet (backfill will compute)
  // -1: analyzed but unknown/failed
  // >=0: PhotoColorCategory.code
  @HiveField(11)
  int? colorCategoryCode;

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
    this.isViewed = false,
    this.note = '',
    this.colorCategoryCode,
    this.isSelected = false,
  }) : tags = tags ?? [];

  // Calculate resolution (total pixels)
  int get resolution => width * height;

  PhotoColorCategory? get colorCategory => PhotoColorCategory.fromStoredCode(colorCategoryCode);

  bool get isColorAnalyzed => colorCategoryCode != null;

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

  // Mark photo as viewed and persist if changed
  void markViewed() {
    if (!isViewed) {
      isViewed = true;
      try {
        save();
        debugPrint('Photo.markViewed: Marked as viewed for $path');
      } catch (e) {
        debugPrint('Photo.markViewed ERROR: $e');
      }
    }
  }

  // Update photo note
  void updateNote(String newNote) {
    note = newNote;
    try {
      save();
      debugPrint('Photo.updateNote: Note updated for $path');
    } catch (e) {
      debugPrint('Photo.updateNote ERROR: $e');
    }
  }
}

enum PhotoColorCategory {
  red(0),
  orange(1),
  yellow(2),
  green(3),
  blue(4),
  purple(5),
  pink(6),
  brown(7),
  black(8),
  white(9),
  gray(10);

  final int code;
  const PhotoColorCategory(this.code);

  static PhotoColorCategory? fromStoredCode(int? code) {
    if (code == null || code < 0) return null;
    for (final value in PhotoColorCategory.values) {
      if (value.code == code) return value;
    }
    return null;
  }
}
