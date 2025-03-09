import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/photo.dart';
import '../models/folder.dart';
import '../models/tag.dart';

class PhotoViewModel extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final Box<Folder> _folderBox;
  final Box<Tag> _tagBox;
  final List<String> _folders = [];
  String? _selectedFolder;
  List<Photo> _photos = [];
  int _photosPerRow = 4; // Default value
  final Map<String, List<String>> _folderHierarchy = {};
  final Map<String, bool> _expandedFolders = {};
  final Map<String, Tag> _tagShortcuts = {};

  PhotoViewModel(this._photoBox, this._folderBox, this._tagBox) {
    _loadFolders();
    _loadTags();
  }

  void _loadFolders() {
    for (var folder in _folderBox.values) {
      _folders.add(folder.path);
      _addToHierarchy(folder.path);
      for (var subFolder in folder.subFolders) {
        if (!_folders.contains(subFolder)) {
          _folders.add(subFolder);
          _addToHierarchy(subFolder);
        }
      }
    }
  }

  void _addToHierarchy(String path) {
    final parentPath =
        path.substring(0, path.lastIndexOf(Platform.pathSeparator));
    if (_folders.contains(parentPath)) {
      _folderHierarchy.putIfAbsent(parentPath, () => []).add(path);
    }
  }

  List<String> get folders => _folders;
  String? get selectedFolder => _selectedFolder;
  List<Photo> get photos => _photos;
  int get photosPerRow => _photosPerRow;
  Map<String, List<String>> get folderHierarchy => _folderHierarchy;
  Map<String, bool> get expandedFolders => _expandedFolders;

  void setPhotosPerRow(int value) {
    if (value > 0) {
      _photosPerRow = value;
      notifyListeners();
    }
  }

  String getFolderName(String path) => path.split(Platform.pathSeparator).last;

  void toggleFolderExpanded(String path) {
    _expandedFolders[path] = !(_expandedFolders[path] ?? false);
    notifyListeners();
  }

  bool isFolderExpanded(String path) => _expandedFolders[path] ?? false;

  void addFolder(String path) {
    if (!_folders.contains(path)) {
      final folder = Folder(path: path);
      _folderBox.add(folder);
      _folders.add(path);

      // Scan for subfolders
      try {
        final directory = Directory(path);
        final entities = directory.listSync(recursive: true);
        for (var entity in entities) {
          if (entity is Directory) {
            final subPath = entity.path;
            if (!_folders.contains(subPath)) {
              folder.addSubFolder(subPath);
              _folders.add(subPath);
              _addToHierarchy(subPath);
            }
          }
        }
        _addToHierarchy(path);
        selectFolder(path); // Automatically select the newly added folder
      } catch (e) {
        debugPrint('Error scanning directory: $e');
      }
    }
    notifyListeners();
  }

  void removeFolder(String path) {
    if (_folders.contains(path)) {
      // Remove from Hive
      final folder = _folderBox.values.firstWhere((f) => f.path == path);
      folder.delete();

      // Remove from lists and maps
      _folders.remove(path);
      _folderHierarchy.remove(path);
      _expandedFolders.remove(path);

      // Remove associated photos
      final photosToRemove =
          _photoBox.values.where((p) => p.path.startsWith(path));
      for (var photo in photosToRemove) {
        photo.delete();
      }

      if (_selectedFolder == path) {
        selectFolder(null);
      }

      notifyListeners();
    }
  }

  void selectFolder(String? path) {
    _selectedFolder = path;
    if (path != null) {
      _loadPhotosFromFolder(path);
    } else {
      _photos.clear();
    }
    notifyListeners();
  }

  void _loadPhotosFromFolder(String path) {
    _photos.clear();
    final directory = Directory(path);
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif'];

    try {
      final files = directory.listSync();
      for (var file in files) {
        if (file is File) {
          final extension = file.path.toLowerCase().split('.').last;
          if (imageExtensions.contains('.$extension')) {
            final photo = _photoBox.values.firstWhere(
              (p) => p.path == file.path,
              orElse: () => Photo(path: file.path),
            );
            if (!_photoBox.values.contains(photo)) {
              _photoBox.add(photo);
            }
            _photos.add(photo);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading photos: $e');
    }

    notifyListeners();
  }

  void toggleFavorite(Photo photo) {
    photo.toggleFavorite();
    notifyListeners();
  }

  void setRating(Photo photo, int rating) {
    if (photo.rating == rating) {
      photo.setRating(0);
    } else {
      photo.setRating(rating);
    }
    notifyListeners();
  }

  void addTagToPhoto(Photo photo, String tagName) {
    photo.addTag(tagName);
    notifyListeners();
  }

  void removeTagFromPhoto(Photo photo, String tagName) {
    photo.removeTag(tagName);
    notifyListeners();
  }

  void _loadTags() {
    for (var tag in _tagBox.values) {
      _tagShortcuts[tag.shortcut] = tag;
    }
  }

  List<Tag> get tags => _tagBox.values.toList();

  void addTag(String name, Color color, String shortcut) {
    if (!_tagShortcuts.containsKey(shortcut)) {
      final tag = Tag(
        name: name,
        color: color.value,
        shortcut: shortcut,
      );
      _tagBox.add(tag);
      _tagShortcuts[shortcut] = tag;
      notifyListeners();
    }
  }

  void removeTag(Tag tag) {
    _tagShortcuts.remove(tag.shortcut);
    tag.delete();
    notifyListeners();
  }

  void handleKeyEvent(RawKeyEvent event, Photo? selectedPhoto) {
    if (event is RawKeyDownEvent && selectedPhoto != null) {
      final key = event.logicalKey.keyLabel;
      if (key.length == 1) {
        // Check for rating keys (1-5)
        if (RegExp(r'[1-5]').hasMatch(key)) {
          setRating(selectedPhoto, int.parse(key));
        } else {
          // Check for tag shortcuts
          final tag = _tagShortcuts[key];
          if (tag != null) {
            addTagToPhoto(selectedPhoto, tag.name);
          }
        }
      }
    }
  }
}
