import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
// Use window_manager on desktop platforms, and a stub implementation on web
import 'package:window_manager/window_manager.dart' if (dart.library.html) '../utils/web_window_manager.dart';
import '../models/settings.dart';
import '../models/folder.dart';
import '../models/photo.dart';
import '../models/tag.dart';
import '../models/color_adapter.dart';
import '../models/keyboard_key_adapter.dart';
import '../models/datetime_adapter.dart';

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

  // Tüm verileri sıfırla
  Future<bool> resetAllData() async {
    try {
      debugPrint('Resetting all data...');

      // Tüm Hive kutularını kapat
      await Hive.close();

      // Hive veritabanı dizinini al
      final appDocDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDocDir.path}/Archive Manager';

      // Tüm Hive dosyalarını sil
      final directory = Directory(hivePath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        debugPrint('Deleted Hive directory: $hivePath');

        // Yeni bir dizin oluştur
        await directory.create(recursive: true);
        debugPrint('Created new Hive directory');

        return true;
      }

      debugPrint('Hive directory not found: $hivePath');
      return false;
    } catch (e) {
      debugPrint('Error resetting data: $e');
      return false;
    }
  }

  // Export application data to a JSON file
  Future<bool> exportData() async {
    try {
      debugPrint('Exporting application data...');

      // Create a map to hold all data
      final Map<String, dynamic> exportData = {};

      // Export settings
      if (_settingsBox != null && _settingsBox!.isNotEmpty) {
        final settings = _settingsBox!.getAt(0);
        if (settings != null) {
          exportData['settings'] = {
            'photosPerRow': settings.photosPerRow,
            'showImageInfo': settings.showImageInfo,
            'fullscreenAutoNext': settings.fullscreenAutoNext,
            'dividerPosition': settings.dividerPosition,
            'folderMenuWidth': settings.folderMenuWidth,
          };
        }
      }

      // Export folders
      final folderBox = Hive.box<Folder>('folders');
      if (folderBox.isNotEmpty) {
        final List<Map<String, dynamic>> folders = [];
        for (var i = 0; i < folderBox.length; i++) {
          final folder = folderBox.getAt(i);
          if (folder != null) {
            folders.add({
              'path': folder.path,
              'subFolders': folder.subFolders,
              'isFavorite': folder.isFavorite,
            });
          }
        }
        exportData['folders'] = folders;
      }

      // Export tags
      final tagBox = Hive.box<Tag>('tags');
      if (tagBox.isNotEmpty) {
        final List<Map<String, dynamic>> tags = [];
        for (var i = 0; i < tagBox.length; i++) {
          final tag = tagBox.getAt(i);
          if (tag != null) {
            tags.add({
              'name': tag.name,
              'colorValue': tag.colorValue,
              'shortcutKeyId': tag.shortcutKeyId,
              'id': tag.id,
            });
          }
        }
        exportData['tags'] = tags;
      }

      // Export photos (basic info only to keep file size manageable)
      final photoBox = Hive.box<Photo>('photos');
      if (photoBox.isNotEmpty) {
        final List<Map<String, dynamic>> photos = [];
        for (var i = 0; i < photoBox.length; i++) {
          final photo = photoBox.getAt(i);
          if (photo != null) {
            final photoTags = photo.tags.map((tag) => tag.id).toList();
            photos.add({
              'path': photo.path,
              'isFavorite': photo.isFavorite,
              'rating': photo.rating,
              'isRecycled': photo.isRecycled,
              'tags': photoTags,
              'width': photo.width,
              'height': photo.height,
              'dateModified': photo.dateModified?.millisecondsSinceEpoch,
              'dimensionsLoaded': photo.dimensionsLoaded,
            });
          }
        }
        exportData['photos'] = photos;
      }

      // Convert to JSON
      final jsonData = json.encode(exportData);

      // Get save location from user
      final saveLocation = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Archive Manager Data',
        fileName: 'archive_manager_export.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (saveLocation != null) {
        // Write to file
        final file = File(saveLocation);
        await file.writeAsString(jsonData);
        debugPrint('Data exported to: $saveLocation');
        return true;
      } else {
        debugPrint('Export cancelled by user');
        return false;
      }
    } catch (e) {
      debugPrint('Error exporting data: $e');
      return false;
    }
  }

  // Import application data from a JSON file
  Future<bool> importData() async {
    try {
      debugPrint('Importing application data...');

      // Get file location from user
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Import Archive Manager Data',
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('Import cancelled by user');
        return false;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        debugPrint('Invalid file path');
        return false;
      }

      // Read file
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File does not exist: $filePath');
        return false;
      }

      // Just check if the file is valid JSON
      final jsonString = await file.readAsString();
      json.decode(jsonString); // Validate JSON format

      // Process the imported data
      return await processImportedData(filePath);
    } catch (e) {
      debugPrint('Error importing data: $e');
      return false;
    }
  }

  // Process the imported data
  Future<bool> processImportedData(String filePath) async {
    try {
      // Read file
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> importData = json.decode(jsonString);

      // Tüm Hive kutularını kapat
      await Hive.close();

      // Hive veritabanı dizinini al
      final appDocDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDocDir.path}/Archive Manager';

      // Geçici bir dizine JSON dosyasını kopyala
      final tempDir = await Directory('$hivePath/temp').create(recursive: true);
      final tempFile = File('${tempDir.path}/import_data.json');
      await tempFile.writeAsString(jsonString);

      // Tüm Hive dosyalarını sil (settings hariç)
      final directory = Directory(hivePath);
      if (await directory.exists()) {
        // Temp dizini hariç tüm dosya ve klasörleri sil
        final entities = await directory.list().toList();
        for (var entity in entities) {
          if (entity.path != tempDir.path) {
            await entity.delete(recursive: true);
          }
        }

        debugPrint('Deleted Hive directories for import');

        // Yeni bir dizin oluştur
        await Directory(hivePath).create(recursive: true);
        debugPrint('Created new Hive directory');

        // Hive'ı yeniden başlat
        await Hive.initFlutter(hivePath);

        // Adapterleri kaydet
        Hive.registerAdapter(ColorAdapter());
        Hive.registerAdapter(DateTimeAdapter());
        Hive.registerAdapter(PhotoAdapter());
        Hive.registerAdapter(FolderAdapter());
        Hive.registerAdapter(TagAdapter());
        Hive.registerAdapter(LogicalKeyboardKeyAdapter());
        Hive.registerAdapter(SettingsAdapter());

        // Kutuları aç
        final settingsBox = await Hive.openBox<Settings>('settings');
        final folderBox = await Hive.openBox<Folder>('folders');
        final tagBox = await Hive.openBox<Tag>('tags');
        final photoBox = await Hive.openBox<Photo>('photos');

        // Varsayılan ayarları oluştur
        if (settingsBox.isEmpty) {
          await settingsBox.add(Settings());
        }

        // Import settings
        if (importData.containsKey('settings')) {
          final settingsData = importData['settings'] as Map<String, dynamic>;
          final settings = settingsBox.getAt(0);
          if (settings != null) {
            settings.photosPerRow = settingsData['photosPerRow'] ?? 4;
            settings.showImageInfo = settingsData['showImageInfo'] ?? true;
            settings.fullscreenAutoNext = settingsData['fullscreenAutoNext'] ?? false;
            settings.dividerPosition = settingsData['dividerPosition'] ?? 0.3;
            settings.folderMenuWidth = settingsData['folderMenuWidth'] ?? 250;
            await settings.save();
          }
        }

        // Import folders
        if (importData.containsKey('folders')) {
          final foldersData = importData['folders'] as List<dynamic>;
          for (var folderData in foldersData) {
            final data = folderData as Map<String, dynamic>;
            final path = data['path'] as String;
            final subFolders = (data['subFolders'] as List<dynamic>).cast<String>();
            final isFavorite = data['isFavorite'] as bool;

            final folder = Folder(
              path: path,
              subFolders: subFolders,
              isFavorite: isFavorite,
            );

            await folderBox.add(folder);
          }
        }

        // Import tags
        final Map<String, Tag> importedTagsById = {};
        if (importData.containsKey('tags')) {
          final tagsData = importData['tags'] as List<dynamic>;
          for (var tagData in tagsData) {
            final data = tagData as Map<String, dynamic>;
            final id = data['id'] as String;
            final name = data['name'] as String;
            final colorValue = data['colorValue'] as int;
            final shortcutKeyId = data['shortcutKeyId'] as int;

            final tag = Tag(
              name: name,
              color: Color(colorValue),
              shortcutKey: LogicalKeyboardKey(shortcutKeyId),
              id: id,
            );

            final tagKey = await tagBox.add(tag);
            final addedTag = tagBox.get(tagKey);
            if (addedTag != null) {
              importedTagsById[id] = addedTag;
            }
          }
        }

        // Import photos
        if (importData.containsKey('photos')) {
          final photosData = importData['photos'] as List<dynamic>;
          for (var photoData in photosData) {
            final data = photoData as Map<String, dynamic>;
            final path = data['path'] as String;

            // Check if file exists
            final photoFile = File(path);
            if (!await photoFile.exists()) {
              debugPrint('Photo file does not exist, skipping: $path');
              continue;
            }

            // Create new photo
            final photo = Photo(
              path: path,
              isFavorite: data['isFavorite'] as bool,
              rating: data['rating'] as int,
              isRecycled: data['isRecycled'] as bool,
              width: data['width'] as int,
              height: data['height'] as int,
              dimensionsLoaded: data['dimensionsLoaded'] as bool,
            );

            // Set date modified if available
            if (data['dateModified'] != null) {
              photo.dateModified = DateTime.fromMillisecondsSinceEpoch(data['dateModified'] as int);
            }

            await photoBox.add(photo);

            // Add tags to photo
            if (data.containsKey('tags')) {
              final tagIds = (data['tags'] as List<dynamic>).cast<String>();
              for (var tagId in tagIds) {
                if (importedTagsById.containsKey(tagId)) {
                  if (!photo.tags.contains(importedTagsById[tagId])) {
                    photo.tags.add(importedTagsById[tagId]!);
                  }
                }
              }
              await photo.save();
            }
          }
        }

        // Geçici dosyayı sil
        await tempDir.delete(recursive: true);

        return true;
      }

      debugPrint('Hive directory not found: $hivePath');
      return false;
    } catch (e) {
      debugPrint('Error processing imported data: $e');
      return false;
    }
  }
}
