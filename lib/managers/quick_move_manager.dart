import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/photo.dart';
import '../models/quick_move_destination.dart';
import '../managers/photo_manager.dart';

class QuickMoveManager extends ChangeNotifier {
  Box<QuickMoveDestination>? _destBox;

  QuickMoveManager() {
    _initBox();
  }

  Box<QuickMoveDestination>? get destBox => _destBox;
  List<QuickMoveDestination> get destinations => _destBox?.values.toList() ?? [];

  Future<void> _initBox() async {
    _destBox = await Hive.openBox<QuickMoveDestination>('quick_move_destinations');
    notifyListeners();
  }

  // Kısayol tuşunun başka bir hedef tarafından kullanılıp kullanılmadığını kontrol et
  QuickMoveDestination? getDestinationByShortcutKey(LogicalKeyboardKey shortcutKey, {String? excludeId}) {
    for (var dest in destinations) {
      if (dest.shortcutKey == shortcutKey && dest.id != excludeId) {
        return dest;
      }
    }
    return null;
  }

  Future<void> addDestination(QuickMoveDestination dest) async {
    await _destBox?.add(dest);
    notifyListeners();
  }

  Future<void> updateDestination(
    QuickMoveDestination dest,
    String newName,
    String newPath,
    Color newColor,
    LogicalKeyboardKey newShortcutKey,
  ) async {
    bool hasChanges = false;

    if (dest.name != newName) {
      dest.name = newName;
      hasChanges = true;
    }
    if (dest.path != newPath) {
      dest.path = newPath;
      hasChanges = true;
    }
    if (dest.color != newColor) {
      dest.color = newColor;
      hasChanges = true;
    }
    if (dest.shortcutKey != newShortcutKey) {
      dest.shortcutKey = newShortcutKey;
      hasChanges = true;
    }

    if (hasChanges) {
      await dest.save();
      notifyListeners();
    }
  }

  Future<void> deleteDestination(QuickMoveDestination dest) async {
    await dest.delete();
    notifyListeners();
  }

  // Seçili fotoğrafları hedefe taşı
  Future<int> movePhotosToDestination(
    List<Photo> photos,
    QuickMoveDestination dest,
    PhotoManager photoManager,
  ) async {
    int movedCount = 0;
    for (var photo in photos) {
      try {
        await photoManager.movePhotoToFolder(photo, dest.path);
        movedCount++;
      } catch (e) {
        debugPrint('Error moving photo ${photo.path} to ${dest.path}: $e');
      }
    }
    return movedCount;
  }
}
