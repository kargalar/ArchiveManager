// home_view_model.dart: Fotoğraf seçimi ve grid navigasyonu yönetir
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../models/sort_state.dart';
import '../models/tag.dart';
import '../managers/folder_manager.dart';
import '../managers/photo_manager.dart';
import '../managers/tag_manager.dart';
import '../managers/settings_manager.dart';
import '../managers/filter_manager.dart';
import '../services/input_controller.dart';
import '../views/widgets/full_screen_image.dart';

class HomeViewModel extends ChangeNotifier {
  Photo? _selectedPhoto;
  Photo? get selectedPhoto => _selectedPhoto;

  final List<Photo> _selectedPhotos = [];
  List<Photo> get selectedPhotos => _selectedPhotos;

  bool get hasSelectedPhotos => _selectedPhotos.isNotEmpty;

  DateTime? _lastNavigationTime;
  static const Duration _navigationThrottleDelay = Duration(milliseconds: 100);

  void setSelectedPhoto(Photo? photo) {
    if (_selectedPhoto != photo) {
      _selectedPhoto = photo;
      notifyListeners();
    }
  }

  void togglePhotoSelection(Photo photo) {
    if (photo.isSelected) {
      photo.isSelected = false;
      _selectedPhotos.remove(photo);
    } else {
      photo.isSelected = true;
      _selectedPhotos.add(photo);
    }
    notifyListeners();
  }

  void clearPhotoSelections() {
    for (var photo in _selectedPhotos) {
      photo.isSelected = false;
    }
    _selectedPhotos.clear();
    notifyListeners();
  }

  void toggleFavoriteForSelectedPhotos(PhotoManager photoManager) {
    if (_selectedPhotos.isEmpty) return;
    for (var photo in _selectedPhotos) {
      photoManager.toggleFavorite(photo);
    }
  }

  void setRatingForSelectedPhotos(PhotoManager photoManager, int rating) {
    if (_selectedPhotos.isEmpty) return;
    for (var photo in _selectedPhotos) {
      photoManager.setRating(photo, rating);
    }
  }

  void toggleTagForSelectedPhotos(TagManager tagManager, Tag tag) {
    if (_selectedPhotos.isEmpty) return;

    int photosWithTag = _selectedPhotos.where((photo) => photo.tags.any((t) => t.id == tag.id)).length;
    bool shouldAddTag = photosWithTag < _selectedPhotos.length;

    for (var photo in _selectedPhotos) {
      bool photoHasTag = photo.tags.any((t) => t.id == tag.id);

      if (shouldAddTag && !photoHasTag) {
        tagManager.toggleTag(photo, tag);
      } else if (!shouldAddTag && photoHasTag) {
        tagManager.toggleTag(photo, tag);
      }
    }
  }

  /// Helper: Sorting logic'ini apply et
  void _applySorting(
    List<Photo> photos,
    FilterManager filterManager,
  ) {
    if (filterManager.ratingSortState != SortState.none) {
      photos.sort((a, b) => filterManager.ratingSortState == SortState.ascending ? a.rating.compareTo(b.rating) : b.rating.compareTo(a.rating));
    } else if (filterManager.dateSortState != SortState.none) {
      _sortByDate(photos, filterManager.dateSortState == SortState.ascending);
    } else if (filterManager.resolutionSortState != SortState.none) {
      photos.sort((a, b) => filterManager.resolutionSortState == SortState.ascending ? a.resolution.compareTo(b.resolution) : b.resolution.compareTo(a.resolution));
    }
  }

  /// Helper: Tarih ile sıralama
  void _sortByDate(List<Photo> photos, bool ascending) {
    photos.sort((a, b) {
      final dateA = a.dateModified;
      final dateB = b.dateModified;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return ascending ? -1 : 1;
      if (dateB == null) return ascending ? 1 : -1;
      return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
  }

  void handleKeyEvent(
    KeyEvent event,
    BuildContext context,
    FolderManager folderManager,
    PhotoManager photoManager,
    TagManager tagManager,
  ) {
    final isArrowKey = _isArrowKey(event.logicalKey);
    if (event is! KeyDownEvent && !(event is KeyRepeatEvent && isArrowKey)) return;

    // Throttle navigation on key repeat
    if (event is KeyRepeatEvent && isArrowKey) {
      final now = DateTime.now();
      if (_lastNavigationTime != null && now.difference(_lastNavigationTime!) < _navigationThrottleDelay) {
        return;
      }
      _lastNavigationTime = now;
    }

    final filterManager = Provider.of<FilterManager>(context, listen: false);
    List<Photo> filteredPhotos = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags);
    List<Photo> sortedPhotos = List.from(filteredPhotos);
    _applySorting(sortedPhotos, filterManager);

    if (sortedPhotos.isEmpty) return;

    _handleNavigation(
      event,
      context,
      sortedPhotos,
      photoManager,
      tagManager,
      filterManager,
    );
  }

  /// Navigation ve action'ları handle et
  void _handleNavigation(
    KeyEvent event,
    BuildContext context,
    List<Photo> sortedPhotos,
    PhotoManager photoManager,
    TagManager tagManager,
    FilterManager filterManager,
  ) {
    final isArrowKey = _isArrowKey(event.logicalKey);

    if (_selectedPhoto == null && isArrowKey) {
      final first = sortedPhotos[0];
      first.markViewed();
      setSelectedPhoto(first);
      return;
    }

    if (_selectedPhoto == null) {
      setSelectedPhoto(sortedPhotos[0]);
      return;
    }

    final currentIndex = sortedPhotos.indexOf(_selectedPhoto!);
    if (currentIndex == -1) {
      setSelectedPhoto(sortedPhotos[0]);
      return;
    }

    int newIndex = _calculateNextIndex(
      event,
      currentIndex,
      sortedPhotos.length,
      Provider.of<SettingsManager>(context, listen: false).photosPerRow,
    );

    _handleSpecialKeys(
      event,
      context,
      photoManager,
      tagManager,
      sortedPhotos,
      currentIndex,
      filterManager,
    );

    if (newIndex != currentIndex) {
      final target = sortedPhotos[newIndex];
      target.markViewed();
      setSelectedPhoto(target);
    }
  }

  /// Next index hesapla (arrow key navigation)
  int _calculateNextIndex(
    KeyEvent event,
    int currentIndex,
    int totalPhotos,
    int photosPerRow,
  ) {
    int newIndex = currentIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
      newIndex = currentIndex - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && currentIndex < totalPhotos - 1) {
      newIndex = currentIndex + 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && currentIndex >= photosPerRow) {
      newIndex = currentIndex - photosPerRow;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && currentIndex + photosPerRow < totalPhotos) {
      newIndex = currentIndex + photosPerRow;
    }

    return newIndex;
  }

  /// Special key'leri handle et (Delete, F, Space, Escape, vb)
  void _handleSpecialKeys(
    KeyEvent event,
    BuildContext context,
    PhotoManager photoManager,
    TagManager tagManager,
    List<Photo> sortedPhotos,
    int currentIndex,
    FilterManager filterManager,
  ) {
    if (event.logicalKey == LogicalKeyboardKey.delete) {
      _handleDelete(photoManager, sortedPhotos, currentIndex, tagManager, filterManager);
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _handleFavoriteToggle(photoManager);
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _handleWallpaperSet(context);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _handleEscape();
    } else if (event.logicalKey == LogicalKeyboardKey.keyA && (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      _handleSelectAll(photoManager, tagManager, filterManager);
    } else {
      _handleNumberAndTagKeys(event, photoManager, tagManager);
    }
  }

  /// Delete action
  void _handleDelete(
    PhotoManager photoManager,
    List<Photo> sortedPhotos,
    int currentIndex,
    TagManager tagManager,
    FilterManager filterManager,
  ) {
    if (hasSelectedPhotos) {
      List<Photo> photosToDelete = List.from(_selectedPhotos);
      for (var photo in photosToDelete) {
        photoManager.deletePhoto(photo);
      }
      clearPhotoSelections();
    } else if (_selectedPhoto != null) {
      photoManager.deletePhoto(_selectedPhoto!);

      if (sortedPhotos.isNotEmpty) {
        sortedPhotos.removeWhere((p) => p == _selectedPhoto!);
        _applySorting(sortedPhotos, filterManager);

        final nextIndex = currentIndex < sortedPhotos.length ? currentIndex : sortedPhotos.length - 1;
        setSelectedPhoto(sortedPhotos.isNotEmpty ? sortedPhotos[nextIndex] : null);
      } else {
        setSelectedPhoto(null);
      }
    }
  }

  /// Favorite toggle
  void _handleFavoriteToggle(PhotoManager photoManager) {
    if (hasSelectedPhotos) {
      toggleFavoriteForSelectedPhotos(photoManager);
    } else if (_selectedPhoto != null) {
      photoManager.toggleFavorite(_selectedPhoto!);
    }
  }

  /// Wallpaper set
  void _handleWallpaperSet(BuildContext context) {
    if (_selectedPhoto != null) {
      final inputController = InputController();
      inputController.setAsWallpaper(context, _selectedPhoto!.path);
    }
  }

  /// Escape tuşu
  void _handleEscape() {
    if (hasSelectedPhotos && !FullScreenImage.isActive) {
      clearPhotoSelections();
    }
  }

  /// Select all
  void _handleSelectAll(
    PhotoManager photoManager,
    TagManager tagManager,
    FilterManager filterManager,
  ) {
    final allPhotos = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags);
    clearPhotoSelections();

    for (var photo in allPhotos) {
      photo.isSelected = true;
      _selectedPhotos.add(photo);
    }

    notifyListeners();
  }

  /// Number ve tag key'leri handle et
  void _handleNumberAndTagKeys(
    KeyEvent event,
    PhotoManager photoManager,
    TagManager tagManager,
  ) {
    final key = event.logicalKey.keyLabel;
    if (key.length == 1 && RegExp(r'[0-9]').hasMatch(key)) {
      final rating = int.parse(key);
      if (hasSelectedPhotos) {
        setRatingForSelectedPhotos(photoManager, rating);
      } else if (_selectedPhoto != null) {
        photoManager.setRating(_selectedPhoto!, rating);
      }
      return;
    }

    for (var tag in tagManager.tags) {
      if (event.logicalKey == tag.shortcutKey) {
        if (hasSelectedPhotos) {
          toggleTagForSelectedPhotos(tagManager, tag);
        } else if (_selectedPhoto != null) {
          tagManager.toggleTag(_selectedPhoto!, tag);
        }
        return;
      }
    }
  }

  /// Arrow key kontrolü
  bool _isArrowKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown;
  }

  /// Selects a range of photos from the anchor (last selected) to [photo]
  void selectRange(List<Photo> photos, Photo photo) {
    if (_selectedPhoto == null) {
      togglePhotoSelection(photo);
      return;
    }
    final startIndex = photos.indexOf(_selectedPhoto!);
    final endIndex = photos.indexOf(photo);
    if (startIndex == -1 || endIndex == -1) {
      togglePhotoSelection(photo);
      return;
    }
    final int lower = startIndex < endIndex ? startIndex : endIndex;
    final int upper = startIndex < endIndex ? endIndex : startIndex;
    clearPhotoSelections();
    for (int i = lower; i <= upper; i++) {
      final p = photos[i];
      if (!p.isSelected) {
        p.isSelected = true;
        _selectedPhotos.add(p);
      }
    }
    notifyListeners();
  }

  /// Handle photo tap
  void handlePhotoTap(Photo photo, {bool isCtrlPressed = false}) {
    if (isCtrlPressed) {
      return;
    }

    if (hasSelectedPhotos) {
      clearPhotoSelections();
    }

    if (_selectedPhoto != photo) {
      _selectedPhoto = photo;
      notifyListeners();
    }
  }
}
