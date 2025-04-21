import 'package:hive/hive.dart';

part 'settings.g.dart';

// Uygulama ayarlarını temsil eden model. Hive ile saklanır.
// photosPerRow: satır başına fotoğraf sayısı
// showImageInfo: fotoğraf bilgisi gösterilsin mi
// fullscreenAutoNext: tam ekranda otomatik geçiş
// dividerPosition: ana ekrandaki bölünmüş görünümün konumu
// windowWidth: pencere genişliği
// windowHeight: pencere yüksekliği
// windowLeft: pencere sol konumu
// windowTop: pencere üst konumu

@HiveType(typeId: 5)
class Settings extends HiveObject {
  @HiveField(0)
  int photosPerRow;

  @HiveField(1)
  bool showImageInfo;

  @HiveField(2)
  bool fullscreenAutoNext;

  @HiveField(3)
  double dividerPosition;

  @HiveField(4)
  double? windowWidth;

  @HiveField(5)
  double? windowHeight;

  @HiveField(6)
  double? windowLeft;

  @HiveField(7)
  double? windowTop;

  Settings({
    this.photosPerRow = 4,
    this.showImageInfo = true,
    this.fullscreenAutoNext = false,
    this.dividerPosition = 0.3,
    this.windowWidth,
    this.windowHeight,
    this.windowLeft,
    this.windowTop,
  });
}
