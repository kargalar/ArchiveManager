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

      // Update all photos that contain this tag to trigger UI refresh
      for (var photo in _photoBox.values) {
        if (photo.tags.any((t) => t.id == tag.id)) {
          // Force refresh the tag reference in the photo's tags list
          var tagIndex = photo.tags.indexWhere((t) => t.id == tag.id);
          if (tagIndex != -1) {
            // Replace with the updated tag to ensure UI updates
            photo.tags[tagIndex] = tag;
          }
          await photo.save(); // Save to persist updates
        }
      }

      // Notify listeners to update the UI
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

  List<Tag> get tags => _tagBox.values.toList();

  Future<void> _initSettingsBox() async {
    _settingsBox = await Hive.openBox<Settings>('settings');
    if (_settingsBox.isEmpty) {
      await _settingsBox.add(Settings());
    }
    _photosPerRow = _settingsBox.getAt(0)?.photosPerRow ?? 4;
    notifyListeners();
  }

  bool get showImageInfo => _settingsBox.getAt(0)?.showImageInfo ?? false;

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
    if (photo.tags.any((t) => t.id == tag.id)) {
      photo.tags.removeWhere((t) => t.id == tag.id);
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

  String _favoriteFilterMode = 'none'; // none, favorites, non-favorites
  String get favoriteFilterMode => _favoriteFilterMode;

  bool _showUntaggedOnly = false;
  bool get showUntaggedOnly => _showUntaggedOnly;

  String _tagFilterMode = 'none'; // none, untagged, tagged, filtered
  String get tagFilterMode => _tagFilterMode;

  void toggleTagFilterMode() {
    switch (_tagFilterMode) {
      case 'none':
        if (_selectedTags.isNotEmpty) {
          _tagFilterMode = 'filtered';
        } else {
          _tagFilterMode = 'untagged';
        }
        break;
      case 'untagged':
        _tagFilterMode = 'tagged';
        break;
      case 'tagged':
        _tagFilterMode = 'none';
        break;
      case 'filtered':
        _tagFilterMode = 'none';
        _selectedTags.clear();
        break;
    }
    notifyListeners();
  }

  void toggleFavoritesFilter() {
    switch (_favoriteFilterMode) {
      case 'none':
        _favoriteFilterMode = 'favorites';
        break;
      case 'favorites':
        _favoriteFilterMode = 'non-favorites';
        break;
      case 'non-favorites':
        _favoriteFilterMode = 'none';
        break;
    }
    notifyListeners();
  }

  void resetFavoriteFilter() {
    _favoriteFilterMode = 'none';
    notifyListeners();
  }

  void resetTagFilter() {
    _tagFilterMode = 'none';
    _selectedTags.clear();
    notifyListeners();
  }

  void toggleUntaggedFilter() {
    _showUntaggedOnly = !_showUntaggedOnly;
    if (_showUntaggedOnly) {
      _favoriteFilterMode = 'none';
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
    notifyListeners();
  }

  final List<Tag> _selectedTags = [];
  List<Tag> get selectedTags => _selectedTags;

  void toggleTagFilter(Tag tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
      if (_selectedTags.isEmpty) {
        _tagFilterMode = 'none';
      }
    } else {
      _selectedTags.add(tag);
      _tagFilterMode = 'filtered';
    }
    notifyListeners();
  }

  void clearTagFilters() {
    _selectedTags.clear();
    notifyListeners();
  }

  void removeTagFilter(Tag tag) {
    _selectedTags.remove(tag);
    if (_selectedTags.isEmpty) {
      _tagFilterMode = 'none';
    }
    notifyListeners();
  }

  List<Photo> get filteredPhotos {
    var filtered = _photos.where((photo) {
      // Handle favorite filter modes
      switch (_favoriteFilterMode) {
        case 'favorites':
          if (!photo.isFavorite) return false;
          break;
        case 'non-favorites':
          if (photo.isFavorite) return false;
          break;
      }

      // Handle different tag filter modes
      switch (_tagFilterMode) {
        case 'untagged':
          if (photo.tags.isNotEmpty) return false;
          break;
        case 'tagged':
          if (photo.tags.isEmpty) return false;
          break;
        case 'filtered':
          if (_selectedTags.isNotEmpty && !_selectedTags.every((tag) => photo.tags.any((photoTag) => photoTag.id == tag.id))) return false;
          break;
      }

      if (photo.rating < _minRatingFilter || photo.rating > _maxRatingFilter) return false;
      return true;
    }).toList();
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
