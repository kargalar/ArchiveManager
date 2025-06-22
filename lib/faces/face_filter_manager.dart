import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../faces/face.dart';

class FaceFilterManager extends ChangeNotifier {
  Face? selectedFace;
  final Map<String, int> _facePhotoCount = {};
  List<Face> _uniqueFaces = [];

  List<Face> get uniqueFaces => _uniqueFaces;
  Map<String, int> get facePhotoCount => _facePhotoCount;

  void selectFace(Face face) {
    selectedFace = face;
    notifyListeners();
  }

  void clearSelectedFace() {
    selectedFace = null;
    notifyListeners();
  }

  void resetFilters({List<Photo>? photos}) {
    clearSelectedFace();

    // Reset face detection status for all photos if provided
    if (photos != null) {
      for (final photo in photos) {
        photo.faceDetectionDone = false;
        photo.faces.clear();
        photo.faceTrackingIds.clear();
        photo.save();
      }
      debugPrint('Face detection reset for ${photos.length} photos');
    }

    notifyListeners();
  }

  // Analyze all photos and create face statistics
  void analyzeFaces(List<Photo> allPhotos) {
    _facePhotoCount.clear();
    _uniqueFaces.clear();

    final Map<String, Face> uniqueFaceMap = {};

    for (final photo in allPhotos) {
      for (final face in photo.faces) {
        // Use face ID to group same faces
        if (!uniqueFaceMap.containsKey(face.id)) {
          uniqueFaceMap[face.id] = face;
          _facePhotoCount[face.id] = 1;
        } else {
          _facePhotoCount[face.id] = (_facePhotoCount[face.id] ?? 0) + 1;
        }
      }
    }

    _uniqueFaces = uniqueFaceMap.values.toList();
    // Sort by photo count (most photos first)
    _uniqueFaces.sort((a, b) => (_facePhotoCount[b.id] ?? 0).compareTo(_facePhotoCount[a.id] ?? 0));

    notifyListeners();
  }

  List<Photo> filterPhotosByFace(List<Photo> photos) {
    if (selectedFace == null) return photos;

    return photos.where((photo) {
      return photo.faces.any((face) => face.id == selectedFace!.id);
    }).toList();
  }
}
