import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/folder.dart';
import '../models/photo.dart';

class FolderManager extends ChangeNotifier {
  final Box<Folder> _folderBox;
  final Box<Photo> _photoBox;
  final List<String> _folders = [];
  final Map<String, List<String>> _folderHierarchy = {};
  final Map<String, bool> _expandedFolders = {};
  List<String> _missingFolders = [];
  String? _selectedFolder;

  FolderManager(this._folderBox, this._photoBox) {
    _loadFolders();
    checkFoldersExistence();
  }

  // Getters
  List<String> get folders => _folders;
  String? get selectedFolder => _selectedFolder;
  Map<String, List<String>> get folderHierarchy => _folderHierarchy;
  Map<String, bool> get expandedFolders => _expandedFolders;
  List<String> get missingFolders => _missingFolders;

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
}
