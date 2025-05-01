import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../models/sort_state.dart';
import '../models/tag.dart';
import 'photo_manager.dart';
import '../main.dart';

class FilterManager extends ChangeNotifier {
  // Sorting
  SortState _dateSortState = SortState.none;
  SortState _ratingSortState = SortState.none;
  SortState _resolutionSortState = SortState.none;

  // Filtering
  String _filterType = 'all';
  String _favoriteFilterMode = 'none'; // none, favorites, non-favorites
  String _tagFilterMode = 'none'; // none, untagged, tagged, filtered
  bool _showUntaggedOnly = false;
  double _minRatingFilter = 0;
  double _maxRatingFilter = 9;

  // Loading state tracking
  bool _isLoadingDimensions = false;
  bool _isSorting = false;
  double _loadingProgress = 0.0; // 0.0 to 1.0
  Completer<void>? _dimensionsLoadingCompleter;

  // Getters
  SortState get dateSortState => _dateSortState;
  SortState get ratingSortState => _ratingSortState;
  SortState get resolutionSortState => _resolutionSortState;
  String get filterType => _filterType;
  String get favoriteFilterMode => _favoriteFilterMode;
  String get tagFilterMode => _tagFilterMode;
  bool get showUntaggedOnly => _showUntaggedOnly;
  double get minRatingFilter => _minRatingFilter;
  double get maxRatingFilter => _maxRatingFilter;

  // Loading state getters
  bool get isLoadingDimensions => _isLoadingDimensions;
  bool get isSorting => _isSorting;
  double get loadingProgress => _loadingProgress;

  // Sorting methods
  void resetDateSort() {
    _dateSortState = SortState.none;
    notifyListeners();
  }

  void toggleDateSort() {
    switch (_dateSortState) {
      case SortState.none:
        _dateSortState = SortState.descending;
        _ratingSortState = SortState.none;
        _resolutionSortState = SortState.none;
        break;
      case SortState.descending:
        _dateSortState = SortState.ascending;
        _ratingSortState = SortState.none;
        _resolutionSortState = SortState.none;
        break;
      case SortState.ascending:
        _dateSortState = SortState.none;
        break;
    }
    notifyListeners();
  }

  void resetRatingSort() {
    _ratingSortState = SortState.none;
    notifyListeners();
  }

  void toggleRatingSort() {
    switch (_ratingSortState) {
      case SortState.none:
        _ratingSortState = SortState.descending;
        _dateSortState = SortState.none;
        _resolutionSortState = SortState.none;
        break;
      case SortState.descending:
        _ratingSortState = SortState.ascending;
        _dateSortState = SortState.none;
        _resolutionSortState = SortState.none;
        break;
      case SortState.ascending:
        _ratingSortState = SortState.none;
        break;
    }
    notifyListeners();
  }

  void resetResolutionSort() {
    _resolutionSortState = SortState.none;
    notifyListeners();
  }

  void toggleResolutionSort() {
    // Check if indexing is in progress
    if (_photoManager != null && _photoManager!.isIndexing) {
      // Don't allow resolution sorting during indexing
      debugPrint('Cannot sort by resolution while indexing is in progress');

      // Show warning dialog
      _showIndexingWarningDialog();

      // Reset resolution sort state
      _resolutionSortState = SortState.none;
      notifyListeners();
      return;
    }

    switch (_resolutionSortState) {
      case SortState.none:
        _resolutionSortState = SortState.descending;
        _dateSortState = SortState.none;
        _ratingSortState = SortState.none;
        break;
      case SortState.descending:
        _resolutionSortState = SortState.ascending;
        _dateSortState = SortState.none;
        _ratingSortState = SortState.none;
        break;
      case SortState.ascending:
        _resolutionSortState = SortState.none;
        break;
    }
    notifyListeners();
  }

  // Show warning dialog when trying to sort by resolution during indexing
  void _showIndexingWarningDialog() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('İndeksleme Devam Ediyor'),
          content: const Text(
            'Fotoğrafların boyutları şu anda indeksleniyor. İndeksleme tamamlanana kadar çözünürlüğe göre sıralama yapılamaz. '
            'Lütfen indeksleme işleminin tamamlanmasını bekleyin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  // Load actual dimensions and date modified, and update Photo object
  // Optimized to prevent memory leaks
  Future<void> loadActualDimensions(Photo photo) async {
    try {
      final file = File(photo.path);
      if (!file.existsSync()) {
        // Dosya yoksa, boyutları yüklenmiş olarak işaretle
        photo.width = 1;
        photo.height = 1;
        photo.dimensionsLoaded = true;
        photo.save();
        debugPrint('File does not exist, marking as loaded with default dimensions: ${photo.path}');
        return;
      }

      // Load date modified if not already loaded
      photo.dateModified ??= file.statSync().modified;

      // Skip if dimensions are already loaded and marked as such
      // This is critical to prevent repeated loading
      if (photo.dimensionsLoaded) return;

      // Create a limited scope for the image loading
      await _loadImageDimensions(file.path, photo);

      // Explicitly call garbage collection to free memory
      // This is not normally recommended but helps in this specific case
      // to prevent memory buildup during batch processing
      Future.microtask(() {
        try {
          // Force a GC cycle after processing each image
          // This is a workaround for Flutter's image caching behavior
          ImageCache().clear();
          ImageCache().clearLiveImages();

          // Only clear PaintingBinding if it's available
          if (WidgetsBinding.instance is PaintingBinding) {
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
          }

          debugPrint('Image cache cleared to prevent memory leaks');
        } catch (e) {
          debugPrint('Error clearing image cache: $e');
        }
      });
    } catch (e) {
      // Hata durumunda, boyutları yüklenmiş olarak işaretle
      photo.width = 1;
      photo.height = 1;
      photo.dimensionsLoaded = true;
      photo.save();
      debugPrint('Error loading actual image dimensions, marking as loaded with default dimensions: $e');
    }
  }

  // Helper method to load image dimensions with proper resource cleanup
  Future<void> _loadImageDimensions(String path, Photo photo) async {
    final completer = Completer<void>();
    final imageProvider = FileImage(File(path));
    bool isCompleted = false;

    // Set a timeout to handle images that can't be loaded
    Timer? timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!isCompleted) {
        debugPrint('Timeout loading image dimensions for: $path');
        // Mark as loaded with default dimensions to prevent future loading attempts
        photo.width = 1;
        photo.height = 1;
        photo.dimensionsLoaded = true;
        photo.save();
        isCompleted = true;
        completer.complete();
      }
    });

    // Use a more controlled approach to load the image
    final imageStream = imageProvider.resolve(const ImageConfiguration());
    final imageStreamListener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        // Cancel timeout timer
        timeoutTimer?.cancel();
        timeoutTimer = null;

        // Update dimensions and save to Hive
        photo.width = imageInfo.image.width;
        photo.height = imageInfo.image.height;
        photo.dimensionsLoaded = true;
        photo.save();

        // Release resources
        imageInfo.image.dispose();
        if (!isCompleted) {
          isCompleted = true;
          completer.complete();
        }
      },
      onError: (exception, stackTrace) {
        // Cancel timeout timer
        timeoutTimer?.cancel();
        timeoutTimer = null;

        debugPrint('Error loading image dimensions: $exception');

        // Mark as loaded with default dimensions to prevent future loading attempts
        photo.width = 1;
        photo.height = 1;
        photo.dimensionsLoaded = true;
        photo.save();

        if (!isCompleted) {
          isCompleted = true;
          completer.complete(); // Complete normally instead of with error
        }
      },
    );

    // Add listener
    imageStream.addListener(imageStreamListener);

    try {
      await completer.future;
    } finally {
      // Always remove the listener to prevent memory leaks
      imageStream.removeListener(imageStreamListener);
      imageProvider.evict();
      timeoutTimer?.cancel();
    }
  }

  // Check if all photos have resolution data
  bool allPhotosHaveResolution(List<Photo> photos) {
    return photos.every((photo) => photo.dimensionsLoaded);
  }

  // Check if all photos have date modified data
  bool allPhotosHaveDate(List<Photo> photos) {
    return photos.every((photo) => photo.dateModified != null);
  }

  // Load resolutions and dates for all photos that don't have it yet
  // Optimized to prevent memory leaks and duplicate loading
  Future<void> loadAllResolutions(List<Photo> photos) async {
    // If already loading, return the existing completer
    if (_isLoadingDimensions && _dimensionsLoadingCompleter != null) {
      return _dimensionsLoadingCompleter!.future;
    }

    // Create a new completer and mark as loading
    _dimensionsLoadingCompleter = Completer<void>();
    _isLoadingDimensions = true;
    _loadingProgress = 0.0;
    notifyListeners();

    try {
      // Filter photos that need dimensions or dates
      final List<Photo> photosNeedingData = photos.where((photo) => !photo.dimensionsLoaded || photo.dateModified == null).toList();

      if (photosNeedingData.isEmpty) {
        _loadingProgress = 1.0;
        _isLoadingDimensions = false;
        _dimensionsLoadingCompleter!.complete();
        notifyListeners();
        return; // No photos need processing
      }

      // Calculate total photos to process for progress tracking
      final int totalPhotos = photosNeedingData.length;
      int processedCount = 0;

      debugPrint('Loading dimensions for $totalPhotos photos');

      // Process in small batches to prevent memory buildup
      const int batchSize = 10;
      for (int i = 0; i < photosNeedingData.length; i += batchSize) {
        final int end = (i + batchSize < photosNeedingData.length) ? i + batchSize : photosNeedingData.length;

        final batch = photosNeedingData.sublist(i, end);

        // Process each photo in the batch
        for (var photo in batch) {
          await loadActualDimensions(photo);
          processedCount++;

          // Update progress
          _loadingProgress = processedCount / totalPhotos;
          if (processedCount % 10 == 0) {
            notifyListeners();
          }
        }

        // Log progress periodically
        if (processedCount % 50 == 0 || processedCount == totalPhotos) {
          final percentage = (processedCount / totalPhotos * 100).toStringAsFixed(1);
          debugPrint('Processed $processedCount/$totalPhotos photos ($percentage%)');
        }

        // Allow UI to update and GC to run between batches
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint('Finished loading dimensions for all photos');
      _loadingProgress = 1.0;
      _isLoadingDimensions = false;
      _dimensionsLoadingCompleter!.complete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading dimensions: $e');
      _isLoadingDimensions = false;
      _dimensionsLoadingCompleter!.completeError(e);
      notifyListeners();
    }
  }

  // Load dates for all photos that don't have it yet
  // Optimized to prevent UI freezing
  Future<void> loadAllDates(List<Photo> photos) async {
    // Filter photos that need dates
    final List<Photo> photosNeedingDates = photos.where((photo) => photo.dateModified == null).toList();

    if (photosNeedingDates.isEmpty) {
      return; // No photos need processing
    }

    // Process in batches to prevent UI freezing
    const int batchSize = 50; // Date loading is faster, so we can use larger batches
    for (int i = 0; i < photosNeedingDates.length; i += batchSize) {
      final int end = (i + batchSize < photosNeedingDates.length) ? i + batchSize : photosNeedingDates.length;

      final batch = photosNeedingDates.sublist(i, end);

      // Process each photo in the batch
      for (var photo in batch) {
        try {
          final file = File(photo.path);
          if (file.existsSync()) {
            photo.dateModified = file.statSync().modified;
            photo.save();
          }
        } catch (e) {
          debugPrint('Error loading date for photo: $e');
        }
      }

      // Allow UI to update between batches
      if (i + batchSize < photosNeedingDates.length) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  // Reference to PhotoManager for checking indexing state
  PhotoManager? _photoManager;

  void setPhotoManager(PhotoManager photoManager) {
    _photoManager = photoManager;
  }

  // Optimized sorting with batching for better performance
  Future<void> sortPhotos(List<Photo> photos) async {
    if (photos.isEmpty) {
      debugPrint('No photos to sort, returning early');
      return;
    }

    // If already sorting, don't start another sort
    if (_isSorting) {
      debugPrint('Already sorting, returning early');
      return;
    }

    // Check if indexing is in progress for resolution sorting
    if (_resolutionSortState != SortState.none && _photoManager != null && _photoManager!.isIndexing) {
      // Don't allow resolution sorting during indexing
      debugPrint('Cannot sort by resolution while indexing is in progress');
      _resolutionSortState = SortState.none;
      notifyListeners();
      return;
    }

    _isSorting = true;
    notifyListeners();

    debugPrint('Starting sort operation with ${photos.length} photos');
    debugPrint('Sort states: Resolution=$_resolutionSortState, Date=$_dateSortState, Rating=$_ratingSortState');

    try {
      // Use isolate for sorting if the list is large
      if (photos.length > 1000) {
        debugPrint('Large photo collection (${photos.length}), using batch sorting');
        await _sortPhotosInBatches(photos);
        _isSorting = false;
        notifyListeners();
        return;
      }

      // For smaller lists, use the regular sorting approach
      if (_dateSortState != SortState.none) {
        debugPrint('Sorting by date: $_dateSortState');
        // Check if we need to load dates first
        if (!allPhotosHaveDate(photos)) {
          debugPrint('Loading dates for photos first');
          // We'll need to load dates first
          await loadAllDates(photos);
        }

        switch (_dateSortState) {
          case SortState.ascending:
            debugPrint('Sorting dates ascending');
            photos.sort((a, b) {
              final dateA = a.dateModified;
              final dateB = b.dateModified;
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return -1;
              if (dateB == null) return 1;
              return dateA.compareTo(dateB);
            });
            break;
          case SortState.descending:
            debugPrint('Sorting dates descending');
            photos.sort((a, b) {
              final dateA = a.dateModified;
              final dateB = b.dateModified;
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            });
            break;
          case SortState.none:
            break;
        }
      } else if (_ratingSortState != SortState.none) {
        debugPrint('Sorting by rating: $_ratingSortState');

        // Log some ratings to verify data
        if (photos.isNotEmpty) {
          debugPrint('Sample ratings before sort:');
          for (int i = 0; i < math.min(5, photos.length); i++) {
            debugPrint('Photo ${i + 1}: rating=${photos[i].rating}, path=${photos[i].path}');
          }
        }

        switch (_ratingSortState) {
          case SortState.ascending:
            debugPrint('Sorting ratings ascending');
            photos.sort((a, b) => a.rating.compareTo(b.rating));
            break;
          case SortState.descending:
            debugPrint('Sorting ratings descending');
            photos.sort((a, b) => b.rating.compareTo(a.rating));
            break;
          case SortState.none:
            break;
        }

        // Log some ratings after sort to verify it worked
        if (photos.isNotEmpty) {
          debugPrint('Sample ratings after sort:');
          for (int i = 0; i < math.min(5, photos.length); i++) {
            debugPrint('Photo ${i + 1}: rating=${photos[i].rating}, path=${photos[i].path}');
          }
        }
      } else if (_resolutionSortState != SortState.none) {
        debugPrint('Sorting by resolution: $_resolutionSortState');
        // Check if we need to load resolutions first
        if (!allPhotosHaveResolution(photos)) {
          debugPrint('Loading resolutions for photos first');
          // We'll need to load resolutions first
          await loadAllResolutions(photos);
        }

        // Now sort by resolution
        switch (_resolutionSortState) {
          case SortState.ascending:
            debugPrint('Sorting resolutions ascending');
            photos.sort((a, b) => (a.resolution).compareTo(b.resolution));
            break;
          case SortState.descending:
            debugPrint('Sorting resolutions descending');
            photos.sort((a, b) => (b.resolution).compareTo(a.resolution));
            break;
          case SortState.none:
            break;
        }
      }

      debugPrint('Sorting completed successfully');
      _isSorting = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error during sorting: $e');
      _isSorting = false;
      notifyListeners();
    }
  }

  // Sort photos in batches to prevent UI freezing
  Future<void> _sortPhotosInBatches(List<Photo> photos) async {
    debugPrint('Starting batch sorting for ${photos.length} photos');

    // First, ensure all required data is loaded
    if (_dateSortState != SortState.none && !allPhotosHaveDate(photos)) {
      debugPrint('Loading dates for batch sorting');
      await loadAllDates(photos);
    } else if (_resolutionSortState != SortState.none && !allPhotosHaveResolution(photos)) {
      debugPrint('Loading resolutions for batch sorting');
      await loadAllResolutions(photos);
    }

    // Create a copy of the list to sort
    final List<Photo> sortedPhotos = List.from(photos);

    debugPrint('Sorting ${sortedPhotos.length} photos in batch mode');
    debugPrint('Sort states: Resolution=$_resolutionSortState, Date=$_dateSortState, Rating=$_ratingSortState');

    // Sort the copy based on the current sort state
    if (_dateSortState == SortState.ascending) {
      debugPrint('Batch sorting dates ascending');
      sortedPhotos.sort((a, b) {
        final dateA = a.dateModified;
        final dateB = b.dateModified;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return -1;
        if (dateB == null) return 1;
        return dateA.compareTo(dateB);
      });
    } else if (_dateSortState == SortState.descending) {
      debugPrint('Batch sorting dates descending');
      sortedPhotos.sort((a, b) {
        final dateA = a.dateModified;
        final dateB = b.dateModified;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    } else if (_ratingSortState == SortState.ascending) {
      debugPrint('Batch sorting ratings ascending');

      // Log some ratings to verify data
      if (sortedPhotos.isNotEmpty) {
        debugPrint('Sample ratings before batch sort:');
        for (int i = 0; i < math.min(5, sortedPhotos.length); i++) {
          debugPrint('Photo ${i + 1}: rating=${sortedPhotos[i].rating}, path=${sortedPhotos[i].path}');
        }
      }

      sortedPhotos.sort((a, b) => a.rating.compareTo(b.rating));

      // Log some ratings after sort to verify it worked
      if (sortedPhotos.isNotEmpty) {
        debugPrint('Sample ratings after batch sort:');
        for (int i = 0; i < math.min(5, sortedPhotos.length); i++) {
          debugPrint('Photo ${i + 1}: rating=${sortedPhotos[i].rating}, path=${sortedPhotos[i].path}');
        }
      }
    } else if (_ratingSortState == SortState.descending) {
      debugPrint('Batch sorting ratings descending');

      // Log some ratings to verify data
      if (sortedPhotos.isNotEmpty) {
        debugPrint('Sample ratings before batch sort:');
        for (int i = 0; i < math.min(5, sortedPhotos.length); i++) {
          debugPrint('Photo ${i + 1}: rating=${sortedPhotos[i].rating}, path=${sortedPhotos[i].path}');
        }
      }

      sortedPhotos.sort((a, b) => b.rating.compareTo(a.rating));

      // Log some ratings after sort to verify it worked
      if (sortedPhotos.isNotEmpty) {
        debugPrint('Sample ratings after batch sort:');
        for (int i = 0; i < math.min(5, sortedPhotos.length); i++) {
          debugPrint('Photo ${i + 1}: rating=${sortedPhotos[i].rating}, path=${sortedPhotos[i].path}');
        }
      }
    } else if (_resolutionSortState == SortState.ascending) {
      debugPrint('Batch sorting resolutions ascending');
      sortedPhotos.sort((a, b) => (a.resolution).compareTo(b.resolution));
    } else if (_resolutionSortState == SortState.descending) {
      debugPrint('Batch sorting resolutions descending');
      sortedPhotos.sort((a, b) => (b.resolution).compareTo(a.resolution));
    }

    // Clear the original list and add all sorted items at once
    photos.clear();
    photos.addAll(sortedPhotos);

    debugPrint('Batch sorting completed: ${photos.length} photos sorted and updated');
  }

  // Filter methods
  void toggleTagFilterMode() {
    switch (_tagFilterMode) {
      case 'none':
        _tagFilterMode = 'untagged';
        break;
      case 'untagged':
        _tagFilterMode = 'tagged';
        break;
      case 'tagged':
        _tagFilterMode = 'none';
        break;
      case 'filtered':
        _tagFilterMode = 'none';
        break;
    }
    notifyListeners();
  }

  void setTagFilterMode(String mode) {
    _tagFilterMode = mode;
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
    notifyListeners();
  }

  void toggleUntaggedFilter() {
    _showUntaggedOnly = !_showUntaggedOnly;
    if (_showUntaggedOnly) {
      _favoriteFilterMode = 'none';
    }
    notifyListeners();
  }

  void setRatingFilter(double min, double max) {
    _minRatingFilter = min;
    _maxRatingFilter = max;
    notifyListeners();
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  List<Photo> filterPhotos(List<Photo> photos, List<Tag> selectedTags) {
    return photos.where((photo) {
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
          if (selectedTags.isNotEmpty && !selectedTags.every((tag) => photo.tags.any((photoTag) => photoTag.id == tag.id))) return false;
          break;
      }

      if (photo.rating < _minRatingFilter || photo.rating > _maxRatingFilter) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    // Clean up resources
    _dimensionsLoadingCompleter = null;
    super.dispose();
  }
}
