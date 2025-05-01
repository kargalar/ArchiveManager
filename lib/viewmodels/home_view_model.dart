import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../models/sort_state.dart';
import '../managers/folder_manager.dart';
import '../managers/photo_manager.dart';
import '../managers/tag_manager.dart';
import '../managers/settings_manager.dart';
import '../managers/filter_manager.dart';

class HomeViewModel extends ChangeNotifier {
  Photo? _selectedPhoto;
  Photo? get selectedPhoto => _selectedPhoto;

  void setSelectedPhoto(Photo? photo) {
    // Only notify listeners if the selected photo actually changed
    if (_selectedPhoto != photo) {
      _selectedPhoto = photo;
      notifyListeners();
    }
  }

  void handleKeyEvent(KeyEvent event, BuildContext context, FolderManager folderManager, PhotoManager photoManager, TagManager tagManager) {
    if (event is! KeyDownEvent) return;

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
    } else if (event.logicalKey == LogicalKeyboardKey.delete && _selectedPhoto != null) {
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
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.keyF && _selectedPhoto != null) {
      // Toggle favorite with F key
      debugPrint('F key pressed, toggling favorite for ${_selectedPhoto!.path}');
      photoManager.toggleFavorite(_selectedPhoto!);
      return;
    } else {
      // Handle number keys for rating (1-9)
      final key = event.logicalKey.keyLabel;
      if (key.length == 1 && RegExp(r'[1-9]').hasMatch(key) && _selectedPhoto != null) {
        debugPrint('Number key $key pressed, setting rating for ${_selectedPhoto!.path}');
        photoManager.setRating(_selectedPhoto!, int.parse(key));
        return;
      }

      // Handle tag shortcuts
      final tags = tagManager.tags;
      for (var tag in tags) {
        if (event.logicalKey == tag.shortcutKey && _selectedPhoto != null) {
          debugPrint('Tag shortcut pressed for ${tag.name}, toggling tag for ${_selectedPhoto!.path}');
          tagManager.toggleTag(_selectedPhoto!, tag);
          return;
        }
      }
    }

    if (newIndex != currentIndex) {
      setSelectedPhoto(sortedPhotos[newIndex]);
    }
  }

  void handlePhotoTap(Photo photo) {
    // İndeksleme sırasında bile fotoğraf seçiminin düzgün çalışması için
    // Sadece seçilen fotoğraf değiştiğinde notifyListeners çağırıyoruz
    if (_selectedPhoto != photo) {
      _selectedPhoto = photo;
      notifyListeners();
    }
  }
}
