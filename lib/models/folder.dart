import 'package:hive/hive.dart';

part 'folder.g.dart';

@HiveType(typeId: 1)
class Folder extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final List<String> subFolders;

  Folder({
    required this.path,
    List<String>? subFolders,
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