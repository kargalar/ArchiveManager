import 'package:archive_manager_v3/views/widgets/full_screen_image.dart';
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

class HomeViewModel extends ChangeNotifier {
  Photo? _selectedPhoto;
  Photo? get selectedPhoto => _selectedPhoto;

  // List to track selected photos
  final List<Photo> _selectedPhotos = [];
  List<Photo> get selectedPhotos => _selectedPhotos;

  // Check if any photos are selected
  bool get hasSelectedPhotos => _selectedPhotos.isNotEmpty;

  // Throttle navigation on key repeat to slow down rapid movement
  DateTime? _lastNavigationTime;
  static const Duration _navigationThrottleDelay = Duration(milliseconds: 100);

  void setSelectedPhoto(Photo? photo) {
    // Only notify listeners if the selected photo actually changed
    if (_selectedPhoto != photo) {
      _selectedPhoto = photo;
      notifyListeners();
    }
  }

  // Toggle selection for a photo
  void togglePhotoSelection(Photo photo) {
    if (photo.isSelected) {
      // Deselect the photo
      photo.isSelected = false;
      _selectedPhotos.remove(photo);
    } else {
      // Select the photo
      photo.isSelected = true;
      _selectedPhotos.add(photo);
    }
    notifyListeners();
  }

  // Clear all selections
  void clearPhotoSelections() {
    for (var photo in _selectedPhotos) {
      photo.isSelected = false;
    }
    _selectedPhotos.clear();
    notifyListeners();
  }

  // Apply favorite toggle to all selected photos
  void toggleFavoriteForSelectedPhotos(PhotoManager photoManager) {
    if (_selectedPhotos.isEmpty) return;

    for (var photo in _selectedPhotos) {
      photoManager.toggleFavorite(photo);
    }
  }

  // Apply rating to all selected photos
  void setRatingForSelectedPhotos(PhotoManager photoManager, int rating) {
    if (_selectedPhotos.isEmpty) return;

    for (var photo in _selectedPhotos) {
      photoManager.setRating(photo, rating);
    }
  }

  // Apply tag toggle to all selected photos
  void toggleTagForSelectedPhotos(TagManager tagManager, Tag tag) {
    if (_selectedPhotos.isEmpty) return;

    // Check how many of the selected photos have this tag
    int photosWithTag = _selectedPhotos.where((photo) => photo.tags.any((t) => t.id == tag.id)).length;

    // If all photos have the tag, remove it from all
    // If not all photos have the tag, add it to all photos that don't have it
    bool shouldAddTag = photosWithTag < _selectedPhotos.length;

    for (var photo in _selectedPhotos) {
      bool photoHasTag = photo.tags.any((t) => t.id == tag.id);

      if (shouldAddTag && !photoHasTag) {
        // Add tag to photos that don't have it
        tagManager.toggleTag(photo, tag);
      } else if (!shouldAddTag && photoHasTag) {
        // Remove tag from photos that have it (only when all photos had the tag)
        tagManager.toggleTag(photo, tag);
      }
    }
  }

  void handleKeyEvent(KeyEvent event, BuildContext context, FolderManager folderManager, PhotoManager photoManager, TagManager tagManager) {
    // Support continuous navigation on key hold by accepting KeyRepeatEvent for arrow keys only
    final isArrowKey = event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (event is! KeyDownEvent && !(event is KeyRepeatEvent && isArrowKey)) return;

    // Throttle navigation on key repeat to prevent too rapid movement
    if (event is KeyRepeatEvent && isArrowKey) {
      final now = DateTime.now();
      if (_lastNavigationTime != null && now.difference(_lastNavigationTime!) < _navigationThrottleDelay) {
        return; // Skip this event if it's too soon
      }
      _lastNavigationTime = now;
    }

    // Get the filter manager to access sorting state
    final filterManager = Provider.of<FilterManager>(context, listen: false);

    // Get filtered photos
    List<Photo> filteredPhotos = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags);

    // Create a copy of the filtered photos to sort
    List<Photo> sortedPhotos = List.from(filteredPhotos);

    // Apply the same sorting as in the photo grid
    if (filterManager.ratingSortState != SortState.none) {
      if (filterManager.ratingSortState == SortState.ascending) {
        sortedPhotos.sort((a, b) => a.rating.compareTo(b.rating));
      } else {
        sortedPhotos.sort((a, b) => b.rating.compareTo(a.rating));
      }
    } else if (filterManager.dateSortState != SortState.none) {
      if (filterManager.dateSortState == SortState.ascending) {
        sortedPhotos.sort((a, b) {
          final dateA = a.dateModified;
          final dateB = b.dateModified;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        });
      } else {
        sortedPhotos.sort((a, b) {
          final dateA = a.dateModified;
          final dateB = b.dateModified;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
      }
    } else if (filterManager.resolutionSortState != SortState.none) {
      if (filterManager.resolutionSortState == SortState.ascending) {
        sortedPhotos.sort((a, b) => a.resolution.compareTo(b.resolution));
      } else {
        sortedPhotos.sort((a, b) => b.resolution.compareTo(a.resolution));
      }
    }

    if (sortedPhotos.isEmpty) return;

    if (_selectedPhoto == null) {
      // If no selection yet and user navigates with arrow keys, select first and mark viewed
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final first = sortedPhotos[0];
        first.markViewed();
        setSelectedPhoto(first);
        return;
      }
      setSelectedPhoto(sortedPhotos[0]);
      return;
    }

    final currentIndex = sortedPhotos.indexOf(_selectedPhoto!);
    if (currentIndex == -1) {
      // If the selected photo is not in the sorted list, select the first photo
      setSelectedPhoto(sortedPhotos[0]);
      return;
    }

    final settingsManager = Provider.of<SettingsManager>(context, listen: false);
    final photosPerRow = settingsManager.photosPerRow;
    int newIndex = currentIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
      newIndex = currentIndex - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && currentIndex < sortedPhotos.length - 1) {
      newIndex = currentIndex + 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && currentIndex >= photosPerRow) {
      newIndex = currentIndex - photosPerRow;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && currentIndex + photosPerRow < sortedPhotos.length) {
      newIndex = currentIndex + photosPerRow;
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      // Check if we have selected photos
      if (hasSelectedPhotos) {
        // Delete all selected photos
        List<Photo> photosToDelete = List.from(_selectedPhotos);
        for (var photo in photosToDelete) {
          photoManager.deletePhoto(photo);
        }
        // Clear selections after deletion
        clearPhotoSelections();
      } else if (_selectedPhoto != null) {
        // Delete the single selected photo
        photoManager.deletePhoto(_selectedPhoto!);

        // Select next photo after deletion
        if (sortedPhotos.isNotEmpty) {
          // Refresh the sorted photos list after deletion
          sortedPhotos = List.from(filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags));

          // Apply the same sorting again
          if (filterManager.ratingSortState != SortState.none) {
            if (filterManager.ratingSortState == SortState.ascending) {
              sortedPhotos.sort((a, b) => a.rating.compareTo(b.rating));
            } else {
              sortedPhotos.sort((a, b) => b.rating.compareTo(a.rating));
            }
          } else if (filterManager.dateSortState != SortState.none) {
            if (filterManager.dateSortState == SortState.ascending) {
              sortedPhotos.sort((a, b) {
                final dateA = a.dateModified;
                final dateB = b.dateModified;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return -1;
                if (dateB == null) return 1;
                return dateA.compareTo(dateB);
              });
            } else {
              sortedPhotos.sort((a, b) {
                final dateA = a.dateModified;
                final dateB = b.dateModified;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });
            }
          } else if (filterManager.resolutionSortState != SortState.none) {
            if (filterManager.resolutionSortState == SortState.ascending) {
              sortedPhotos.sort((a, b) => a.resolution.compareTo(b.resolution));
            } else {
              sortedPhotos.sort((a, b) => b.resolution.compareTo(a.resolution));
            }
          }

          final nextIndex = currentIndex < sortedPhotos.length ? currentIndex : sortedPhotos.length - 1;
          setSelectedPhoto(sortedPhotos[nextIndex]);
        } else {
          setSelectedPhoto(null);
        }
      }
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      // Toggle favorite with F key
      if (hasSelectedPhotos) {
        // Toggle favorite for all selected photos
        toggleFavoriteForSelectedPhotos(photoManager);
      } else if (_selectedPhoto != null) {
        // Toggle favorite for the single selected photo
        debugPrint('F key pressed, toggling favorite for ${_selectedPhoto!.path}');
        photoManager.toggleFavorite(_selectedPhoto!);
      }
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Clear all selections with Escape key only if we're in grid view (not in fullscreen)
      // Check if we're in fullscreen mode using the static flag

      // Only clear selections if we're not in fullscreen mode
      if (hasSelectedPhotos && !FullScreenImage.isActive) {
        debugPrint('Escape pressed in grid view, clearing selections');
        clearPhotoSelections();
        return;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyA && (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      // Select all photos with Ctrl+A
      final filterManager = Provider.of<FilterManager>(context, listen: false);
      final List<Photo> allPhotos = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags);

      // Clear current selections first
      clearPhotoSelections();

      // Select all photos
      for (var photo in allPhotos) {
        photo.isSelected = true;
        _selectedPhotos.add(photo);
      }

      notifyListeners();
      return;
    } else {
      // Handle number keys for rating (0-9)
      final key = event.logicalKey.keyLabel;
      if (key.length == 1 && RegExp(r'[0-9]').hasMatch(key)) {
        final rating = int.parse(key);
        if (hasSelectedPhotos) {
          // Set rating for all selected photos
          setRatingForSelectedPhotos(photoManager, rating);
        } else if (_selectedPhoto != null) {
          // Set rating for the single selected photo
          debugPrint('Number key $key pressed, setting rating for ${_selectedPhoto!.path}');
          photoManager.setRating(_selectedPhoto!, rating);
        }
        return;
      }

      // Handle tag shortcuts
      final tags = tagManager.tags;
      for (var tag in tags) {
        if (event.logicalKey == tag.shortcutKey) {
          if (hasSelectedPhotos) {
            // Toggle tag for all selected photos
            toggleTagForSelectedPhotos(tagManager, tag);
          } else if (_selectedPhoto != null) {
            // Toggle tag for the single selected photo
            debugPrint('Tag shortcut pressed for ${tag.name}, toggling tag for ${_selectedPhoto!.path}');
            tagManager.toggleTag(_selectedPhoto!, tag);
          }
          return;
        }
      }
    }

    if (newIndex != currentIndex) {
      final target = sortedPhotos[newIndex];
      // Mark as viewed when navigating with arrow keys in grid
      target.markViewed();
      setSelectedPhoto(target);
    }
  }

  /// Selects a range of photos from the anchor (last selected) to [photo], clearing previous selections.
  void selectRange(List<Photo> photos, Photo photo) {
    if (_selectedPhoto == null) {
      // No anchor, fall back to single selection
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

  void handlePhotoTap(Photo photo, {bool isCtrlPressed = false}) {
    // If Ctrl key is pressed, don't change the selected photo
    // This allows selecting multiple photos without changing the current selection
    if (isCtrlPressed) {
      // Do nothing with the current selection
      return;
    }

    // Clear all selections when clicking on a photo without Ctrl
    if (hasSelectedPhotos) {
      clearPhotoSelections();
    }

    // İndeksleme sırasında bile fotoğraf seçiminin düzgün çalışması için
    // Sadece seçilen fotoğraf değiştiğinde notifyListeners çağırıyoruz
    if (_selectedPhoto != photo) {
      _selectedPhoto = photo;
      notifyListeners();
    }
  }
}
