import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/folder.dart';
import '../models/photo.dart';
import 'photo_manager.dart';

class FolderManager extends ChangeNotifier {
  final Box<Folder> _folderBox;
  final Box<Photo> _photoBox;
  final List<String> _folders = [];
  final Map<String, List<String>> _folderHierarchy = {};
  final Map<String, bool> _expandedFolders = {};
  List<String> _missingFolders = [];
  String? _selectedFolder;
  final List<String> _favoriteFolders = [];
  PhotoManager? _photoManager;

  // Folder filtering
  String _searchQuery = '';
  List<String> _filteredFolders = [];
  List<String> _filteredFavoriteFolders = [];

  // Section visibility flags
  bool _isFavoriteSectionExpanded = true;
  bool _isAllFoldersSectionExpanded = true;

  // Track which section is selected for viewing all photos
  String? _selectedSection;

  FolderManager(this._folderBox, this._photoBox) {
    _loadFolders();
    checkFoldersExistence();
    _updateFilteredFolders();
  }

  void setPhotoManager(PhotoManager photoManager) {
    _photoManager = photoManager;
  }

  // Getters
  List<String> get folders => _folders; // Her zaman tüm klasörleri döndür
  List<String> get filteredFolders => _filteredFolders; // Sadece filtrelenmiş klasörleri döndür
  String? get selectedFolder => _selectedFolder;
  Map<String, List<String>> get folderHierarchy => _folderHierarchy;
  Map<String, bool> get expandedFolders => _expandedFolders;
  List<String> get missingFolders => _missingFolders;
  List<String> get favoriteFolders => _searchQuery.isEmpty ? _favoriteFolders : _filteredFavoriteFolders;
  bool get isFavoriteSectionExpanded => _isFavoriteSectionExpanded;
  bool get isAllFoldersSectionExpanded => _isAllFoldersSectionExpanded;
  String? get selectedSection => _selectedSection;

  // Optimized folder loading
  void _loadFolders() {
    // Create a map for faster lookups
    final Map<String, Folder> folderMap = {};

    // First pass: build the folder map for faster lookups
    for (var folder in _folderBox.values) {
      folderMap[folder.path] = folder;
    }

    // Second pass: process folders and build hierarchy
    for (var folder in _folderBox.values) {
      if (!_folders.contains(folder.path)) {
        _folders.add(folder.path);
        _addToHierarchy(folder.path);
      }

      // Load favorite folders
      if (folder.isFavorite && !_favoriteFolders.contains(folder.path)) {
        _favoriteFolders.add(folder.path);
      }

      // Process subfolders
      for (var subFolder in folder.subFolders) {
        if (!_folders.contains(subFolder)) {
          _folders.add(subFolder);
          _addToHierarchy(subFolder);

          // Check if this subfolder is a favorite using the map (faster)
          final subFolderObj = folderMap[subFolder];
          if (subFolderObj != null && subFolderObj.isFavorite && !_favoriteFolders.contains(subFolder)) {
            _favoriteFolders.add(subFolder);
          }
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

  Future<void> checkFoldersExistence() async {
    _missingFolders = [];
    for (var folderPath in _folders) {
      if (!await Directory(folderPath).exists()) {
        _missingFolders.add(folderPath);
      }
    }
    if (_missingFolders.isNotEmpty) {
      notifyListeners();
    }
  }

  // Check if a folder is a subfolder of any missing folder
  bool isSubfolderOfMissingFolder(String path) {
    String currentPath = path;
    while (currentPath.contains(Platform.pathSeparator)) {
      currentPath = currentPath.substring(0, currentPath.lastIndexOf(Platform.pathSeparator));
      if (_missingFolders.contains(currentPath)) {
        return true;
      }
    }
    return false;
  }

  String getFolderName(String path) => path.split(Platform.pathSeparator).last;

  void toggleFolderExpanded(String path) {
    _expandedFolders[path] = !(_expandedFolders[path] ?? false);
    notifyListeners();
  }

  bool isFolderExpanded(String path) => _expandedFolders[path] ?? false;

  // Optimized folder addition with batching
  Future<void> addFolder(String path) async {
    if (!_folders.contains(path)) {
      final folder = Folder(path: path);
      _folderBox.add(folder);
      _folders.add(path);

      // Notify UI that we're starting to scan
      notifyListeners();

      // Scan for subfolders
      try {
        final directory = Directory(path);
        final List<Directory> subDirectories = [];

        // First pass: collect all subdirectories
        try {
          final entities = directory.listSync(recursive: true);
          for (var entity in entities) {
            if (entity is Directory) {
              subDirectories.add(entity);
            }
          }
        } catch (e) {
          debugPrint('Error listing directory contents: $e');
        }

        // Process subdirectories in batches
        const int batchSize = 50;
        for (int i = 0; i < subDirectories.length; i += batchSize) {
          final int end = (i + batchSize < subDirectories.length) ? i + batchSize : subDirectories.length;
          final batch = subDirectories.sublist(i, end);

          for (var subDir in batch) {
            final subPath = subDir.path;
            if (!_folders.contains(subPath)) {
              folder.addSubFolder(subPath);
              _folders.add(subPath);
              _addToHierarchy(subPath);

              // Create a Folder object for the subfolder
              final subFolder = Folder(path: subPath);
              _folderBox.add(subFolder);
            }
          }

          // Allow UI to update between batches
          if (i + batchSize < subDirectories.length) {
            notifyListeners();
            await Future.delayed(Duration.zero);
          }
        }

        _addToHierarchy(path);
        selectFolder(path); // Automatically select the newly added folder

        // Yeni eklenen klasördeki fotoğrafları otomatik olarak indeksle
        if (_photoManager != null) {
          debugPrint('Starting indexing for newly added folder: $path');
          _photoManager!.indexFolderPhotos(path);
        }
      } catch (e) {
        debugPrint('Error scanning directory: $e');
      }
    }

    notifyListeners();
  }

  Future<void> removeFolder(String path) async {
    // Check if the folder is in any of our lists
    bool folderExists = _folders.contains(path) || _missingFolders.contains(path);
    debugPrint('Removing folder: $path, exists: $folderExists');

    if (folderExists) {
      // First, check if this folder is a subfolder in any other folder
      // We need to do this before deleting the folder from Hive
      List<Folder> parentFolders = [];
      for (var folder in _folderBox.values) {
        if (folder.subFolders.contains(path)) {
          parentFolders.add(folder);
        }
      }

      // Remove from parent folders' subfolder lists
      for (var parentFolder in parentFolders) {
        parentFolder.removeSubFolder(path);
        await parentFolder.save();
        debugPrint('Removed from parent folder: ${parentFolder.path}');
      }

      // Get all subfolders of this folder to delete them too
      List<String> subFoldersToRemove = [];
      if (_folderHierarchy.containsKey(path)) {
        // Make a copy of the subfolders list to avoid modification during iteration
        subFoldersToRemove = List.from(_folderHierarchy[path] ?? []);
        debugPrint('Found ${subFoldersToRemove.length} subfolders to remove');
      }

      // Remove from Hive if it exists
      final folderInBox = _folderBox.values.where((f) => f.path == path).toList();
      if (folderInBox.isNotEmpty) {
        await folderInBox.first.delete();
        debugPrint('Deleted folder from Hive: $path');
      }

      // Remove from lists and maps
      _folders.remove(path);
      _folderHierarchy.remove(path);
      _expandedFolders.remove(path);
      _missingFolders.remove(path); // Also remove from missing folders list
      _favoriteFolders.remove(path); // Remove from favorites list

      // Remove associated photos
      final photosToRemove = _photoBox.values.where((p) => p.path.startsWith(path)).toList();
      for (var photo in photosToRemove) {
        await photo.delete();
      }
      debugPrint('Removed ${photosToRemove.length} photos associated with folder');

      if (_selectedFolder == path) {
        selectFolder(null);
      }

      // Now recursively remove all subfolders
      for (var subFolder in subFoldersToRemove) {
        await removeFolder(subFolder);
      }

      notifyListeners();
      debugPrint('Folder removal complete: $path');
    }
  }

  // Replace an old folder path with a new one
  Future<void> replaceFolder(String oldPath, String newPath) async {
    await Future.delayed(Duration(milliseconds: 10)); // Short delay for UI thread
    if (_folders.contains(oldPath) && !_folders.contains(newPath)) {
      // 1. Update paths for all subfolders
      final subFoldersToUpdate = _folders.where((f) => f == oldPath || f.startsWith(oldPath + Platform.pathSeparator)).toList();
      final Map<String, String> oldToNewMap = {};
      final List<String> nonExistentSubfolders = [];

      // Check each subfolder and create mapping only for those that exist in the new location
      for (var subFolder in subFoldersToUpdate) {
        final newSubFolder = subFolder.replaceFirst(oldPath, newPath);
        oldToNewMap[subFolder] = newSubFolder;

        // For subfolders (not the main folder we're replacing), check if they exist
        if (subFolder != oldPath && !Directory(newSubFolder).existsSync()) {
          nonExistentSubfolders.add(subFolder);
          debugPrint('Subfolder does not exist in new location: $newSubFolder');
        }
      }

      // Remove non-existent subfolders from the mapping
      for (var nonExistentSubfolder in nonExistentSubfolders) {
        oldToNewMap.remove(nonExistentSubfolder);
      }

      // Update _folders list
      _folders.removeWhere((f) => oldToNewMap.keys.contains(f) || nonExistentSubfolders.contains(f));
      _folders.addAll(oldToNewMap.values);

      // Update _folderHierarchy and remove missing subfolders
      final updatedHierarchy = <String, List<String>>{};
      _folderHierarchy.forEach((parent, children) {
        // Skip if this parent folder doesn't exist anymore
        if (nonExistentSubfolders.contains(parent)) return;

        final newParent = oldToNewMap[parent] ?? parent;
        final newChildren = children
            .where((c) => !nonExistentSubfolders.contains(c)) // Filter out non-existent children
            .map((c) => oldToNewMap[c] ?? c)
            .toList();

        updatedHierarchy[newParent] = newChildren;
      });
      _folderHierarchy
        ..clear()
        ..addAll(updatedHierarchy);

      // Update _expandedFolders
      final updatedExpanded = <String, bool>{};
      _expandedFolders.forEach((k, v) {
        // Skip if folder doesn't exist anymore
        if (nonExistentSubfolders.contains(k)) return;

        final newK = oldToNewMap[k] ?? k;
        updatedExpanded[newK] = v;
      });
      _expandedFolders
        ..clear()
        ..addAll(updatedExpanded);

      // Update _missingFolders and remove missing folders
      _missingFolders = _missingFolders
          .where((f) => !nonExistentSubfolders.contains(f)) // Remove non-existent folders
          .map((f) => oldToNewMap[f] ?? f) // Map to new paths
          .toList();

      // Update _favoriteFolders and remove non-existent favorites
      final updatedFavorites = _favoriteFolders
          .where((f) => !nonExistentSubfolders.contains(f)) // Remove non-existent folders
          .map((f) => oldToNewMap[f] ?? f) // Map to new paths
          .toList();
      _favoriteFolders.clear();
      _favoriteFolders.addAll(updatedFavorites);

      // Delete non-existent folders from Hive
      for (var nonExistentSubfolder in nonExistentSubfolders) {
        final folderInBox = _folderBox.values.where((f) => f.path == nonExistentSubfolder).toList();
        if (folderInBox.isNotEmpty) {
          await folderInBox.first.delete();
          debugPrint('Deleted non-existent folder from Hive: $nonExistentSubfolder');
        }

        // Remove associated photos
        final photosToRemove = _photoBox.values.where((p) => p.path.startsWith(nonExistentSubfolder)).toList();
        for (var photo in photosToRemove) {
          await photo.delete();
        }
        debugPrint('Removed ${photosToRemove.length} photos associated with non-existent folder');
      }

      // Update Folder objects in Hive (only for existing ones)
      for (var subFolder in subFoldersToUpdate) {
        // Skip if folder doesn't exist in new location
        if (nonExistentSubfolders.contains(subFolder)) continue;

        final folderInBox = _folderBox.values.where((f) => f.path == subFolder).toList();
        if (folderInBox.isNotEmpty) {
          var folderObj = folderInBox.first;
          var updatedFolder = Folder(path: oldToNewMap[subFolder]!);

          // Update subfolder list, removing non-existent ones
          updatedFolder.subFolders.addAll(folderObj.subFolders
              .where((sf) => !nonExistentSubfolders.contains(sf)) // Filter out non-existent ones
              .map((sf) => oldToNewMap[sf] ?? sf));

          await folderObj.delete();
          await _folderBox.add(updatedFolder);
        }
      }

      // Update photo paths (only for existing ones)
      final photosToUpdate = _photoBox.values.where((p) => p.path.startsWith(oldPath) && !nonExistentSubfolders.any((folder) => p.path.startsWith(folder))).toList();

      for (var photo in photosToUpdate) {
        final newPhotoPath = photo.path.replaceFirst(oldPath, newPath);
        photo.path = newPhotoPath;
        await photo.save();
      }

      // Select the new path
      if (_selectedFolder != null && (_selectedFolder == oldPath || _selectedFolder!.startsWith(oldPath + Platform.pathSeparator))) {
        if (nonExistentSubfolders.contains(_selectedFolder)) {
          // If currently selected folder doesn't exist in new path, select the parent folder
          _selectedFolder = newPath;
        } else {
          _selectedFolder = _selectedFolder!.replaceFirst(oldPath, newPath);
        }
      }

      // Scan for subfolders in the new path
      try {
        final directory = Directory(newPath);
        final entities = directory.listSync(recursive: true);
        for (var entity in entities) {
          if (entity is Directory) {
            final subPath = entity.path;
            if (!_folders.contains(subPath)) {
              final parentFolder = _folderBox.values.firstWhere(
                (f) => subPath != newPath && subPath.startsWith(f.path),
                orElse: () => Folder(path: newPath),
              );
              parentFolder.addSubFolder(subPath);
              _folders.add(subPath);
              _addToHierarchy(subPath);
            }
          }
        }
        _addToHierarchy(newPath);
        notifyListeners();
      } catch (e) {
        debugPrint('Error scanning directory: $e');
        notifyListeners();
      }
    }
  }

  void selectFolder(String? path) {
    _selectedFolder = path;
    notifyListeners();
  }

  // Toggle favorite status for a folder
  void toggleFavorite(String path) {
    final folderInBox = _folderBox.values.where((f) => f.path == path).toList();
    if (folderInBox.isNotEmpty) {
      final folder = folderInBox.first;
      folder.isFavorite = !folder.isFavorite;
      folder.save();

      if (folder.isFavorite) {
        if (!_favoriteFolders.contains(path)) {
          _favoriteFolders.add(path);
        }
      } else {
        _favoriteFolders.remove(path);
      }

      notifyListeners();
    }
  }

  // Check if a folder is a favorite
  bool isFavorite(String path) {
    final folderInBox = _folderBox.values.where((f) => f.path == path).toList();
    return folderInBox.isNotEmpty ? folderInBox.first.isFavorite : false;
  }

  // Check if search is active
  bool get isSearchActive => _searchQuery.isNotEmpty;

  // Filter folders based on search query
  void filterFolders(String query) {
    _searchQuery = query.trim().toLowerCase();
    _updateFilteredFolders();
    notifyListeners();
  }

  // Update filtered folder lists based on current search query
  void _updateFilteredFolders() {
    if (_searchQuery.isEmpty) {
      _filteredFolders = List.from(_folders);
      _filteredFavoriteFolders = List.from(_favoriteFolders);
      return;
    }

    // Filter all folders - only include folders that actually contain the search query
    _filteredFolders = _folders.where((path) {
      final folderName = getFolderName(path).toLowerCase();
      return folderName.contains(_searchQuery);
    }).toList();

    // Sort filtered folders by name for better readability
    _filteredFolders.sort((a, b) => getFolderName(a).toLowerCase().compareTo(getFolderName(b).toLowerCase()));

    // Filter favorite folders - only include folders that actually contain the search query
    _filteredFavoriteFolders = _favoriteFolders.where((path) {
      final folderName = getFolderName(path).toLowerCase();
      return folderName.contains(_searchQuery);
    }).toList();

    // Sort filtered favorite folders by name for better readability
    _filteredFavoriteFolders.sort((a, b) => getFolderName(a).toLowerCase().compareTo(getFolderName(b).toLowerCase()));
  }

  // Toggle favorite section expanded state
  void toggleFavoriteSectionExpanded() {
    _isFavoriteSectionExpanded = !_isFavoriteSectionExpanded;
    notifyListeners();
  }

  // Toggle all folders section expanded state
  void toggleAllFoldersSectionExpanded() {
    _isAllFoldersSectionExpanded = !_isAllFoldersSectionExpanded;
    notifyListeners();
  }

  // Select the Favorites section to view all photos from favorite folders
  void selectFavoritesSection() {
    _selectedSection = 'favorites';
    _selectedFolder = null; // Clear the selected folder
    notifyListeners();
  }

  // Select the All Folders section to view all photos from all folders
  void selectAllFoldersSection() {
    _selectedSection = 'all';
    _selectedFolder = null; // Clear the selected folder
    notifyListeners();
  }

  // Clear section selection
  void clearSectionSelection() {
    _selectedSection = null;
    notifyListeners();
  }
}
