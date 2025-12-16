// input_controller.dart: Tüm klavye ve fare input'larını merkezi olarak yönetir
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/home_view_model.dart';
import '../managers/folder_manager.dart';
import '../managers/photo_manager.dart';
import '../managers/tag_manager.dart';
import '../managers/settings_manager.dart';
import '../managers/filter_manager.dart';
import '../views/widgets/full_screen_image.dart';

/// InputController: Tüm input'ları ve kısayolları merkezi olarak yönetir
class InputController {
  // Kısayol tanımları
  static const Map<String, String> keyboardShortcuts = {
    'F11': 'Tam ekran aç/kapat',
    'Enter': 'Seçili fotoğrafı tam ekranda aç',
    'Arrow Keys': 'Fotoğraflar arasında gezin',
    'F': 'Seçili fotoğrafı favori olarak işaretle',
    'Space': 'Masaüstü arkaplanı ayarla',
    'Delete': 'Seçili fotoğrafı sil',
    'Escape': 'Seçimleri temizle',
    'Ctrl+A': 'Tüm fotoğrafları seç',
    '0-9': 'Fotoğraf derecelendirmesi ayarla',
    'Ctrl+Scroll': 'Grid satır başına fotoğraf sayısını değiştir',
  };

  /// Klavye event'ini işle
  bool handleKeyboardEvent(KeyEvent event) {
    // Arrow key'leri tekrar etmeye izin ver; diğerleri sadece KeyDown'da tetiklensin
    final isArrowKey = _isArrowKey(event.logicalKey);
    if (event is KeyDownEvent || (event is KeyRepeatEvent && isArrowKey)) {
      return true; // Event işlenebilir
    }
    return false;
  }

  /// Fare scroll event'ini işle
  void handlePointerEvent(
    PointerEvent event,
    BuildContext context,
    SettingsManager settingsManager,
  ) {
    if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
      final delta = event.scrollDelta.dy;
      if (delta < 0) {
        settingsManager.setPhotosPerRow(settingsManager.photosPerRow + 1);
      } else if (delta > 0) {
        settingsManager.setPhotosPerRow(settingsManager.photosPerRow - 1);
      }
    }
  }

  /// Klavye olayını ViewModele iletme öncesi kontrol et
  void processKeyEvent(
    KeyEvent event,
    BuildContext context,
    HomeViewModel homeViewModel,
  ) {
    if (!context.mounted) return;

    final folderManager = context.read<FolderManager>();
    final photoManager = context.read<PhotoManager>();
    final tagManager = context.read<TagManager>();
    final settingsManager = context.read<SettingsManager>();
    final filterManager = context.read<FilterManager>();

    // F11 - Tam ekran değiştir (buraya odak alan)
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      settingsManager.toggleFullscreen();
      return;
    }

    // Enter - Seçili fotoğrafı tam ekranda aç
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && homeViewModel.selectedPhoto != null && !FullScreenImage.isActive) {
      _openFullscreenImage(context, homeViewModel, filterManager, photoManager, tagManager);
      return;
    }

    // ViewModel'e diğer key event'lerini gönder
    homeViewModel.handleKeyEvent(event, context, folderManager, photoManager, tagManager);
  }

  /// Arrow key kontrolü
  bool _isArrowKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown;
  }

  /// Tam ekran resmini aç
  void _openFullscreenImage(
    BuildContext context,
    HomeViewModel homeViewModel,
    FilterManager filterManager,
    PhotoManager photoManager,
    TagManager tagManager,
  ) {
    final filteredPhotos = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags);

    Navigator.of(context).push(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'fullscreen_image'),
        pageBuilder: (context, animation, secondaryAnimation) => FullScreenImage(
          photo: homeViewModel.selectedPhoto!,
          filteredPhotos: filteredPhotos,
        ),
      ),
    );
  }

  /// Wallpaper ayarla
  Future<void> setAsWallpaper(BuildContext context, String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resim dosyası bulunamadı')),
          );
        }
        return;
      }

      final absolutePath = file.absolute.path.replaceAll('/', '\\');

      final script = '''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
[Wallpaper]::SystemParametersInfo(20, 0, "$absolutePath", 3)
''';

      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-Command', script],
      );

      if (result.exitCode == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Masaüstü arkaplanı başarıyla ayarlandı')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${result.stderr}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }
}
