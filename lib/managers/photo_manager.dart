import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/photo.dart';
import '../models/indexing_state.dart';
import 'filter_manager.dart';

class PhotoManager extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final List<Photo> _photos = [];
  FilterManager? _filterManager;

  // Indexing state tracking
  bool _isIndexing = false;
  double _indexingProgress = 0.0;
  int _totalPhotosToIndex = 0;
  int _indexedPhotosCount = 0;

  // Stream controller for indexing updates
  final _indexingController = StreamController<IndexingState>.broadcast();
  Stream<IndexingState> get indexingStream => _indexingController.stream;

  // Getters for indexing state
  bool get isIndexing => _isIndexing;
  double get indexingProgress => _indexingProgress;
  String get indexingStatus => _isIndexing ? 'İndeksleniyor: ${(_indexingProgress * 100).toStringAsFixed(1)}% ($_indexedPhotosCount/$_totalPhotosToIndex)' : '';

  // Method to get current indexing state
  IndexingState get currentIndexingState => IndexingState(
        isIndexing: _isIndexing,
        progress: _indexingProgress,
        processedCount: _indexedPhotosCount,
        totalCount: _totalPhotosToIndex,
      );

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

    // Then start indexing dimensions in the background
    if (_filterManager != null) {
      _startIndexing(_photos);
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

    // Then start indexing dimensions in the background
    if (_filterManager != null) {
      _startIndexing(_photos);
    }
  }

  // Start the indexing process in the background
  void _startIndexing(List<Photo> photos) {
    // First filter out photos that already have dimensions loaded
    final List<Photo> photosNeedingDimensions = photos.where((photo) => !photo.dimensionsLoaded || photo.width <= 0 || photo.height <= 0).toList();

    // If no photos need dimensions, return early
    if (photosNeedingDimensions.isEmpty) {
      debugPrint('No photos need dimensions, skipping indexing');
      _isIndexing = false;
      _indexingProgress = 1.0;

      // Update the stream with completed state
      _indexingController.add(currentIndexingState);

      // Also notify listeners for other UI elements
      notifyListeners();
      return;
    }

    // Set indexing state
    _isIndexing = true;
    _indexingProgress = 0.0;
    _totalPhotosToIndex = photosNeedingDimensions.length;
    _indexedPhotosCount = 0;

    // Update the stream with initial state
    _indexingController.add(currentIndexingState);

    // Also notify listeners for other UI elements
    notifyListeners();

    debugPrint('Starting indexing for ${photosNeedingDimensions.length} photos');

    // Process in batches to prevent UI freezing
    _loadDimensionsInBatches(photosNeedingDimensions);
  }

  // Load dimensions in batches to prevent UI freezing and memory leaks
  void _loadDimensionsInBatches(List<Photo> photos) {
    const int batchSize = 10; // Process fewer photos at a time to reduce memory pressure
    int totalPhotos = photos.length;
    int processedCount = 0;

    Future<void> processBatch() async {
      if (processedCount >= totalPhotos) {
        debugPrint('Finished indexing for all photos');
        _isIndexing = false;
        _indexingProgress = 1.0;

        // Update the stream with completed state
        _indexingController.add(currentIndexingState);

        // Also notify listeners for other UI elements that might need to know indexing is complete
        notifyListeners();
        return;
      }

      int endIndex = (processedCount + batchSize < totalPhotos) ? processedCount + batchSize : totalPhotos;

      List<Photo> batch = photos.sublist(processedCount, endIndex);

      // Process this batch
      for (var photo in batch) {
        if (_filterManager != null) {
          await _filterManager!.loadActualDimensions(photo);
        }
      }

      processedCount = endIndex;
      _indexedPhotosCount = processedCount;
      _indexingProgress = processedCount / totalPhotos;

      // Log progress periodically
      if (processedCount % 50 == 0 || processedCount == totalPhotos) {
        final percentage = (_indexingProgress * 100).toStringAsFixed(1);
        debugPrint('Indexed $processedCount/$totalPhotos photos ($percentage%)');
      }

      // Update the stream with current progress
      _indexingController.add(currentIndexingState);

      // Don't notify all listeners to prevent grid rebuilding
      // Only update the app bar through the stream

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
    debugPrint('Toggling favorite for photo: ${photo.path}, current state: ${photo.isFavorite}');

    // Toggle favorite
    photo.toggleFavorite();

    debugPrint('Favorite toggled to: ${photo.isFavorite}');

    // Notify listeners immediately
    notifyListeners();
  }

  void setRating(Photo photo, int rating) {
    debugPrint('Setting rating for photo: ${photo.path}, current rating: ${photo.rating}, new rating: $rating');

    // Set new rating
    if (photo.rating == rating) {
      photo.setRating(0);
      debugPrint('Rating cleared to 0');
    } else {
      photo.setRating(rating);
      debugPrint('Rating set to $rating');
    }

    // Notify listeners immediately
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

  @override
  void dispose() {
    _indexingController.close();
    super.dispose();
  }
}
