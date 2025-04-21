import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../models/sort_state.dart';
import '../models/tag.dart';

class FilterManager extends ChangeNotifier {
  // Sorting
  SortState _dateSortState = SortState.none;
  SortState _ratingSortState = SortState.none;

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
        break;
      case SortState.descending:
        _dateSortState = SortState.ascending;
        _ratingSortState = SortState.none;
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
        break;
      case SortState.descending:
        _ratingSortState = SortState.ascending;
        _dateSortState = SortState.none;
        break;
      case SortState.ascending:
        _ratingSortState = SortState.none;
        break;
    }
    notifyListeners();
  }

  void sortPhotos(List<Photo> photos) {
    if (_dateSortState != SortState.none) {
      switch (_dateSortState) {
        case SortState.ascending:
          photos.sort((a, b) => File(a.path).statSync().modified.compareTo(File(b.path).statSync().modified));
          break;
        case SortState.descending:
          photos.sort((a, b) => File(b.path).statSync().modified.compareTo(File(a.path).statSync().modified));
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
