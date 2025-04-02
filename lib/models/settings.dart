import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 5)
class Settings extends HiveObject {
  @HiveField(0)
  int photosPerRow;

  @HiveField(1)
  bool showImageInfo;

  @HiveField(2)
  bool fullscreenAutoNext;

  Settings({
    this.photosPerRow = 4,
    this.showImageInfo = true,
    this.fullscreenAutoNext = false,
  });
}
