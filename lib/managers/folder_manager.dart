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
    _scanForNewSubfolders(); // Yeni alt klasörleri tara
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
    debugPrint('Loading folders from Hive...');

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

    debugPrint('Loaded ${_folders.length} folders from Hive');
  }

  void _addToHierarchy(String path) {
    final parentPath = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
    if (_folders.contains(parentPath)) {
      _folderHierarchy.putIfAbsent(parentPath, () => []).add(path);
    }
  }

  // Rebuild the folder hierarchy from current folders list
  void _rebuildHierarchy() {
    debugPrint('Rebuilding folder hierarchy...');
    _folderHierarchy.clear();

    // Rebuild hierarchy for all remaining folders
    for (String folderPath in _folders) {
      _addToHierarchy(folderPath);
    }

    debugPrint('Folder hierarchy rebuilt. Hierarchy map size: ${_folderHierarchy.length}');
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

        // Update filtered folders after adding
        _updateFilteredFolders();

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

    // Final update of filtered folders and UI notification
    _updateFilteredFolders();
    notifyListeners();
  }

  // Legacy method - now just calls removeFolderFromList for backward compatibility
  Future<void> removeFolder(String path) async {
    await removeFolderFromList(path);
  }

  // Remove folder from list only (without deleting from file system)
  Future<void> removeFolderFromList(String path) async {
    // Check if the folder is in any of our lists
    bool folderExists = _folders.contains(path) || _missingFolders.contains(path);
    debugPrint('Removing folder from list: $path, exists: $folderExists');

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

      // Get all subfolders of this folder to remove them too
      List<String> subFoldersToRemove = [];
      if (_folderHierarchy.containsKey(path)) {
        // Make a copy of the subfolders list to avoid modification during iteration
        subFoldersToRemove = List.from(_folderHierarchy[path] ?? []);
        debugPrint('Found ${subFoldersToRemove.length} subfolders to remove from list');
      }

      // Remove from Hive if it exists
      final folderInBox = _folderBox.values.where((f) => f.path == path).toList();
      if (folderInBox.isNotEmpty) {
        await folderInBox.first.delete();
        debugPrint('Deleted folder from Hive: $path');
      } // Remove from lists and maps
      _folders.remove(path);
      _folderHierarchy.remove(path);
      _expandedFolders.remove(path);
      _missingFolders.remove(path); // Also remove from missing folders list
      _favoriteFolders.remove(path); // Remove from favorites list

      // Remove this folder from any parent's children list in the hierarchy
      // Need to use a safer approach to avoid concurrent modification
      final hierarchyKeysToUpdate = <String>[];
      _folderHierarchy.forEach((parent, children) {
        if (children.contains(path)) {
          hierarchyKeysToUpdate.add(parent);
        }
      });

      for (String parentKey in hierarchyKeysToUpdate) {
        _folderHierarchy[parentKey]?.remove(path);
        // Remove empty parent lists
        if (_folderHierarchy[parentKey]?.isEmpty ?? false) {
          _folderHierarchy.remove(parentKey);
        }
      }

      // Remove associated photos from database only
      final photosToRemove = _photoBox.values.where((p) => p.path.startsWith(path)).toList();
      for (var photo in photosToRemove) {
        await photo.delete();
      }
      debugPrint('Removed ${photosToRemove.length} photos associated with folder from database');

      if (_selectedFolder == path) {
        selectFolder(null);
        // Clear photos from the photo manager if this folder was selected
        if (_photoManager != null) {
          _photoManager!.clearPhotos();
        }
      }

      // Now recursively remove all subfolders from list
      for (var subFolder in subFoldersToRemove) {
        await removeFolderFromList(subFolder);
      } // Update filtered folders after removal and rebuild hierarchy
      _updateFilteredFolders();
      _rebuildHierarchy();

      // Force UI update with multiple notification methods
      notifyListeners();

      // Add a small delay to ensure UI has time to process the changes
      await Future.delayed(Duration(milliseconds: 10));

      debugPrint('Folder removal from list complete: $path');
      debugPrint('Remaining folders count: ${_folders.length}');
      debugPrint('Filtered folders count: ${_filteredFolders.length}');
    }
  }

  // Delete folder permanently to recycle bin
  Future<void> deleteFolderToRecycleBin(String path) async {
    try {
      final directory = Directory(path);
      if (await directory.exists()) {
        // On Windows, use PowerShell to move folder to recycle bin (same approach as photo deletion)
        final result = await Process.run('powershell', [
          '-command',
          '''
          Add-Type -AssemblyName Microsoft.VisualBasic
          [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            '${path.replaceAll('\\', '\\\\')}',
            'OnlyErrorDialogs',
            'SendToRecycleBin'
          )
          '''
        ]);

        if (result.exitCode != 0) {
          throw Exception('Failed to move folder to recycle bin: ${result.stderr}');
        }

        debugPrint('Successfully moved folder to recycle bin: $path');
      } else {
        debugPrint('Folder does not exist on file system: $path');
      }

      // After deleting from file system, remove from our lists
      await removeFolderFromList(path);
    } catch (e) {
      debugPrint('Error deleting folder to recycle bin: $e');
      rethrow;
    }
  }

  // Replace an old folder path with a new one
  Future<void> replaceFolder(String oldPath, String newPath) async {
    await Future.delayed(Duration(milliseconds: 10)); // Short delay for UI thread

    debugPrint('Replacing folder: $oldPath -> $newPath');

    if (_folders.contains(oldPath) && !_folders.contains(newPath)) {
      // Step 1: Update photo paths and preserve metadata (ratings, tags, favorites)
      debugPrint('Updating photo paths from $oldPath to $newPath...');
      final photosToUpdate = _photoBox.values.where((p) => p.path.startsWith(oldPath)).toList();

      int updatedCount = 0;
      for (var photo in photosToUpdate) {
        final oldPhotoPath = photo.path;
        final newPhotoPath = photo.path.replaceFirst(oldPath, newPath);

        // Log metadata before update for verification
        if (photo.isFavorite || photo.rating > 0 || photo.tags.isNotEmpty) {
          debugPrint('Preserving metadata for: $oldPhotoPath');
          debugPrint('  - Favorite: ${photo.isFavorite}');
          debugPrint('  - Rating: ${photo.rating}');
          debugPrint('  - Tags: ${photo.tags.length}');
        }

        // Update the photo path while preserving all metadata
        photo.path = newPhotoPath;
        await photo.save();
        updatedCount++;

        if (photo.isFavorite || photo.rating > 0 || photo.tags.isNotEmpty) {
          debugPrint('Updated to: $newPhotoPath (metadata preserved)');
        }
      }

      debugPrint('Updated $updatedCount photo paths with metadata preserved'); // Step 2: Remove the old folder from our lists (but preserve photos metadata)
      await removeFolderFromListPreservingPhotos(oldPath);

      // Step 3: Add the new folder and scan for any additional photos
      await addFolder(newPath);

      // Step 4: Select the new path
      selectFolder(newPath);

      debugPrint('Folder replaced successfully: $oldPath -> $newPath');

      // Force update filtered folders and UI
      _updateFilteredFolders();
      notifyListeners();
    } else {
      debugPrint('Replace folder failed: oldPath exists=${_folders.contains(oldPath)}, newPath exists=${_folders.contains(newPath)}');
    }
  }

  void selectFolder(String? path) {
    debugPrint('Selecting folder: $path (previous: $_selectedFolder)');

    final oldSelectedFolder = _selectedFolder;
    _selectedFolder = path;

    // Clear section selection when a folder is selected
    if (path != null) {
      _selectedSection = null;
      debugPrint('Cleared section selection, selected folder: $path');
    }

    // Notify listeners immediately for UI update
    notifyListeners();
    debugPrint('notifyListeners() called for folder selection');

    // Load photos from the selected folder if photo manager is available
    if (_photoManager != null && path != null && path != oldSelectedFolder) {
      debugPrint('Loading photos for selected folder: $path');
      _photoManager!.loadPhotosFromFolder(path);
    } else if (_photoManager != null && path == null) {
      debugPrint('Clearing photos as no folder is selected');
      _photoManager!.clearPhotos();
    }

    debugPrint('Folder selection complete: $path');
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

  // Force a complete UI refresh - useful for debugging
  void forceUIRefresh() {
    debugPrint('Forcing complete UI refresh...');
    _updateFilteredFolders();
    notifyListeners();
    debugPrint('UI refresh complete. Folders: ${_folders.length}, Filtered: ${_filteredFolders.length}');
  }

  // Remove folder from list while preserving photos (for folder replacement)
  Future<void> removeFolderFromListPreservingPhotos(String path) async {
    // Check if the folder is in any of our lists
    bool folderExists = _folders.contains(path) || _missingFolders.contains(path);
    debugPrint('Removing folder from list (preserving photos): $path, exists: $folderExists');

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

      // Get all subfolders of this folder to remove them too
      List<String> subFoldersToRemove = [];
      if (_folderHierarchy.containsKey(path)) {
        // Make a copy of the subfolders list to avoid modification during iteration
        subFoldersToRemove = List.from(_folderHierarchy[path] ?? []);
        debugPrint('Found ${subFoldersToRemove.length} subfolders to remove from list');
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

      // Remove this folder from any parent's children list in the hierarchy
      // Need to use a safer approach to avoid concurrent modification
      final hierarchyKeysToUpdate = <String>[];
      _folderHierarchy.forEach((parent, children) {
        if (children.contains(path)) {
          hierarchyKeysToUpdate.add(parent);
        }
      });

      for (String parentKey in hierarchyKeysToUpdate) {
        _folderHierarchy[parentKey]?.remove(path);
        // Remove empty parent lists
        if (_folderHierarchy[parentKey]?.isEmpty ?? false) {
          _folderHierarchy.remove(parentKey);
        }
      }

      // NOTE: DO NOT remove photos from database - preserve metadata for folder replacement!
      debugPrint('Photos preserved during folder removal for replacement');

      if (_selectedFolder == path) {
        selectFolder(null);
        // Clear photos from the photo manager if this folder was selected
        if (_photoManager != null) {
          _photoManager!.clearPhotos();
        }
      }

      // Now recursively remove all subfolders from list (also preserving their photos)
      for (var subFolder in subFoldersToRemove) {
        await removeFolderFromListPreservingPhotos(subFolder);
      }

      // Update filtered folders after removal
      _updateFilteredFolders();
      notifyListeners();
      debugPrint('Folder removal from list complete (photos preserved): $path');
    }
  }

  // Scan for new subfolders that were created after initial import
  Future<void> _scanForNewSubfolders() async {
    debugPrint('Scanning for new subfolders...');

    int newFoldersFound = 0;
    final List<String> newFolders = [];

    // Create a copy of the folders list to avoid modification during iteration
    final foldersToScan = List<String>.from(_folders);

    for (String folderPath in foldersToScan) {
      // Only scan existing folders
      if (!Directory(folderPath).existsSync()) {
        continue;
      }

      try {
        // Get current subfolders in our database for this folder
        final currentSubfolders = Set<String>.from(_folderHierarchy[folderPath] ?? []);

        // Scan directory for actual subfolders
        final directory = Directory(folderPath);
        final entities = directory.listSync();

        for (var entity in entities) {
          if (entity is Directory) {
            final subPath = entity.path;

            // Check if this subfolder is new (not in our lists)
            if (!_folders.contains(subPath) && !currentSubfolders.contains(subPath)) {
              debugPrint('New subfolder found: $subPath');

              // Add to our lists
              _folders.add(subPath);
              newFolders.add(subPath);
              _addToHierarchy(subPath);

              // Update parent folder's subfolder list in Hive
              final parentFolderInBox = _folderBox.values.where((f) => f.path == folderPath).toList();
              if (parentFolderInBox.isNotEmpty) {
                parentFolderInBox.first.addSubFolder(subPath);
                await parentFolderInBox.first.save();
              }

              // Create Folder object for the new subfolder
              final newSubfolderObj = Folder(path: subPath);
              _folderBox.add(newSubfolderObj);

              newFoldersFound++;

              // Recursively scan the new subfolder for its subfolders
              await _scanFolderRecursively(subPath, newFolders);
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning folder $folderPath: $e');
      }
    }

    if (newFoldersFound > 0) {
      debugPrint('Found $newFoldersFound new subfolders');
      _updateFilteredFolders();
      notifyListeners();

      // Start indexing for new folders if photo manager is available
      if (_photoManager != null && newFolders.isNotEmpty) {
        for (String newFolder in newFolders) {
          debugPrint('Starting indexing for new subfolder: $newFolder');
          _photoManager!.indexFolderPhotos(newFolder);
        }
      }
    } else {
      debugPrint('No new subfolders found');
    }
  }

  // Helper method to recursively scan a folder and its subfolders
  Future<void> _scanFolderRecursively(String folderPath, List<String> newFolders) async {
    try {
      final directory = Directory(folderPath);
      if (!directory.existsSync()) return;

      final entities = directory.listSync();

      for (var entity in entities) {
        if (entity is Directory) {
          final subPath = entity.path;

          if (!_folders.contains(subPath)) {
            // Add to our lists
            _folders.add(subPath);
            newFolders.add(subPath);
            _addToHierarchy(subPath);

            // Update parent folder's subfolder list in Hive
            final parentFolderInBox = _folderBox.values.where((f) => f.path == folderPath).toList();
            if (parentFolderInBox.isNotEmpty) {
              parentFolderInBox.first.addSubFolder(subPath);
              await parentFolderInBox.first.save();
            }

            // Create Folder object for the new subfolder
            final newSubfolderObj = Folder(path: subPath);
            _folderBox.add(newSubfolderObj);

            // Continue recursively
            await _scanFolderRecursively(subPath, newFolders);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning folder recursively $folderPath: $e');
    }
  }

  // Manually trigger a scan for new subfolders (can be called from UI)
  Future<void> refreshSubfolders() async {
    debugPrint('Manual refresh of subfolders triggered');
    await _scanForNewSubfolders();
    debugPrint('Manual refresh completed');
  }
}
