// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo.dart';

/// FullScreen görünümü için ViewModel
/// Cache yönetimi ve fotoğraf geçişlerini yönetir
class FullScreenViewModel extends ChangeNotifier {
  Photo _currentPhoto;
  final List<Photo> _allPhotos;

  // Cache monitoring
  Timer? _cacheMonitorTimer;
  int _cachedImagesCount = 0;
  int _cachedImagesSizeMB = 0;

  // Detaylı cache durumu
  final Map<String, bool> _photoCacheStatus = {}; // path -> isCached

  // Cache yapılandırması
  static const int CACHE_PREVIOUS_COUNT = 2; // Geçmiş 2 fotoğraf
  static const int CACHE_NEXT_COUNT = 5; // Gelecek 5 fotoğraf

  // 🎯 Performans optimizasyonu: Tam ekran için maksimum çözünürlük
  // 4K monitör için yeterli, ancak gereksiz büyük dosyaları küçültür
  // Sadece width veriyoruz - Flutter otomatik olarak aspect ratio'yu korur!
  static const int MAX_CACHE_WIDTH = 3840; // 4K genişlik

  // Şu anda cache'lenmiş fotoğrafların path'leri
  final Set<String> _cachedPhotoPaths = {};

  // ÖNEMLİ: Provider referanslarını hafızada tutarak tam eşleşme (instance identity) sağlıyoruz
  final Map<String, ImageProvider> _imageProviders = {};

  // 🔑 ÖNEMLI: Mevcut fotoğraf için ImageProvider - Cache'den okumak için aynı instance kullanılmalı!
  ImageProvider? _currentImageProvider;
  String? _currentImageProviderPath; // Provider'ın path'ini tutmak için

  FullScreenViewModel({
    required Photo initialPhoto,
    required List<Photo> allPhotos,
  })  : _currentPhoto = initialPhoto,
        _allPhotos = allPhotos {
    // Ensure _currentPhoto is the same instance as the one in _allPhotos.
    // Photo does not override ==, so relying on identity breaks indexOf-based navigation.
    final normalizedIndex = _indexOfPath(initialPhoto.path);
    if (normalizedIndex >= 0) {
      _currentPhoto = _allPhotos[normalizedIndex];
    }

    // İlk fotoğraf zaten gösterilecek, cache'de say
    _cachedPhotoPaths.add(_currentPhoto.path);
    _photoCacheStatus[_currentPhoto.path] = true;

    // İlk ImageProvider'ı oluştur (boyutlandırılmış, aspect ratio korunur)
    final initialProvider = ResizeImage(
      FileImage(File(_currentPhoto.path)),
      width: MAX_CACHE_WIDTH,
      // height belirtilmedi - aspect ratio korunur!
    );
    _imageProviders[_currentPhoto.path] = initialProvider;
    _currentImageProvider = initialProvider;
    _currentImageProviderPath = _currentPhoto.path;
  }

  // Getters
  Photo get currentPhoto => _currentPhoto;
  List<Photo> get allPhotos => _allPhotos;
  int get cachedImagesCount => _cachedImagesCount;
  int get cachedImagesSizeMB => _cachedImagesSizeMB;
  int get currentIndex => _indexOfPath(_currentPhoto.path);
  bool get canGoNext => currentIndex >= 0 && currentIndex < _allPhotos.length - 1;
  bool get canGoPrevious => currentIndex > 0;

  int _indexOfPath(String path) {
    return _allPhotos.indexWhere((p) => p.path == path);
  }

  // 🔑 ÖNEMLI: Mevcut fotoğraf için ImageProvider - Cache'den yükleme için aynı instance'ı kullan
  ImageProvider get currentImageProvider {
    // Eğer photo değiştiyse, yeni provider oluştur veya cache'den al
    if (_currentImageProvider == null || _currentImageProviderPath != _currentPhoto.path) {
      if (_imageProviders.containsKey(_currentPhoto.path)) {
        _currentImageProvider = _imageProviders[_currentPhoto.path];
      } else {
        final newProvider = ResizeImage(
          FileImage(File(_currentPhoto.path)),
          width: MAX_CACHE_WIDTH,
          // height belirtilmedi - aspect ratio korunur!
        );
        _imageProviders[_currentPhoto.path] = newProvider;
        _currentImageProvider = newProvider;
      }
      _currentImageProviderPath = _currentPhoto.path;
    }
    return _currentImageProvider!;
  }

  // Cache status bilgileri
  List<Map<String, dynamic>> getCacheStatusList() {
    final idx = currentIndex;
    final List<Map<String, dynamic>> statusList = [];

    // Önceki 2 fotoğraf
    for (int i = CACHE_PREVIOUS_COUNT; i >= 1; i--) {
      if (idx - i >= 0) {
        final photo = _allPhotos[idx - i];
        statusList.add({
          'label': 'PREV-$i',
          'fileName': photo.path.split('\\').last,
          'isCached': _cachedPhotoPaths.contains(photo.path),
          'path': photo.path,
        });
      }
    }

    // Mevcut fotoğraf
    statusList.add({
      'label': 'CURRENT',
      'fileName': _currentPhoto.path.split('\\').last,
      'isCached': true, // Mevcut fotoğraf her zaman görüntüleniyor
      'path': _currentPhoto.path,
    });

    // Sonraki 5 fotoğraf
    for (int i = 1; i <= CACHE_NEXT_COUNT; i++) {
      if (idx + i < _allPhotos.length) {
        final photo = _allPhotos[idx + i];
        statusList.add({
          'label': 'NEXT+$i',
          'fileName': photo.path.split('\\').last,
          'isCached': _cachedPhotoPaths.contains(photo.path),
          'path': photo.path,
        });
      }
    }

    return statusList;
  }

  /// Image cache'i yapılandır
  void configureImageCache(BuildContext context) {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = 100;
    imageCache.maximumSizeBytes = 500 * 1024 * 1024; // 500 MB

    debugPrint('🖼️ Image Cache Configured: maxSize=${imageCache.maximumSize}, maxBytes=${imageCache.maximumSizeBytes ~/ (1024 * 1024)}MB');
    debugPrint('📊 Current Cache: ${imageCache.currentSize} images, ${imageCache.currentSizeBytes ~/ (1024 * 1024)}MB');
  }

  /// Cache monitörünü başlat
  void startCacheMonitoring() {
    _cacheMonitorTimer?.cancel();
    _cacheMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final cache = PaintingBinding.instance.imageCache;
      _cachedImagesCount = cache.currentSize;
      _cachedImagesSizeMB = cache.currentSizeBytes ~/ (1024 * 1024);
      notifyListeners();
    });
  }

  /// Akıllı cache yönetimi - sadece gerekli fotoğrafları cache'le
  Future<void> manageCacheForCurrentPhoto(BuildContext context) async {
    final idx = currentIndex;

    debugPrint('\n🔄 Managing cache for: ${_currentPhoto.path.split('\\').last}');
    debugPrint('📍 Current index: $idx / ${_allPhotos.length}');

    // Hangi fotoğrafların cache'de olması gerektiğini belirle
    final Set<String> requiredPhotoPaths = {};

    // Mevcut fotoğraf (zaten gösteriliyor)
    requiredPhotoPaths.add(_currentPhoto.path);

    // Geçmiş 2 fotoğraf
    for (int i = 1; i <= CACHE_PREVIOUS_COUNT; i++) {
      if (idx - i >= 0) {
        requiredPhotoPaths.add(_allPhotos[idx - i].path);
      }
    }

    // Gelecek 5 fotoğraf
    for (int i = 1; i <= CACHE_NEXT_COUNT; i++) {
      if (idx + i < _allPhotos.length) {
        requiredPhotoPaths.add(_allPhotos[idx + i].path);
      }
    }

    debugPrint('📋 Required in cache: ${requiredPhotoPaths.length} photos');
    debugPrint('   Range: ${idx - CACHE_PREVIOUS_COUNT} to ${idx + CACHE_NEXT_COUNT}');

    // Gereksiz cache'leri temizle (opsiyonel - Flutter bunu otomatik yapar ama biz kontrol ediyoruz)
    final unnecessaryPaths = _cachedPhotoPaths.difference(requiredPhotoPaths);
    if (unnecessaryPaths.isNotEmpty) {
      debugPrint('🗑️ Removing ${unnecessaryPaths.length} unnecessary cached images');
      // Flutter'ın cache'ini direkt temizleyemeyiz, ama takip listesini güncelleyebiliriz
      _cachedPhotoPaths.removeAll(unnecessaryPaths);
      // Provider bellek referanslarını temizle
      for (final path in unnecessaryPaths) {
        _imageProviders.remove(path);
      }
    }

    // Yeni fotoğrafları cache'le - HEPSİNİ AWAIT ET!
    final photosToCache = requiredPhotoPaths.difference(_cachedPhotoPaths);
    if (photosToCache.isNotEmpty) {
      debugPrint('➕ Caching ${photosToCache.length} new photos');

      final imageCache = PaintingBinding.instance.imageCache;
      debugPrint('📊 Before cache: ${imageCache.currentSize} images, ${imageCache.currentSizeBytes ~/ (1024 * 1024)}MB');

      // SIRA İLE her bir fotoğrafı cache'le ve BEKLE!
      for (final photoPath in photosToCache) {
        final fileName = photoPath.split('\\').last;

        try {
          debugPrint('   📥 Caching: $fileName');

          // ImageProvider instance'ını oluştur ve sakla
          final provider = ResizeImage(
            FileImage(File(photoPath)),
            width: MAX_CACHE_WIDTH,
          );
          _imageProviders[photoPath] = provider;

          // 🎯 PERFORMANS: Boyutlandırılmış versiyonu cache'le (decode daha hızlı!)
          // Sakladığımız özdeş instance üzerinden cache'i çağırıyoruz
          await precacheImage(
            provider,
            context,
          );
          _cachedPhotoPaths.add(photoPath);
          _photoCacheStatus[photoPath] = true;
          notifyListeners(); // Her cache işleminde UI'ı güncelle
          debugPrint('   ✅ Cached: $fileName');
        } catch (e) {
          debugPrint('   ❌ Cache failed for $fileName: $e');
          _photoCacheStatus[photoPath] = false;
        }
      }

      debugPrint('📊 After cache: ${imageCache.currentSize} images, ${imageCache.currentSizeBytes ~/ (1024 * 1024)}MB');
    } else {
      debugPrint('✅ All required photos already cached');
    }

    debugPrint('📋 Total tracked in cache: ${_cachedPhotoPaths.length} photos\n');
  }

  /// Sonraki fotoğrafa geç
  Future<void> moveToNext(BuildContext context) async {
    final idx = currentIndex;
    if (idx < 0 || idx >= _allPhotos.length - 1) return;

    _currentPhoto = _allPhotos[idx + 1];
    _currentPhoto.markViewed();
    notifyListeners();

    // Cache'i güncelle
    await manageCacheForCurrentPhoto(context);
  }

  /// Önceki fotoğrafa geç
  Future<void> moveToPrevious(BuildContext context) async {
    final idx = currentIndex;
    if (idx <= 0) return;

    _currentPhoto = _allPhotos[idx - 1];
    _currentPhoto.markViewed();
    notifyListeners();

    // Cache'i güncelle
    await manageCacheForCurrentPhoto(context);
  }

  /// Belirli bir fotoğrafa geç
  Future<void> moveToPhoto(BuildContext context, Photo photo) async {
    final idx = _indexOfPath(photo.path);
    if (idx < 0) return;

    _currentPhoto = _allPhotos[idx];
    _currentPhoto.markViewed();
    notifyListeners();

    // Cache'i güncelle
    await manageCacheForCurrentPhoto(context);
  }

  /// Mevcut fotoğrafı sil ve bir sonrakine geç
  Future<void> deleteCurrentAndMoveNext(BuildContext context) async {
    final idx = currentIndex;
    if (idx < 0 || idx >= _allPhotos.length) {
      return;
    }

    final deletedPath = _currentPhoto.path;
    _allPhotos.removeAt(idx);
    _cachedPhotoPaths.remove(deletedPath);
    _photoCacheStatus.remove(deletedPath);

    if (_allPhotos.isEmpty) {
      return; // View'da handle edilecek
    }

    // Aynı indeksi kullan, eğer son fotoğraf silindiyse bir öncekine geç
    final nextIdx = idx < _allPhotos.length ? idx : _allPhotos.length - 1;
    _currentPhoto = _allPhotos[nextIdx];
    _currentPhoto.markViewed();
    notifyListeners();

    // Cache'i güncelle
    await manageCacheForCurrentPhoto(context);
  }

  @override
  void dispose() {
    _cacheMonitorTimer?.cancel();
    _cachedPhotoPaths.clear();
    super.dispose();
  }
}
