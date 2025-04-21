import 'dart:io';
import 'dart:async';
import 'package:archive_manager_v3/main.dart';
import 'package:archive_manager_v3/managers/file_system_watcher.dart';
import 'package:archive_manager_v3/managers/filter_manager.dart';
import 'package:archive_manager_v3/managers/folder_manager.dart';
import 'package:archive_manager_v3/managers/photo_manager.dart';
import 'package:archive_manager_v3/managers/settings_manager.dart';
import 'package:archive_manager_v3/managers/tag_manager.dart';
import 'package:archive_manager_v3/models/photo.dart';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:archive_manager_v3/viewmodels/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../models/folder.dart';
import '../models/sort_state.dart';

class PhotoViewModel extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final Box<Folder> _folderBox;
  String? _selectedFolder;
  final List<Photo> _photos = [];

  // Folder methods delegated to FolderManager
  List<String> get missingFolders => _folderManager.missingFolders;

  // Check if a folder is a subfolder of any missing folder
  bool isSubfolderOfMissingFolder(String path) {
    return _folderManager.isSubfolderOfMissingFolder(path);
  }

  // Managers
  late final SettingsManager _settingsManager;
  late final TagManager _tagManager;
  late final PhotoManager _photoManager;
  late final FilterManager _filterManager;
  late final FileSystemWatcher _fileSystemWatcher;
  late final FolderManager _folderManager;

  PhotoViewModel(this._photoBox, this._folderBox) {
    _loadFolders();
    checkFoldersExistence();
    _initTagBox();
    _initSettingsBox();
    _setupFolderWatchers();

    // Initialize managers
    _folderManager = FolderManager(_folderBox, _photoBox);
    _settingsManager = SettingsManager();
    _tagManager = TagManager();
    _photoManager = PhotoManager(_photoBox);
    _filterManager = FilterManager();
    _fileSystemWatcher = FileSystemWatcher(_folderBox, _folderManager.folders, _folderManager.missingFolders);
  }

  @override
  void dispose() {
    // Dispose all managers
    _fileSystemWatcher.dispose();
    super.dispose();
  }

  // Folder watching methods delegated to FileSystemWatcher
  void _setupFolderWatchers() {
    // This is now handled by FileSystemWatcher
    // Keep this method for backward compatibility
  }

  // Folder methods delegated to FolderManager
  Future<void> checkFoldersExistence() async {
    await _folderManager.checkFoldersExistence();
  }

  void _loadFolders() {
    // This is now handled by FolderManager
    // Keep this method for backward compatibility
  }

  // Folder getters delegated to FolderManager
  List<String> get folders => _folderManager.folders;
  String? get selectedFolder => _folderManager.selectedFolder;
  List<Photo> get photos => _photos.isEmpty ? _photoManager.photos : _photos;
  Map<String, List<String>> get folderHierarchy => _folderManager.folderHierarchy;
  Map<String, bool> get expandedFolders => _folderManager.expandedFolders;

  // Tag methods delegated to TagManager
  Future<void> _initTagBox() async {
    // This is now handled by TagManager
    // Keep this method for backward compatibility
  }

  Future<void> addTag(Tag tag) async {
    await _tagManager.addTag(tag);
  }

  Future<void> updateTag(Tag tag, String newName, Color newColor, LogicalKeyboardKey newShortcutKey) async {
    await _tagManager.updateTag(tag, newName, newColor, newShortcutKey);
  }

  Future<void> deleteTag(Tag tag) async {
    await _tagManager.deleteTag(tag);
  }

  List<Tag> get tags => _tagManager.tags;
  Box<Tag>? get tagBox => _tagManager.tagBox;

  // Settings methods delegated to SettingsManager
  Future<void> _initSettingsBox() async {
    // This is now handled by SettingsManager
    // Keep this method for backward compatibility
  }

  bool get showImageInfo => _settingsManager.showImageInfo;

  bool get fullscreenAutoNext => _settingsManager.fullscreenAutoNext;

  void setShowImageInfo(bool value) {
    _settingsManager.setShowImageInfo(value);
  }

  void setFullscreenAutoNext(bool value) {
    _settingsManager.setFullscreenAutoNext(value);
  }

  void setPhotosPerRow(int value) {
    _settingsManager.setPhotosPerRow(value);
  }

  int get photosPerRow => _settingsManager.photosPerRow;

  // Folder operations delegated to FolderManager
  String getFolderName(String path) => _folderManager.getFolderName(path);

  void toggleFolderExpanded(String path) {
    _folderManager.toggleFolderExpanded(path);
  }

  bool isFolderExpanded(String path) => _folderManager.isFolderExpanded(path);

  void addFolder(String path) {
    _folderManager.addFolder(path);
    selectFolder(path); // Automatically select the newly added folder
  }

  Future<void> removeFolder(String path) async {
    await _folderManager.removeFolder(path);
    if (_selectedFolder == path) {
      selectFolder(null);
    }
  }

  // Replace an old folder path with a new one
  Future<void> replaceFolder(String oldPath, String newPath) async {
    await _folderManager.replaceFolder(oldPath, newPath);

    // Update selected folder if needed
    if (_selectedFolder != null && (_selectedFolder == oldPath || _selectedFolder!.startsWith(oldPath + Platform.pathSeparator))) {
      if (_folderManager.folders.contains(_selectedFolder!.replaceFirst(oldPath, newPath))) {
        selectFolder(_selectedFolder!.replaceFirst(oldPath, newPath));
      } else {
        selectFolder(newPath);
      }
    }
  }

  void selectFolder(String? path) {
    _folderManager.selectFolder(path);
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
    _photoManager.loadPhotosFromFolder(path);
    _photos.addAll(_photoManager.photos);
    notifyListeners();
  }

  void toggleFavorite(Photo photo) {
    _photoManager.toggleFavorite(photo);
  }

  void setRating(Photo photo, int rating) {
    _photoManager.setRating(photo, rating);
  }

  void toggleTag(Photo photo, Tag tag) {
    _tagManager.toggleTag(photo, tag);
  }

  void sortPhotosByRating({bool ascending = false}) {
    _photos.sort((a, b) => ascending ? a.rating.compareTo(b.rating) : b.rating.compareTo(a.rating));
    notifyListeners();
  }

  // Sorting methods delegated to FilterManager
  SortState get dateSortState => _filterManager.dateSortState;
  SortState get ratingSortState => _filterManager.ratingSortState;

  void resetDateSort() {
    _filterManager.resetDateSort();
    _sortPhotos();
  }

  void toggleDateSort() {
    _filterManager.toggleDateSort();
    _sortPhotos();
  }

  void resetRatingSort() {
    _filterManager.resetRatingSort();
    _sortPhotos();
  }

  void toggleRatingSort() {
    _filterManager.toggleRatingSort();
    _sortPhotos();
  }

  void _sortPhotos() {
    if (_filterManager.dateSortState != SortState.none || _filterManager.ratingSortState != SortState.none) {
      _filterManager.sortPhotos(_photos);
      notifyListeners();
    } else if (_selectedFolder != null) {
      _loadPhotosFromFolder(_selectedFolder!);
    }
  }

  // Filter methods delegated to FilterManager
  String get filterType => _filterManager.filterType;
  String get favoriteFilterMode => _filterManager.favoriteFilterMode;
  bool get showUntaggedOnly => _filterManager.showUntaggedOnly;
  String get tagFilterMode => _filterManager.tagFilterMode;

  void toggleTagFilterMode() {
    if (_tagManager.selectedTags.isNotEmpty) {
      _filterManager.setTagFilterMode('filtered');
    } else {
      _filterManager.toggleTagFilterMode();
    }
    notifyListeners();
  }

  void toggleFavoritesFilter() {
    _filterManager.toggleFavoritesFilter();
    notifyListeners();
  }

  void resetFavoriteFilter() {
    _filterManager.resetFavoriteFilter();
    notifyListeners();
  }

  void resetTagFilter() {
    _filterManager.resetTagFilter();
    _tagManager.clearTagFilters();
    notifyListeners();
  }

  void toggleUntaggedFilter() {
    _filterManager.toggleUntaggedFilter();
    notifyListeners();
  }

  double get minRatingFilter => _filterManager.minRatingFilter;
  double get maxRatingFilter => _filterManager.maxRatingFilter;

  void setRatingFilter(double min, double max) {
    _filterManager.setRatingFilter(min, max);
    notifyListeners();
  }

  List<Tag> get selectedTags => _tagManager.selectedTags;

  void toggleTagFilter(Tag tag) {
    _tagManager.toggleTagFilter(tag);
    if (_tagManager.selectedTags.isEmpty) {
      _filterManager.setTagFilterMode('none');
    } else {
      _filterManager.setTagFilterMode('filtered');
    }
    notifyListeners();
  }

  void clearTagFilters() {
    _tagManager.clearTagFilters();
    _filterManager.setTagFilterMode('none');
    notifyListeners();
  }

  void removeTagFilter(Tag tag) {
    _tagManager.removeTagFilter(tag);
    if (_tagManager.selectedTags.isEmpty) {
      _filterManager.setTagFilterMode('none');
    }
    notifyListeners();
  }

  List<Photo> get filteredPhotos {
    return _filterManager.filterPhotos(_photos, _tagManager.selectedTags);
  }

  void setFilterType(String type) {
    _filterManager.setFilterType(type);
    notifyListeners();
  }

  void deletePhoto(Photo photo) {
    _photoManager.deletePhoto(photo);
  }

  void restorePhoto(Photo photo) {
    _photoManager.restorePhoto(photo);
    if (_selectedFolder != null && photo.path.startsWith(_selectedFolder!)) {
      _photos.add(photo);
      notifyListeners();
    }
  }

  void permanentlyDeletePhoto(Photo photo) {
    _photoManager.permanentlyDeletePhoto(photo);
  }
}
