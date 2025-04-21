import 'package:hive/hive.dart';

part 'settings.g.dart';

// Uygulama ayarlarını temsil eden model. Hive ile saklanır.
// photosPerRow: satır başına fotoğraf sayısı
// showImageInfo: fotoğraf bilgisi gösterilsin mi
// fullscreenAutoNext: tam ekranda otomatik geçiş

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
