import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/photo.dart';
import 'filter_manager.dart';

class PhotoManager extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final List<Photo> _photos = [];
  FilterManager? _filterManager;

  PhotoManager(this._photoBox);

  void setFilterManager(FilterManager filterManager) {
    _filterManager = filterManager;
  }

  List<Photo> get photos => _photos;

  void loadPhotosFromFolder(String path) {
    _photos.clear();
    _loadPhotosFromSingleFolder(path);

    // Notify listeners first so UI updates quickly
    notifyListeners();

    // Then start loading actual dimensions in the background
    if (_filterManager != null) {
      Future.microtask(() async {
        for (var photo in _photos) {
          // Load and save actual dimensions for each photo
          await _filterManager!.loadActualDimensions(photo);
        }
      });
    }
  }

  // Load photos from multiple folders
  void loadPhotosFromMultipleFolders(List<String> paths) {
    _photos.clear();

    // Use a Set to track unique photo paths
    final Set<String> addedPhotoPaths = {};

    for (var path in paths) {
      _loadPhotosFromSingleFolder(path, addedPhotoPaths);
    }

    // Notify listeners first so UI updates quickly
    notifyListeners();

    // Then start loading actual dimensions in the background
    if (_filterManager != null) {
      Future.microtask(() async {
        for (var photo in _photos) {
          // Load and save actual dimensions for each photo
          await _filterManager!.loadActualDimensions(photo);
        }
      });
    }
  }

  // Helper method to load photos from a single folder
  void _loadPhotosFromSingleFolder(String path, [Set<String>? addedPhotoPaths]) {
    final directory = Directory(path);
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif'];

    try {
      final files = directory.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          final extension = file.path.toLowerCase().split('.').last;
          if (imageExtensions.contains('.$extension')) {
            // Skip if this photo path has already been added (when using addedPhotoPaths)
            if (addedPhotoPaths != null && addedPhotoPaths.contains(file.path)) {
              continue;
            }

            // Check if photo exists in box
            final photo = _photoBox.values.firstWhere(
              (p) => p.path == file.path,
              orElse: () {
                // Create new photo with date modified
                final newPhoto = Photo(
                  path: file.path,
                  dateModified: file.statSync().modified,
                );
                return newPhoto;
              },
            );
            if (!_photoBox.values.contains(photo)) {
              _photoBox.add(photo);
            }

            // Add to photos list and track the path if needed
            _photos.add(photo);
            addedPhotoPaths?.add(file.path);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading photos from folder $path: $e');
    }
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

  void clearPhotos() {
    _photos.clear();
    notifyListeners();
  }
}
