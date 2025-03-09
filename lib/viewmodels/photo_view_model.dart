import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/photo.dart';

class PhotoViewModel extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final List<String> _folders = [];
  String? _selectedFolder;
  List<Photo> _photos = [];

  PhotoViewModel(this._photoBox);

  List<String> get folders => _folders;
  String? get selectedFolder => _selectedFolder;
  List<Photo> get photos => _photos;

  void addFolder(String path) {
    if (!_folders.contains(path)) {
      _folders.add(path);
      notifyListeners();
    }
  }

  void selectFolder(String? path) {
    _selectedFolder = path;
    if (path != null) {
      _loadPhotosFromFolder(path);
    } else {
      _photos.clear();
    }
    notifyListeners();
  }

  void _loadPhotosFromFolder(String path) {
    // TODO: Implement photo loading from the selected folder
    _photos.clear();
    notifyListeners();
  }

  void toggleFavorite(Photo photo) {
    photo.toggleFavorite();
    notifyListeners();
  }

  void setRating(Photo photo, int rating) {
    photo.setRating(rating);
    notifyListeners();
  }

  void addTag(Photo photo, String tag) {
    photo.addTag(tag);
    notifyListeners();
  }

  void removeTag(Photo photo, String tag) {
    photo.removeTag(tag);
    notifyListeners();
  }

  void handleKeyEvent(RawKeyEvent event, Photo? selectedPhoto) {
    if (event is RawKeyDownEvent && selectedPhoto != null) {
      final key = event.logicalKey.keyLabel;
      if (key.length == 1 && RegExp(r'[1-5]').hasMatch(key)) {
        setRating(selectedPhoto, int.parse(key));
      }
    }
  }
}