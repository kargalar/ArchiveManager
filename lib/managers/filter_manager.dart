import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../models/sort_state.dart';
import '../models/tag.dart';

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

  // Load actual dimensions and date modified, and update Photo object
  // Optimized to prevent memory leaks
  Future<void> loadActualDimensions(Photo photo) async {
    try {
      final file = File(photo.path);
      if (!file.existsSync()) return;

      // Load date modified if not already loaded
      photo.dateModified ??= file.statSync().modified;

      // Skip if dimensions are already loaded - this is critical to prevent repeated loading
      if (photo.width > 0 && photo.height > 0) return;

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
        } catch (e) {
          debugPrint('Error clearing image cache: $e');
        }
      });
    } catch (e) {
      debugPrint('Error loading actual image dimensions: $e');
    }
  }

  // Helper method to load image dimensions with proper resource cleanup
  Future<void> _loadImageDimensions(String path, Photo photo) async {
    final completer = Completer<void>();
    final imageProvider = FileImage(File(path));

    // Use a more controlled approach to load the image
    final imageStream = imageProvider.resolve(const ImageConfiguration());
    final imageStreamListener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        // Update dimensions and save to Hive
        photo.width = imageInfo.image.width;
        photo.height = imageInfo.image.height;
        photo.save();

        // Release resources
        imageInfo.image.dispose();
        completer.complete();
      },
      onError: (exception, stackTrace) {
        debugPrint('Error loading image dimensions: $exception');
        completer.completeError(exception);
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
    }
  }

  // Check if all photos have resolution data
  bool allPhotosHaveResolution(List<Photo> photos) {
    return photos.every((photo) => photo.width > 0 && photo.height > 0);
  }

  // Check if all photos have date modified data
  bool allPhotosHaveDate(List<Photo> photos) {
    return photos.every((photo) => photo.dateModified != null);
  }

  // Load resolutions and dates for all photos that don't have it yet
  // Optimized to prevent memory leaks
  Future<void> loadAllResolutions(List<Photo> photos) async {
    // Filter photos that need dimensions
    final List<Photo> photosNeedingData = photos.where((photo) => photo.width <= 0 || photo.height <= 0 || photo.dateModified == null).toList();

    if (photosNeedingData.isEmpty) {
      return; // No photos need processing
    }

    // Process in small batches to prevent memory buildup
    const int batchSize = 10;
    for (int i = 0; i < photosNeedingData.length; i += batchSize) {
      final int end = (i + batchSize < photosNeedingData.length) ? i + batchSize : photosNeedingData.length;

      final batch = photosNeedingData.sublist(i, end);

      // Process each photo in the batch
      for (var photo in batch) {
        await loadActualDimensions(photo);
      }

      // Allow UI to update and GC to run between batches
      await Future.delayed(const Duration(milliseconds: 50));
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

  // Optimized sorting with batching for better performance
  Future<void> sortPhotos(List<Photo> photos) async {
    if (photos.isEmpty) return;

    // Use isolate for sorting if the list is large
    if (photos.length > 1000) {
      await _sortPhotosInBatches(photos);
      return;
    }

    // For smaller lists, use the regular sorting approach
    if (_dateSortState != SortState.none) {
      // Check if we need to load dates first
      if (!allPhotosHaveDate(photos)) {
        // We'll need to load dates first
        await loadAllDates(photos);
      }

      switch (_dateSortState) {
        case SortState.ascending:
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
      switch (_ratingSortState) {
        case SortState.ascending:
          photos.sort((a, b) => a.rating.compareTo(b.rating));
          break;
        case SortState.descending:
          photos.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case SortState.none:
          break;
      }
    } else if (_resolutionSortState != SortState.none) {
      // Check if we need to load resolutions first
      if (!allPhotosHaveResolution(photos)) {
        // We'll need to load resolutions first
        await loadAllResolutions(photos);
      }

      // Now sort by resolution
      switch (_resolutionSortState) {
        case SortState.ascending:
          photos.sort((a, b) => (a.resolution).compareTo(b.resolution));
          break;
        case SortState.descending:
          photos.sort((a, b) => (b.resolution).compareTo(a.resolution));
          break;
        case SortState.none:
          break;
      }
    }
  }

  // Sort photos in batches to prevent UI freezing
  Future<void> _sortPhotosInBatches(List<Photo> photos) async {
    // First, ensure all required data is loaded
    if (_dateSortState != SortState.none && !allPhotosHaveDate(photos)) {
      await loadAllDates(photos);
    } else if (_resolutionSortState != SortState.none && !allPhotosHaveResolution(photos)) {
      await loadAllResolutions(photos);
    }

    // Create a copy of the list to sort
    final List<Photo> sortedPhotos = List.from(photos);

    // Sort the copy based on the current sort state
    if (_dateSortState == SortState.ascending) {
      sortedPhotos.sort((a, b) {
        final dateA = a.dateModified;
        final dateB = b.dateModified;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return -1;
        if (dateB == null) return 1;
        return dateA.compareTo(dateB);
      });
    } else if (_dateSortState == SortState.descending) {
      sortedPhotos.sort((a, b) {
        final dateA = a.dateModified;
        final dateB = b.dateModified;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    } else if (_ratingSortState == SortState.ascending) {
      sortedPhotos.sort((a, b) => a.rating.compareTo(b.rating));
    } else if (_ratingSortState == SortState.descending) {
      sortedPhotos.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_resolutionSortState == SortState.ascending) {
      sortedPhotos.sort((a, b) => (a.resolution).compareTo(b.resolution));
    } else if (_resolutionSortState == SortState.descending) {
      sortedPhotos.sort((a, b) => (b.resolution).compareTo(a.resolution));
    }

    // Clear the original list and add all sorted items at once
    photos.clear();
    photos.addAll(sortedPhotos);

    debugPrint('Tüm fotoğraflar sıralandı ve eklendi: ${photos.length}');
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
}
