import 'package:hive/hive.dart';

part 'photo.g.dart';

@HiveType(typeId: 0)
class Photo extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  bool isFavorite;

  @HiveField(2)
  int rating;

  Photo({
    required this.path,
    this.isFavorite = false,
    this.rating = 0,
  });

  void toggleFavorite() {
    isFavorite = !isFavorite;
    save();
  }

  void setRating(int value) {
    if (value >= 0 && value <= 5) {
      rating = value;
      save();
    }
  }
}
