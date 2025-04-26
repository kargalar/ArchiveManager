import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
// Use window_manager on desktop platforms, and a stub implementation on web
import 'package:window_manager/window_manager.dart' if (dart.library.html) '../utils/web_window_manager.dart';
import '../models/settings.dart';

class SettingsManager extends ChangeNotifier {
  Box<Settings>? _settingsBox;
  int _photosPerRow = 4; // Default value
  double _dividerPosition = 0.3; // Default value
  double _folderMenuWidth = 250; // Default value
  bool _isInitialized = false;

  // Desktop platformda mıyız?
  final bool _isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // Ayarlar kutusu başlatıldı mı?
  bool get isInitialized => _isInitialized;

  SettingsManager() {
    _initSettingsBox();
  }

  int get photosPerRow => _photosPerRow;
  bool get showImageInfo => _settingsBox?.getAt(0)?.showImageInfo ?? false;
  bool get fullscreenAutoNext => _settingsBox?.getAt(0)?.fullscreenAutoNext ?? false;
  double get dividerPosition => _dividerPosition;
  double get folderMenuWidth => _folderMenuWidth;
  bool get isFullscreen => _settingsBox?.getAt(0)?.isFullscreen ?? false;

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
      _folderMenuWidth = _settingsBox!.getAt(0)?.folderMenuWidth ?? 250;
      _isInitialized = true;
      debugPrint('Settings initialized: photosPerRow=$_photosPerRow, dividerPosition=$_dividerPosition, folderMenuWidth=$_folderMenuWidth');
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

  // Tam ekran modunu aç/kapat ve ayarları kaydet
  Future<void> toggleFullscreen() async {
    if (!_isInitialized) {
      debugPrint('Cannot toggle fullscreen: settings not initialized');
      return;
    }

    if (_settingsBox?.getAt(0) != null) {
      final settings = _settingsBox!.getAt(0)!;
      final newValue = !settings.isFullscreen;

      // Sadece desktop platformlarda tam ekran modunu değiştir
      if (_isDesktop) {
        await windowManager.setFullScreen(newValue);
      }

      // Ayarları kaydet
      settings.isFullscreen = newValue;
      await settings.save();

      debugPrint('Fullscreen toggled: $newValue');
      notifyListeners();
    }
  }

  // Tam ekran modunu ayarla ve kaydet
  Future<void> setFullscreen(bool value) async {
    if (!_isInitialized) {
      debugPrint('Cannot set fullscreen: settings not initialized');
      return;
    }

    if (_settingsBox?.getAt(0) != null) {
      final settings = _settingsBox!.getAt(0)!;

      // Değer zaten aynıysa işlem yapma
      if (settings.isFullscreen == value) return;

      // Sadece desktop platformlarda tam ekran modunu değiştir
      if (_isDesktop) {
        await windowManager.setFullScreen(value);
      }

      // Ayarları kaydet
      settings.isFullscreen = value;
      await settings.save();

      debugPrint('Fullscreen set to: $value');
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

  void setFolderMenuWidth(double value) {
    if (!_isInitialized) {
      debugPrint('Cannot set folderMenuWidth: settings not initialized');
      // Still update the local variable, will be synchronized later
      if (value >= 200 && value <= 400 && value != _folderMenuWidth) {
        _folderMenuWidth = value;
        notifyListeners();
      }
      return;
    }

    if (value >= 200 && value <= 400 && value != _folderMenuWidth) {
      _folderMenuWidth = value;

      if (_settingsBox?.getAt(0) != null) {
        final settings = _settingsBox!.getAt(0)!;
        if (settings.folderMenuWidth != value) {
          settings.folderMenuWidth = value;
          settings.save();
          debugPrint('Folder menu width saved: $value');
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

    // Sadece desktop platformlarda pencere konumunu kaydet
    if (!_isDesktop) {
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
    // Sadece desktop platformlarda pencere konumunu geri yükle
    if (!_isDesktop) {
      return false;
    }

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
