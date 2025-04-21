import 'package:hive/hive.dart';
import 'tag.dart';

part 'photo.g.dart';

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

  Photo({
    required this.path,
    this.isFavorite = false,
    this.rating = 0,
    this.isRecycled = false,
    this.tags = const [],
  });

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
