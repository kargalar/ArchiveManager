import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/photo.dart';
import 'photo_view_model.dart';

class HomeViewModel extends ChangeNotifier {
  Photo? _selectedPhoto;
  Photo? get selectedPhoto => _selectedPhoto;

  void setSelectedPhoto(Photo? photo) {
    _selectedPhoto = photo;
    notifyListeners();
  }

  void handleKeyEvent(
      RawKeyEvent event, BuildContext context, PhotoViewModel photoViewModel) {
    if (event is! RawKeyDownEvent) return;
    if (photoViewModel.photos.isEmpty) return;

    if (_selectedPhoto == null) {
      setSelectedPhoto(photoViewModel.photos[0]);
      return;
    }

    final currentIndex = photoViewModel.photos.indexOf(_selectedPhoto!);
    final photosPerRow = photoViewModel.photosPerRow;
    int newIndex = currentIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
      newIndex = currentIndex - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        currentIndex < photoViewModel.photos.length - 1) {
      newIndex = currentIndex + 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        currentIndex >= photosPerRow) {
      newIndex = currentIndex - photosPerRow;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        currentIndex + photosPerRow < photoViewModel.photos.length) {
      newIndex = currentIndex + photosPerRow;
    } else if (event.logicalKey == LogicalKeyboardKey.delete &&
        _selectedPhoto != null) {
      final currentIndex = photoViewModel.photos.indexOf(_selectedPhoto!);
      photoViewModel.deletePhoto(_selectedPhoto!);

      // Select next photo after deletion
      if (photoViewModel.photos.isNotEmpty) {
        final nextIndex = currentIndex < photoViewModel.photos.length
            ? currentIndex
            : photoViewModel.photos.length - 1;
        setSelectedPhoto(photoViewModel.photos[nextIndex]);
      } else {
        setSelectedPhoto(null);
      }
      return;
    }

    if (newIndex != currentIndex) {
      setSelectedPhoto(photoViewModel.photos[newIndex]);
    }
  }

  void handlePhotoTap(Photo photo) {
    setSelectedPhoto(photo);
  }
}
