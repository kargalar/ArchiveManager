import 'package:hive/hive.dart';
import 'tag.dart';

part 'photo.g.dart';

// Fotoğraf modelini temsil eder. Hive ile saklanır.
// path: fotoğraf dosya yolu
// isFavorite: favori mi
// rating: puan (0-7)
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

  Photo({
    required this.path,
    this.isFavorite = false,
    this.rating = 0,
    this.isRecycled = false,
    this.tags = const [],
    this.width = 0,
    this.height = 0,
    this.dateModified,
  });

  // Calculate resolution (total pixels)
  int get resolution => width * height;

  void toggleFavorite() {
    isFavorite = !isFavorite;
    save();
  }

  void setRating(int value) {
    if (value >= 0 && value <= 7) {
      rating = value;
      save();
    }
  }
}
