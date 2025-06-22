import 'package:archive_manager_v3/faces/face.dart';
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

  @HiveField(9, defaultValue: false)
  bool faceDetectionDone;

  // isSelected is a transient property (not stored in Hive)
  bool isSelected = false;
  @HiveField(10)
  List<Face> faces = [];

  @HiveField(11, defaultValue: <int>[])
  List<int> faceTrackingIds = [];

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
    this.faceDetectionDone = false,
    List<Face>? faces,
    List<int>? faceTrackingIds,
  })  : tags = tags ?? [],
        faces = faces ?? [],
        faceTrackingIds = faceTrackingIds ?? [];

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

  void addFace(Face face) {
    faces.add(face);
    try {
      save();
      debugPrint('Photo.addFace: Face added with ID ${face.id} for photo: $path');
    } catch (e) {
      debugPrint('Photo.addFace ERROR: $e');
    }
  }

  void addFaceTrackingId(int trackingId) {
    if (!faceTrackingIds.contains(trackingId)) {
      faceTrackingIds.add(trackingId);
      try {
        save();
        debugPrint('Photo.addFaceTrackingId: Tracking ID $trackingId added for photo: $path');
      } catch (e) {
        debugPrint('Photo.addFaceTrackingId ERROR: $e');
      }
    }
  }

  void clearFaceTrackingIds() {
    faceTrackingIds.clear();
    try {
      save();
      debugPrint('Photo.clearFaceTrackingIds: All tracking IDs cleared for photo: $path');
    } catch (e) {
      debugPrint('Photo.clearFaceTrackingIds ERROR: $e');
    }
  }
}
