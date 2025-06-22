import 'package:hive/hive.dart';

part 'folder.g.dart';

// Folder model stored with Hive
// path: full path of the folder
// subFolders: paths of subfolders
// isFavorite: whether the folder is marked as favorite
@HiveType(typeId: 1)
class Folder extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final List<String> subFolders;

  @HiveField(2, defaultValue: false)
  bool isFavorite;

  @HiveField(3, defaultValue: false)
  bool faceDetectionEnabled;

  Folder({
    required this.path,
    List<String>? subFolders,
    this.isFavorite = false,
    this.faceDetectionEnabled = false,
  }) : subFolders = subFolders ?? [];

  void addSubFolder(String path) {
    if (!subFolders.contains(path)) {
      subFolders.add(path);
      save();
    }
  }

  void removeSubFolder(String path) {
    subFolders.remove(path);
    save();
  }
}
