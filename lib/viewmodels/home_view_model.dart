import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../managers/folder_manager.dart';
import '../managers/photo_manager.dart';
import '../managers/tag_manager.dart';
import '../managers/settings_manager.dart';

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
    final photos = photoManager.photos;
    if (photos.isEmpty) return;

    if (_selectedPhoto == null) {
      setSelectedPhoto(photos[0]);
      return;
    }

    final currentIndex = photos.indexOf(_selectedPhoto!);
    final settingsManager = Provider.of<SettingsManager>(context, listen: false);
    final photosPerRow = settingsManager.photosPerRow;
    int newIndex = currentIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
      newIndex = currentIndex - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && currentIndex < photos.length - 1) {
      newIndex = currentIndex + 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && currentIndex >= photosPerRow) {
      newIndex = currentIndex - photosPerRow;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && currentIndex + photosPerRow < photos.length) {
      newIndex = currentIndex + photosPerRow;
    } else if (event.logicalKey == LogicalKeyboardKey.delete && _selectedPhoto != null) {
      final currentIndex = photos.indexOf(_selectedPhoto!);
      photoManager.deletePhoto(_selectedPhoto!);

      // Select next photo after deletion
      if (photos.isNotEmpty) {
        final nextIndex = currentIndex < photos.length ? currentIndex : photos.length - 1;
        setSelectedPhoto(photos[nextIndex]);
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
      setSelectedPhoto(photos[newIndex]);
    }
  }

  void handlePhotoTap(Photo photo) {
    setSelectedPhoto(photo);
  }
}
