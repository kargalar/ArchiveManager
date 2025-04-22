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
  double _maxRatingFilter = 7;

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
  Future<void> loadActualDimensions(Photo photo) async {
    try {
      final file = File(photo.path);
      if (!file.existsSync()) return;

      // Load date modified if not already loaded
      photo.dateModified ??= file.statSync().modified;

      // Skip if dimensions are already loaded
      if (photo.width > 0 && photo.height > 0) return;

      final completer = Completer<void>();
      final image = Image.file(file).image;
      final listener = ImageStreamListener(
        (info, _) {
          // Update the Photo object with actual dimensions
          photo.width = info.image.width;
          photo.height = info.image.height;
          photo.save(); // Save to Hive
          completer.complete();
        },
        onError: (exception, stackTrace) {
          debugPrint('Error loading image dimensions: $exception');
          completer.completeError(exception);
        },
      );

      image.resolve(const ImageConfiguration()).addListener(listener);
      await completer.future;
    } catch (e) {
      debugPrint('Error loading actual image dimensions: $e');
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
  Future<void> loadAllResolutions(List<Photo> photos) async {
    List<Future<void>> futures = [];

    for (var photo in photos) {
      if (photo.width <= 0 || photo.height <= 0 || photo.dateModified == null) {
        futures.add(loadActualDimensions(photo));
      }
    }

    await Future.wait(futures);
  }

  // Load dates for all photos that don't have it yet
  Future<void> loadAllDates(List<Photo> photos) async {
    for (var photo in photos) {
      if (photo.dateModified == null) {
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
    }
  }

  // Synchronous sorting for date and rating, potentially async for resolution
  Future<void> sortPhotos(List<Photo> photos) async {
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
        // We'll need to load resolutions first, but this will be handled by the caller
        // using the FutureBuilder pattern
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
