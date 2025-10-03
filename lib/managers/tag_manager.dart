import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/photo.dart';
import '../models/tag.dart';
import 'filter_manager.dart';

class TagManager extends ChangeNotifier {
  Box<Tag>? _tagBox;
  final List<Tag> _selectedTags = [];
  FilterManager? _filterManager;

  TagManager() {
    _initTagBox();
  }

  void setFilterManager(FilterManager filterManager) {
    _filterManager = filterManager;
  }

  Box<Tag>? get tagBox => _tagBox;
  List<Tag> get tags => _tagBox?.values.toList() ?? [];
  List<Tag> get selectedTags => _selectedTags;

  // Check if a shortcut key is already in use by another tag
  Tag? getTagByShortcutKey(LogicalKeyboardKey shortcutKey, {String? excludeTagId}) {
    for (var tag in tags) {
      if (tag.shortcutKey == shortcutKey && tag.id != excludeTagId) {
        return tag;
      }
    }
    return null;
  }

  Future<void> _initTagBox() async {
    _tagBox = await Hive.openBox<Tag>('tags');
    notifyListeners();
  }

  Future<void> addTag(Tag tag) async {
    await _tagBox?.add(tag);
    notifyListeners();
  }

  Future<void> updateTag(Tag tag, String newName, Color newColor, LogicalKeyboardKey newShortcutKey) async {
    bool hasChanges = false;

    if (tag.name != newName) {
      tag.name = newName;
      hasChanges = true;
    }

    if (tag.color != newColor) {
      tag.color = newColor;
      hasChanges = true;
    }

    if (tag.shortcutKey != newShortcutKey) {
      tag.shortcutKey = newShortcutKey;
      hasChanges = true;
    }

    if (hasChanges) {
      await tag.save();

      // Update all photos that contain this tag to trigger UI refresh
      final photoBox = Hive.box<Photo>('photos');
      for (var photo in photoBox.values) {
        if (photo.tags.any((t) => t.id == tag.id)) {
          var tagIndex = photo.tags.indexWhere((t) => t.id == tag.id);
          if (tagIndex != -1) {
            photo.tags[tagIndex] = tag;
          }
          await photo.save();
        }
      }

      notifyListeners();
    }
  }

  Future<void> deleteTag(Tag tag) async {
    // Remove tag from all photos that have it
    var photoBox = Hive.box<Photo>('photos');
    for (var photo in photoBox.values) {
      if (photo.tags.any((t) => t.id == tag.id)) {
        photo.tags.removeWhere((t) => t.id == tag.id);
        photo.save();
      }
    }
    // Delete the tag itself
    await tag.delete();
    notifyListeners();
  }

  void toggleTag(Photo photo, Tag tag) {
    try {
      // Ensure tags list is initialized
      // Note: This should not be needed anymore with the constructor change,
      // but keeping it as a safety check

      // Check if photo already has this tag
      if (photo.tags.any((t) => t.id == tag.id)) {
        // Remove tag
        photo.tags.removeWhere((t) => t.id == tag.id);
        debugPrint('Removed tag ${tag.name} from photo ${photo.path}');
      } else {
        // Add tag
        photo.tags.add(tag);
        debugPrint('Added tag ${tag.name} to photo ${photo.path}');
      }

      // Save changes to Hive
      try {
        photo.save();
        debugPrint('Saved photo with updated tags');
      } catch (e) {
        debugPrint('Error saving photo after tag toggle: $e');

        // Try to update the photo in the box directly
        final photoBox = Hive.box<Photo>('photos');
        final boxPhoto = photoBox.values.firstWhere(
          (p) => p.path == photo.path,
          orElse: () => photo,
        );

        if (boxPhoto != photo) {
          // Update the box photo's tags
          boxPhoto.tags = List.from(photo.tags);
          boxPhoto.save();
          debugPrint('Updated tags via box photo instead');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error in toggleTag: $e');
    }
  }

  void toggleTagFilter(Tag tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
      if (_selectedTags.isEmpty && _filterManager != null) {
        _filterManager!.resetTagFilter();
      }
    } else {
      _selectedTags.add(tag);
      if (_filterManager != null) {
        _filterManager!.setTagFilterMode('filtered');
      }
    }
    notifyListeners();
  }

  void clearTagFilters() {
    _selectedTags.clear();
    notifyListeners();
  }

  void removeTagFilter(Tag tag) {
    _selectedTags.remove(tag);
    notifyListeners();
  }
}
