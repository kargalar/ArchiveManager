import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/settings.dart';

class SettingsManager extends ChangeNotifier {
  Box<Settings>? _settingsBox;
  int _photosPerRow = 4; // Default value

  SettingsManager() {
    _initSettingsBox();
  }

  int get photosPerRow => _photosPerRow;
  bool get showImageInfo => _settingsBox?.getAt(0)?.showImageInfo ?? false;
  bool get fullscreenAutoNext => _settingsBox?.getAt(0)?.fullscreenAutoNext ?? false;

  Future<void> _initSettingsBox() async {
    _settingsBox = await Hive.openBox<Settings>('settings');
    if (_settingsBox!.isEmpty) {
      await _settingsBox!.add(Settings());
    }
    _photosPerRow = _settingsBox!.getAt(0)?.photosPerRow ?? 4;
    notifyListeners();
  }

  void setShowImageInfo(bool value) {
    _settingsBox?.getAt(0)?.showImageInfo = value;
    _settingsBox?.getAt(0)?.save();
    notifyListeners();
  }

  void setFullscreenAutoNext(bool value) {
    _settingsBox?.getAt(0)?.fullscreenAutoNext = value;
    _settingsBox?.getAt(0)?.save();
    notifyListeners();
  }

  void setPhotosPerRow(int value) {
    if (value > 0) {
      _photosPerRow = value;
      _settingsBox?.getAt(0)?.photosPerRow = value;
      _settingsBox?.getAt(0)?.save();
      notifyListeners();
    }
  }
}
