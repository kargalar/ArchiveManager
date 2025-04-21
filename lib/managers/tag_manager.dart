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
    if (photo.tags.any((t) => t.id == tag.id)) {
      photo.tags.removeWhere((t) => t.id == tag.id);
    } else {
      photo.tags.add(tag);
    }
    photo.save();
    notifyListeners();
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
