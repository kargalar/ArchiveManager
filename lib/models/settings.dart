import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 5)
class Settings extends HiveObject {
  @HiveField(0)
  int photosPerRow;

  Settings({this.photosPerRow = 4});
}
