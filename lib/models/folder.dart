import 'package:hive/hive.dart';
import 'tag.dart';

part 'folder.g.dart';

// Folder model stored with Hive
// path: full path of the folder
// subFolders: paths of subfolders
// isFavorite: whether the folder is marked as favorite
// autoTags: tags that are automatically applied to photos in this folder
@HiveType(typeId: 1)
class Folder extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final List<String> subFolders;

  @HiveField(2, defaultValue: false)
  bool isFavorite;

  @HiveField(3, defaultValue: [])
  List<Tag> autoTags;

  Folder({
    required this.path,
    List<String>? subFolders,
    this.isFavorite = false,
    List<Tag>? autoTags,
  })  : subFolders = subFolders ?? [],
        autoTags = autoTags ?? [];

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

  void addAutoTag(Tag tag) {
    if (!autoTags.any((t) => t.id == tag.id)) {
      autoTags.add(tag);
      save();
    }
  }

  void removeAutoTag(Tag tag) {
    autoTags.removeWhere((t) => t.id == tag.id);
    save();
  }

  bool hasAutoTag(Tag tag) {
    return autoTags.any((t) => t.id == tag.id);
  }
}
