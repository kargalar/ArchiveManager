import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import '../models/photo.dart';
import '../models/folder.dart';

class PhotoViewModel extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final Box<Folder> _folderBox;
  final List<String> _folders = [];
  final Map<String, List<String>> _folderHierarchy = {};
  String? _selectedFolder;
  List<Photo> _photos = [];
  Map<String, bool> _expandedFolders = {};

  PhotoViewModel(this._photoBox) : _folderBox = Hive.box<Folder>('folders') {
    _loadSavedFolders();
  }

  void _loadSavedFolders() {
    for (var folder in _folderBox.values) {
      _addToHierarchy(folder.path);
      for (var subFolder in folder.subFolders) {
        if (!_folders.contains(subFolder)) {
          _addToHierarchy(subFolder);
        }
      }
    }
    notifyListeners();
  }

  void _addToHierarchy(String folderPath) {
    if (!_folders.contains(folderPath)) {
      _folders.add(folderPath);
      _expandedFolders[folderPath] = false;

      final parentPath = path.dirname(folderPath);
      if (_folders.contains(parentPath)) {
        _folderHierarchy.putIfAbsent(parentPath, () => []).add(folderPath);
      } else {
        _folderHierarchy[folderPath] = [];
      }
    }
  }

  List<String> get folders => _folders;
  String? get selectedFolder => _selectedFolder;
  List<Photo> get photos => _photos;
  Map<String, List<String>> get folderHierarchy => _folderHierarchy;
  Map<String, bool> get expandedFolders => _expandedFolders;

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
      
      // Scan for subfolders
      try {
        final directory = Directory(path);
        final entities = directory.listSync(recursive: true);
        for (var entity in entities) {
          if (entity is Directory) {
            final subPath = entity.path;
            if (!_folders.contains(subPath)) {
              folder.addSubFolder(subPath);
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
    photo.setRating(rating);
    notifyListeners();
  }

  void addTag(Photo photo, String tag) {
    photo.addTag(tag);
    notifyListeners();
  }

  void removeTag(Photo photo, String tag) {
    photo.removeTag(tag);
    notifyListeners();
  }

  void handleKeyEvent(RawKeyEvent event, Photo? selectedPhoto) {
    if (event is RawKeyDownEvent && selectedPhoto != null) {
      final key = event.logicalKey.keyLabel;
      if (key.length == 1 && RegExp(r'[1-5]').hasMatch(key)) {
        setRating(selectedPhoto, int.parse(key));
      }
    }
  }
}
