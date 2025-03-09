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

  @HiveField(3)
  List<String> tags;

  Photo({
    required this.path,
    this.isFavorite = false,
    this.rating = 0,
    List<String>? tags,
  }) : tags = tags ?? [];

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

  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
      save();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    save();
  }
}