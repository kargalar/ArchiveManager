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
    _selectedPhoto = photo;
    notifyListeners();
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
    }

    if (newIndex != currentIndex) {
      setSelectedPhoto(photos[newIndex]);
    }
  }

  void handlePhotoTap(Photo photo) {
    setSelectedPhoto(photo);
  }
}
