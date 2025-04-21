import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:window_manager/window_manager.dart';
import '../models/settings.dart';

class SettingsManager extends ChangeNotifier {
  Box<Settings>? _settingsBox;
  int _photosPerRow = 4; // Default value
  double _dividerPosition = 0.3; // Default value
  bool _isInitialized = false;

  // Ayarlar kutusu başlatıldı mı?
  bool get isInitialized => _isInitialized;

  SettingsManager() {
    _initSettingsBox();
  }

  int get photosPerRow => _photosPerRow;
  bool get showImageInfo => _settingsBox?.getAt(0)?.showImageInfo ?? false;
  bool get fullscreenAutoNext => _settingsBox?.getAt(0)?.fullscreenAutoNext ?? false;
  double get dividerPosition => _dividerPosition;

  double? get windowWidth => _settingsBox?.getAt(0)?.windowWidth;
  double? get windowHeight => _settingsBox?.getAt(0)?.windowHeight;
  double? get windowLeft => _settingsBox?.getAt(0)?.windowLeft;
  double? get windowTop => _settingsBox?.getAt(0)?.windowTop;

  Future<void> _initSettingsBox() async {
    try {
      debugPrint('Initializing settings box...');
      _settingsBox = await Hive.openBox<Settings>('settings');

      if (_settingsBox!.isEmpty) {
        debugPrint('Settings box is empty, adding default settings');
        await _settingsBox!.add(Settings());
      } else {
        debugPrint('Settings box loaded successfully');
      }

      _photosPerRow = _settingsBox!.getAt(0)?.photosPerRow ?? 4;
      _dividerPosition = _settingsBox!.getAt(0)?.dividerPosition ?? 0.3;
      _isInitialized = true;
      debugPrint('Settings initialized: photosPerRow=$_photosPerRow, dividerPosition=$_dividerPosition');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing settings box: $e');
      _isInitialized = false;
    }
  }

  void setShowImageInfo(bool value) {
    if (!_isInitialized) {
      debugPrint('Cannot set showImageInfo: settings not initialized');
      return;
    }

    if (_settingsBox?.getAt(0) != null) {
      _settingsBox!.getAt(0)!.showImageInfo = value;
      _settingsBox!.getAt(0)!.save();
      notifyListeners();
    }
  }

  void setFullscreenAutoNext(bool value) {
    if (!_isInitialized) {
      debugPrint('Cannot set fullscreenAutoNext: settings not initialized');
      return;
    }

    if (_settingsBox?.getAt(0) != null) {
      _settingsBox!.getAt(0)!.fullscreenAutoNext = value;
      _settingsBox!.getAt(0)!.save();
      notifyListeners();
    }
  }

  void setPhotosPerRow(int value) {
    if (!_isInitialized) {
      debugPrint('Cannot set photosPerRow: settings not initialized');
      return;
    }

    if (value > 0) {
      _photosPerRow = value;

      if (_settingsBox?.getAt(0) != null) {
        _settingsBox!.getAt(0)!.photosPerRow = value;
        _settingsBox!.getAt(0)!.save();
        notifyListeners();
      }
    }
  }

  void setDividerPosition(double value) {
    if (!_isInitialized) {
      debugPrint('Cannot set dividerPosition: settings not initialized');
      // Yine de yerel değişkeni güncelle, daha sonra senkronize edilecek
      if (value >= 0.1 && value <= 0.3 && value != _dividerPosition) {
        _dividerPosition = value;
        notifyListeners();
      }
      return;
    }

    if (value >= 0.1 && value <= 0.3 && value != _dividerPosition) {
      _dividerPosition = value;

      if (_settingsBox?.getAt(0) != null) {
        final settings = _settingsBox!.getAt(0)!;
        if (settings.dividerPosition != value) {
          settings.dividerPosition = value;
          settings.save();
          debugPrint('Divider position saved: $value');
        }
      }

      notifyListeners();
    }
  }

  // Pencere konumunu ve boyutunu kaydet
  Future<void> saveWindowPosition() async {
    // Ayarlar kutusu başlatılmadıysa işlem yapma
    if (!_isInitialized) {
      debugPrint('Cannot save window position: settings not initialized');
      return;
    }

    if (_settingsBox?.getAt(0) != null) {
      final windowInfo = await windowManager.getBounds();
      final settings = _settingsBox!.getAt(0)!;

      // Sadece değerler değiştiğinde kaydet
      bool changed = false;

      if (settings.windowWidth != windowInfo.width) {
        settings.windowWidth = windowInfo.width;
        changed = true;
      }

      if (settings.windowHeight != windowInfo.height) {
        settings.windowHeight = windowInfo.height;
        changed = true;
      }

      if (settings.windowLeft != windowInfo.left) {
        settings.windowLeft = windowInfo.left;
        changed = true;
      }

      if (settings.windowTop != windowInfo.top) {
        settings.windowTop = windowInfo.top;
        changed = true;
      }

      if (changed) {
        await settings.save();
        debugPrint('Window position saved: ${windowInfo.width}x${windowInfo.height} at (${windowInfo.left},${windowInfo.top})');
      }
    }
  }

  // Kaydedilen pencere konumunu ve boyutunu uygula
  // Ayarlar başarıyla uygulandıysa true, aksi halde false döndürür
  Future<bool> restoreWindowPosition() async {
    // Ayarlar kutusu başlatılmadıysa bekle
    if (!_isInitialized) {
      debugPrint('Settings not initialized yet, waiting...');
      // 5 saniye boyunca 100ms aralıklarla kontrol et
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isInitialized) break;
      }

      // Hala başlatılmadıysa false döndür
      if (!_isInitialized) {
        debugPrint('Settings initialization timeout');
        return false;
      }
    }

    debugPrint('Restoring window position...');
    if (_settingsBox?.getAt(0) != null) {
      final width = _settingsBox?.getAt(0)?.windowWidth;
      final height = _settingsBox?.getAt(0)?.windowHeight;
      final left = _settingsBox?.getAt(0)?.windowLeft;
      final top = _settingsBox?.getAt(0)?.windowTop;

      if (width != null && height != null && left != null && top != null) {
        await windowManager.setBounds(Rect.fromLTWH(left, top, width, height));
        debugPrint('Window position restored: ${width}x$height at ($left,$top)');
        return true;
      }
    }

    debugPrint('No saved window position found');
    return false;
  }
}
