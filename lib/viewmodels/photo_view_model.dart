import 'dart:io';
import 'package:archive_manager_v3/main.dart';
import 'package:archive_manager_v3/models/settings.dart';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:archive_manager_v3/viewmodels/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../models/folder.dart';
import '../models/sort_state.dart';

class PhotoViewModel extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final Box<Folder> _folderBox;
  late final Box<Tag> _tagBox;
  late final Box<Settings> _settingsBox;
  Box<Tag> get tagBox => _tagBox;
  final List<String> _folders = [];
  String? _selectedFolder;
  final List<Photo> _photos = [];
  int _photosPerRow = 4; // Default value
  final Map<String, List<String>> _folderHierarchy = {};
  final Map<String, bool> _expandedFolders = {};

  PhotoViewModel(this._photoBox, this._folderBox) {
    _loadFolders();
    _initTagBox();
    _initSettingsBox();
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
    final parentPath = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
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

  Future<void> _initTagBox() async {
    _tagBox = await Hive.openBox<Tag>('tags');
  }

  Future<void> addTag(Tag tag) async {
    await _tagBox.add(tag);
    notifyListeners();
  }

  Future<void> updateTagName(Tag tag, String newName) async {
    if (tag.name != newName) {
      tag.name = newName;
      await tag.save();
      notifyListeners();
    }
  }

  Future<void> deleteTag(Tag tag) async {
    // Remove tag from all photos that have it
    for (var photo in _photoBox.values) {
      if (photo.tags.contains(tag)) {
        photo.tags.remove(tag);
        photo.save();
      }
    }
    // Delete the tag itself
    await tag.delete();
    notifyListeners();
  }

  List<Tag> get tags => _tagBox.values.toList();

  Future<void> _initSettingsBox() async {
    _settingsBox = await Hive.openBox<Settings>('settings');
    if (_settingsBox.isEmpty) {
      await _settingsBox.add(Settings());
    }
    _photosPerRow = _settingsBox.getAt(0)?.photosPerRow ?? 4;
    notifyListeners();
  }

  bool get showImageInfo => _settingsBox.getAt(0)?.showImageInfo ?? true;

  bool get fullscreenAutoNext => _settingsBox.getAt(0)?.fullscreenAutoNext ?? false;

  void setShowImageInfo(bool value) {
    _settingsBox.getAt(0)?.showImageInfo = value;
    _settingsBox.getAt(0)?.save();
    notifyListeners();
  }

  void setFullscreenAutoNext(bool value) {
    _settingsBox.getAt(0)?.fullscreenAutoNext = value;
    _settingsBox.getAt(0)?.save();
    notifyListeners();
  }

  void setPhotosPerRow(int value) {
    if (value > 0) {
      _photosPerRow = value;
      _settingsBox.getAt(0)?.photosPerRow = value;
      _settingsBox.getAt(0)?.save();
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
      final photosToRemove = _photoBox.values.where((p) => p.path.startsWith(path));
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
      // Set focus to the first photo if available
      if (_photos.isNotEmpty) {
        Provider.of<HomeViewModel>(navigatorKey.currentContext!, listen: false).setSelectedPhoto(_photos.first);
      } else {
        Provider.of<HomeViewModel>(navigatorKey.currentContext!, listen: false).setSelectedPhoto(null);
      }
    } else {
      _photos.clear();
      Provider.of<HomeViewModel>(navigatorKey.currentContext!, listen: false).setSelectedPhoto(null);
    }
    notifyListeners();
  }

  void _loadPhotosFromFolder(String path) {
    _photos.clear();
    final directory = Directory(path);
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif'];

    try {
      final files = directory.listSync(recursive: true);
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

  void toggleTag(Photo photo, Tag tag) {
    if (photo.tags.contains(tag)) {
      photo.tags.remove(tag);
    } else {
      photo.tags.add(tag);
    }
    photo.save();
    notifyListeners();
  }

  void sortPhotosByRating({bool ascending = false}) {
    _photos.sort((a, b) => ascending ? a.rating.compareTo(b.rating) : b.rating.compareTo(a.rating));
    notifyListeners();
  }

  SortState _dateSortState = SortState.none;
  SortState get dateSortState => _dateSortState;

  SortState _ratingSortState = SortState.none;
  SortState get ratingSortState => _ratingSortState;

  void resetDateSort() {
    _dateSortState = SortState.none;
    _sortPhotos();
    notifyListeners();
  }

  void toggleDateSort() {
    switch (_dateSortState) {
      case SortState.none:
        _dateSortState = SortState.ascending;
        _ratingSortState = SortState.none;
        break;
      case SortState.ascending:
        _dateSortState = SortState.descending;
        _ratingSortState = SortState.none;
        break;
      case SortState.descending:
        _dateSortState = SortState.none;
        break;
    }
    _sortPhotos();
    notifyListeners();
  }

  void resetRatingSort() {
    _ratingSortState = SortState.none;
    _sortPhotos();
    notifyListeners();
  }

  void toggleRatingSort() {
    switch (_ratingSortState) {
      case SortState.none:
        _ratingSortState = SortState.ascending;
        _dateSortState = SortState.none;
        break;
      case SortState.ascending:
        _ratingSortState = SortState.descending;
        _dateSortState = SortState.none;
        break;
      case SortState.descending:
        _ratingSortState = SortState.none;
        break;
    }
    _sortPhotos();
    notifyListeners();
  }

  void _sortPhotos() {
    if (_dateSortState != SortState.none) {
      switch (_dateSortState) {
        case SortState.ascending:
          _photos.sort((a, b) => File(a.path).statSync().modified.compareTo(File(b.path).statSync().modified));
          break;
        case SortState.descending:
          _photos.sort((a, b) => File(b.path).statSync().modified.compareTo(File(a.path).statSync().modified));
          break;
        case SortState.none:
          break;
      }
    } else if (_ratingSortState != SortState.none) {
      switch (_ratingSortState) {
        case SortState.ascending:
          _photos.sort((a, b) => a.rating.compareTo(b.rating));
          break;
        case SortState.descending:
          _photos.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case SortState.none:
          break;
      }
    } else {
      _loadPhotosFromFolder(_selectedFolder!);
    }
  }

  String _filterType = 'all';
  String get filterType => _filterType;

  bool _showFavoritesOnly = false;
  bool get showFavoritesOnly => _showFavoritesOnly;

  bool _showUnratedOnly = false;
  bool get showUnratedOnly => _showUnratedOnly;

  void toggleFavoritesFilter() {
    _showFavoritesOnly = !_showFavoritesOnly;
    if (_showFavoritesOnly) {
      _showUnratedOnly = false;
    }
    notifyListeners();
  }

  void toggleUnratedFilter() {
    _showUnratedOnly = !_showUnratedOnly;
    if (_showUnratedOnly) {
      _showFavoritesOnly = false;
    }
    notifyListeners();
  }

  double _minRatingFilter = 0; // New field for minimum rating
  double _maxRatingFilter = 7; // New field for maximum rating

  double get minRatingFilter => _minRatingFilter;
  double get maxRatingFilter => _maxRatingFilter;

  void setRatingFilter(double min, double max) {
    _minRatingFilter = min;
    _maxRatingFilter = max;
    _showFavoritesOnly = false;
    _showUnratedOnly = false;
    notifyListeners();
  }

  final List<Tag> _selectedTags = [];
  List<Tag> get selectedTags => _selectedTags;

  void toggleTagFilter(Tag tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  void clearTagFilters() {
    _selectedTags.clear();
    notifyListeners();
  }

  List<Photo> get filteredPhotos {
    var filtered = photos;

    if (_showFavoritesOnly) {
      filtered = filtered.where((photo) => photo.isFavorite).toList();
    } else if (_showUnratedOnly) {
      filtered = filtered.where((photo) => photo.rating == 0).toList();
    } else if (_minRatingFilter > 0 || _maxRatingFilter < 7) {
      filtered = filtered.where((photo) => photo.rating >= _minRatingFilter && photo.rating <= _maxRatingFilter).toList();
    }

    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((photo) => _selectedTags.every((tag) => photo.tags.contains(tag))).toList();
    }

    return filtered;
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  void deletePhoto(Photo photo) {
    try {
      if (Platform.isWindows) {
        final file = File(photo.path);
        if (file.existsSync()) {
          // Use shell command to move file to recycle bin
          Process.run('powershell', [
            '-command',
            '''
            Add-Type -AssemblyName Microsoft.VisualBasic
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
              '${photo.path.replaceAll('\\', '\\\\')}',
              'OnlyErrorDialogs',
              'SendToRecycleBin'
            )
            '''
          ]);
        }
      }

      // Mark as recycled and save before removing from list
      photo.isRecycled = true;
      photo.save();

      // Remove from photos list if it exists
      if (_photos.contains(photo)) {
        _photos.remove(photo);
      }

      // Also remove from box to ensure persistence
      final box = Hive.box<Photo>('photos');
      final boxPhoto = box.values.firstWhere(
        (p) => p.path == photo.path,
        orElse: () => photo,
      );
      boxPhoto.isRecycled = true;
      boxPhoto.save();

      notifyListeners();
    } catch (e) {
      debugPrint('Error moving photo to recycle bin: $e');
    }
  }

  void restorePhoto(Photo photo) {
    try {
      photo.isRecycled = false;
      photo.save();
      if (_selectedFolder != null && photo.path.startsWith(_selectedFolder!)) {
        _photos.add(photo);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring photo: $e');
    }
  }

  void permanentlyDeletePhoto(Photo photo) {
    try {
      final file = File(photo.path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      photo.delete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error permanently deleting photo: $e');
    }
  }
}
