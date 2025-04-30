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

  // Optimized photo loading with batching
  Future<void> loadPhotosFromFolder(String path) async {
    _photos.clear();

    // Show loading indicator
    notifyListeners();

    // Load photos asynchronously
    await _loadPhotosFromSingleFolder(path);

    // Notify listeners that photos are loaded
    notifyListeners();

    // Then start loading actual dimensions in batches
    if (_filterManager != null) {
      _loadDimensionsInBatches(_photos);
    }
  }

  // Load photos from multiple folders
  Future<void> loadPhotosFromMultipleFolders(List<String> paths) async {
    _photos.clear();

    // Show loading indicator
    notifyListeners();

    // Use a Set to track unique photo paths
    final Set<String> addedPhotoPaths = {};

    // Load photos from each folder
    for (var path in paths) {
      await _loadPhotosFromSingleFolder(path, addedPhotoPaths);

      // Notify after each folder to show progress
      notifyListeners();
    }

    // Then start loading actual dimensions in batches
    if (_filterManager != null) {
      _loadDimensionsInBatches(_photos);
    }
  }

  // Load dimensions in batches to prevent UI freezing and memory leaks
  void _loadDimensionsInBatches(List<Photo> photos) {
    // First filter out photos that already have dimensions
    final List<Photo> photosNeedingDimensions = photos.where((photo) => photo.width <= 0 || photo.height <= 0).toList();

    // If no photos need dimensions, return early
    if (photosNeedingDimensions.isEmpty) {
      debugPrint('No photos need dimensions, skipping batch processing');
      return;
    }

    debugPrint('Loading dimensions for ${photosNeedingDimensions.length} photos');

    const int batchSize = 10; // Process fewer photos at a time to reduce memory pressure
    int totalPhotos = photosNeedingDimensions.length;
    int processedCount = 0;

    Future<void> processBatch() async {
      if (processedCount >= totalPhotos) {
        debugPrint('Finished loading dimensions for all photos');
        return;
      }

      int endIndex = (processedCount + batchSize < totalPhotos) ? processedCount + batchSize : totalPhotos;

      List<Photo> batch = photosNeedingDimensions.sublist(processedCount, endIndex);

      // Process this batch
      for (var photo in batch) {
        if (_filterManager != null) {
          await _filterManager!.loadActualDimensions(photo);
        }
      }

      processedCount = endIndex;

      // Allow UI to update between batches and give more time for GC
      await Future.delayed(const Duration(milliseconds: 50));

      // Process next batch
      await processBatch();
    }

    // Start processing batches
    Future.microtask(processBatch);
  }

  // Helper method to load photos from a single folder - optimized version
  Future<void> _loadPhotosFromSingleFolder(String path, [Set<String>? addedPhotoPaths]) async {
    final directory = Directory(path);
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif'];

    try {
      // Create a map of existing photos for faster lookup
      final Map<String, Photo> existingPhotos = {};
      for (var photo in _photoBox.values) {
        existingPhotos[photo.path] = photo;
      }

      // Tüm dosyaları bir seferde bul (recursive olarak)
      debugPrint('Klasördeki tüm dosyalar taranıyor: $path');
      final List<FileSystemEntity> allFiles = directory.listSync(recursive: true);
      debugPrint('Toplam dosya sayısı: ${allFiles.length}');

      // Sadece resim dosyalarını filtrele
      final List<File> imageFiles = [];
      for (var file in allFiles) {
        if (file is File) {
          final extension = file.path.toLowerCase().split('.').last;
          if (imageExtensions.contains('.$extension')) {
            // Skip if this photo path has already been added
            if (addedPhotoPaths != null && addedPhotoPaths.contains(file.path)) {
              continue;
            }
            imageFiles.add(file);
          }
        }
      }

      debugPrint('Toplam resim dosyası sayısı: ${imageFiles.length}');

      // Tüm resim dosyalarını bir seferde işle (batch olmadan)
      for (var file in imageFiles) {
        // Use the map for faster lookup instead of firstWhere
        final photo = existingPhotos[file.path] ??
            Photo(
              path: file.path,
              dateModified: file.statSync().modified,
            );

        // Add to Hive box if it's a new photo
        if (!existingPhotos.containsKey(file.path)) {
          _photoBox.add(photo);
          existingPhotos[file.path] = photo; // Update the map
        }

        // Add to photos list and track the path if needed
        _photos.add(photo);
        addedPhotoPaths?.add(file.path);
      }

      debugPrint('Tüm fotoğraflar yüklendi. Toplam: ${_photos.length}');
    } catch (e) {
      debugPrint('Error loading photos from folder $path: $e');
    }
  }

  void toggleFavorite(Photo photo) {
    // Save previous state
    final bool wasFavorite = photo.isFavorite;

    // Toggle favorite
    photo.toggleFavorite();

    // Only notify if the state actually changed
    // This is redundant since toggleFavorite always changes state,
    // but it's a good practice for consistency
    if (wasFavorite != photo.isFavorite) {
      // Use microtask to prevent UI freezing during state update
      Future.microtask(() => notifyListeners());
    }
  }

  void setRating(Photo photo, int rating) {
    // Save previous rating
    final int oldRating = photo.rating;

    // Set new rating
    if (photo.rating == rating) {
      photo.setRating(0);
    } else {
      photo.setRating(rating);
    }

    // Only notify if the rating actually changed
    if (oldRating != photo.rating) {
      // Use microtask to prevent UI freezing during state update
      Future.microtask(() => notifyListeners());
    }
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
