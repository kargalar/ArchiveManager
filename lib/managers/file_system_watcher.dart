import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/folder.dart';

class FileSystemWatcher extends ChangeNotifier {
  final Map<String, StreamSubscription<FileSystemEvent>> _folderWatchers = {};
  final Box<Folder> _folderBox;
  final List<String> _folders;
  final List<String> _missingFolders;

  FileSystemWatcher(this._folderBox, this._folders, this._missingFolders) {
    _setupFolderWatchers();
  }

  @override
  void dispose() {
    // Cancel all folder watchers
    for (var subscription in _folderWatchers.values) {
      subscription.cancel();
    }
    _folderWatchers.clear();
    super.dispose();
  }

  void _setupFolderWatchers() {
    // Set up watchers for all folders that exist
    for (var folderPath in _folders) {
      if (!_missingFolders.contains(folderPath)) {
        _watchFolder(folderPath);
      }
    }
  }

  void watchFolder(String folderPath) {
    if (!_missingFolders.contains(folderPath)) {
      _watchFolder(folderPath);
    }
  }

  void _watchFolder(String folderPath) {
    // Cancel existing watcher if any
    _folderWatchers[folderPath]?.cancel();

    try {
      final directory = Directory(folderPath);
      if (directory.existsSync()) {
        // Watch the directory for changes
        _folderWatchers[folderPath] = directory.watch(recursive: false).listen((event) {
          _handleFolderChange(event, folderPath);
        });
        debugPrint('Started watching folder: $folderPath');
      }
    } catch (e) {
      debugPrint('Error setting up folder watcher for $folderPath: $e');
    }
  }

  void _handleFolderChange(FileSystemEvent event, String parentFolderPath) {
    // Only handle directory creation events
    if (event.type == FileSystemEvent.create) {
      final path = event.path;
      try {
        final entity = FileSystemEntity.typeSync(path);
        if (entity == FileSystemEntityType.directory) {
          debugPrint('New subfolder detected: $path in $parentFolderPath');

          // Check if this folder is already in our list
          if (!_folders.contains(path)) {
            // Find the parent folder in Hive
            final parentFolderInBox = _folderBox.values.firstWhere(
              (f) => f.path == parentFolderPath,
              orElse: () => throw Exception('Parent folder not found'),
            );

            // Add the new subfolder
            parentFolderInBox.addSubFolder(path);
            _folders.add(path);
            
            // Start watching the new subfolder too
            _watchFolder(path);

            notifyListeners();
            debugPrint('Added new subfolder: $path');
          }
        }
      } catch (e) {
        debugPrint('Error handling folder change: $e');
      }
    }
  }

  void unwatchFolder(String folderPath) {
    _folderWatchers[folderPath]?.cancel();
    _folderWatchers.remove(folderPath);
  }
}
