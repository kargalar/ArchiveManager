import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/photo.dart';
import '../models/indexing_state.dart';
import 'filter_manager.dart';

class PhotoManager extends ChangeNotifier {
  final Box<Photo> _photoBox;
  final List<Photo> _photos = [];
  FilterManager? _filterManager;

  // Indexing state tracking
  bool _isIndexing = false;
  double _indexingProgress = 0.0;
  int _totalPhotosToIndex = 0;
  int _indexedPhotosCount = 0;

  // Stream controller for indexing updates
  final _indexingController = StreamController<IndexingState>.broadcast();
  Stream<IndexingState> get indexingStream => _indexingController.stream;

  // Getters for indexing state
  bool get isIndexing => _isIndexing;
  double get indexingProgress => _indexingProgress;
  String get indexingStatus => _isIndexing ? 'İndeksleniyor: ${(_indexingProgress * 100).toStringAsFixed(1)}% ($_indexedPhotosCount/$_totalPhotosToIndex)' : '';

  // Method to get current indexing state
  IndexingState get currentIndexingState => IndexingState(
        isIndexing: _isIndexing,
        progress: _indexingProgress,
        processedCount: _indexedPhotosCount,
        totalCount: _totalPhotosToIndex,
      );

  PhotoManager(this._photoBox);

  void setFilterManager(FilterManager filterManager) {
    _filterManager = filterManager;
  }

  List<Photo> get photos => _photos;

  // Optimized photo loading with batching
  Future<void> loadPhotosFromFolder(String path) async {
    _photos.clear();

    // Show loading indicator
    notifyListeners();

    // Load photos asynchronously
    await _loadPhotosFromSingleFolder(path);

    // Notify listeners that photos are loaded
    notifyListeners();

    // Klasör seçildiğinde indeksleme başlatmıyoruz
    // İndeksleme sadece yeni klasör eklendiğinde otomatik olarak başlatılacak
  }

  // Load photos from multiple folders
  Future<void> loadPhotosFromMultipleFolders(List<String> paths) async {
    _photos.clear();

    // Show loading indicator
    notifyListeners();

    // Use a Set to track unique photo paths
    final Set<String> addedPhotoPaths = {};

    // Load photos from each folder
    for (var path in paths) {
      await _loadPhotosFromSingleFolder(path, addedPhotoPaths);

      // Notify after each folder to show progress - only if not indexing
      if (!_isIndexing) {
        notifyListeners();
      }
    }

    // Final notification after all photos are loaded
    notifyListeners();

    // Klasör seçildiğinde indeksleme başlatmıyoruz
    // İndeksleme sadece yeni klasör eklendiğinde otomatik olarak başlatılacak
  }

  // Start the indexing process in the background
  void _startIndexing(List<Photo> photos) {
    // First filter out photos that already have dimensions loaded
    final List<Photo> photosNeedingDimensions = photos.where((photo) => !photo.dimensionsLoaded || photo.width <= 0 || photo.height <= 0).toList();

    // If no photos need dimensions, return early
    if (photosNeedingDimensions.isEmpty) {
      debugPrint('No photos need dimensions, skipping indexing');
      _isIndexing = false;
      _indexingProgress = 1.0;

      // Update the stream with completed state
      _indexingController.add(currentIndexingState);

      // İndeksleme tamamlandığında sadece stream'i güncelle, notifyListeners() çağırma
      return;
    }

    // Set indexing state
    _isIndexing = true;
    _indexingProgress = 0.0;
    _totalPhotosToIndex = photosNeedingDimensions.length;
    _indexedPhotosCount = 0;

    // Update the stream with initial state
    _indexingController.add(currentIndexingState);

    // İndeksleme başladığında sadece stream'i güncelle, notifyListeners() çağırma

    debugPrint('Starting indexing for ${photosNeedingDimensions.length} photos');

    // Process photos one by one
    _processPhotosOneByOne(photosNeedingDimensions);
  }

  // Load dimensions one by one to prevent UI freezing and memory leaks
  void _processPhotosOneByOne(List<Photo> photos) {
    // Process one photo at a time
    int totalPhotos = photos.length;
    int processedCount = 0;
    int cacheCleanupCounter = 0;

    Future<void> processOneByOne() async {
      if (processedCount >= totalPhotos) {
        debugPrint('Finished indexing for all photos');
        _isIndexing = false;
        _indexingProgress = 1.0;

        // Update the stream with completed state
        _indexingController.add(currentIndexingState);

        // İndeksleme tamamlandığında sadece stream'i güncelle, notifyListeners() çağırma
        // Bu sayede UI gereksiz yere yeniden render edilmeyecek
        return;
      }

      // Process just one photo
      Photo photo = photos[processedCount];

      // Process this photo
      if (_filterManager != null) {
        await _filterManager!.loadActualDimensions(photo);
      }

      // Increment cache cleanup counter
      cacheCleanupCounter++;

      // Clear image cache every 5 photos to prevent memory buildup
      if (cacheCleanupCounter >= 5) {
        cacheCleanupCounter = 0;

        // Clear image cache to prevent memory leaks
        try {
          ImageCache().clear();
          ImageCache().clearLiveImages();

          // Only clear PaintingBinding if it's available
          if (WidgetsBinding.instance is PaintingBinding) {
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
          }
        } catch (e) {
          // Ignore errors during cache clearing
        }
      }

      processedCount++;
      _indexedPhotosCount = processedCount;
      _indexingProgress = processedCount / totalPhotos;

      // Update the stream with current progress after each photo
      // Sadece stream'i güncelle, notifyListeners() çağırma
      _indexingController.add(currentIndexingState);

      // Log progress more frequently since we're processing one by one
      if (processedCount % 20 == 0 || processedCount == totalPhotos) {
        final percentage = (_indexingProgress * 100).toStringAsFixed(1);
        debugPrint('Indexed $processedCount/$totalPhotos photos ($percentage%)');
      }

      // Allow UI to update between photos and give more time for GC
      // Shorter delay since we're only processing one photo at a time
      await Future.delayed(const Duration(milliseconds: 20));

      // Process next photo
      await processOneByOne();
    }

    // Start processing one by one
    Future.microtask(processOneByOne);
  }

  // Helper method to load photos from a single folder - optimized version
  Future<void> _loadPhotosFromSingleFolder(String path, [Set<String>? addedPhotoPaths, List<Photo>? targetList]) async {
    final directory = Directory(path);
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif'];

    try {
      // Create a map of existing photos for faster lookup
      final Map<String, Photo> existingPhotos = {};
      for (var photo in _photoBox.values) {
        existingPhotos[photo.path] = photo;
      }

      // Tüm dosyaları bir seferde bul (recursive olarak)
      debugPrint('Klasördeki tüm dosyalar taranıyor: $path');
      final List<FileSystemEntity> allFiles = directory.listSync(recursive: true);
      debugPrint('Toplam dosya sayısı: ${allFiles.length}');

      // Sadece resim dosyalarını filtrele
      final List<File> imageFiles = [];
      for (var file in allFiles) {
        if (file is File) {
          final extension = file.path.toLowerCase().split('.').last;
          if (imageExtensions.contains('.$extension')) {
            // Skip if this photo path has already been added
            if (addedPhotoPaths != null && addedPhotoPaths.contains(file.path)) {
              continue;
            }
            imageFiles.add(file);
          }
        }
      }

      debugPrint('Toplam resim dosyası sayısı: ${imageFiles.length}');

      // Tüm resim dosyalarını bir seferde işle (batch olmadan)
      for (var file in imageFiles) {
        // Use the map for faster lookup instead of firstWhere
        final photo = existingPhotos[file.path] ??
            Photo(
              path: file.path,
              dateModified: file.statSync().modified,
            );

        // Add to Hive box if it's a new photo
        if (!existingPhotos.containsKey(file.path)) {
          _photoBox.add(photo);
          existingPhotos[file.path] = photo; // Update the map
        }

        // Add to photos list and track the path if needed
        if (targetList != null) {
          targetList.add(photo);
        } else {
          _photos.add(photo);
        }
        addedPhotoPaths?.add(file.path);
      }

      debugPrint('Tüm fotoğraflar yüklendi. Toplam: ${targetList?.length ?? _photos.length}');
    } catch (e) {
      debugPrint('Error loading photos from folder $path: $e');
    }
  }

  void toggleFavorite(Photo photo) {
    debugPrint('Toggling favorite for photo: ${photo.path}, current state: ${photo.isFavorite}');

    // Toggle favorite
    photo.toggleFavorite();

    debugPrint('Favorite toggled to: ${photo.isFavorite}');

    // İndeksleme sırasında sadece ilgili fotoğrafı güncellemek için özel bir notifyListeners çağrısı yapıyoruz
    // Bu sayede tüm grid yeniden render edilmeyecek
    if (_isIndexing) {
      // Stream'i güncelle
      _indexingController.add(currentIndexingState);

      // Sadece ilgili fotoğrafı güncellemek için özel bir notifyListeners çağrısı yapıyoruz
      // Bu sayede tüm grid yeniden render edilmeyecek
      // Ancak bu değişikliği yapmak için HomeViewModel'i değiştirmemiz gerekiyor
      // Şimdilik normal notifyListeners çağrısı yapıyoruz
      notifyListeners();
    } else {
      // İndeksleme yoksa normal notifyListeners çağrısı yapıyoruz
      notifyListeners();
    }
  }

  void setRating(Photo photo, int rating) {
    debugPrint('Setting rating for photo: ${photo.path}, current rating: ${photo.rating}, new rating: $rating');

    // Set new rating
    if (photo.rating == rating) {
      photo.setRating(0);
      debugPrint('Rating cleared to 0');
    } else {
      photo.setRating(rating);
      debugPrint('Rating set to $rating');
    }

    // İndeksleme sırasında sadece ilgili fotoğrafı güncellemek için özel bir notifyListeners çağrısı yapıyoruz
    // Bu sayede tüm grid yeniden render edilmeyecek
    if (_isIndexing) {
      // Stream'i güncelle
      _indexingController.add(currentIndexingState);

      // Sadece ilgili fotoğrafı güncellemek için özel bir notifyListeners çağrısı yapıyoruz
      // Bu sayede tüm grid yeniden render edilmeyecek
      // Ancak bu değişikliği yapmak için HomeViewModel'i değiştirmemiz gerekiyor
      // Şimdilik normal notifyListeners çağrısı yapıyoruz
      notifyListeners();
    } else {
      // İndeksleme yoksa normal notifyListeners çağrısı yapıyoruz
      notifyListeners();
    }
  }

  void deletePhoto(Photo photo) {
    try {
      if (Platform.isWindows) {
        final file = File(photo.path);
        if (file.existsSync()) {
          // Use shell command to move file to recycle bin
          Process.run('powershell', [
            '-command',
            '''
            Add-Type -AssemblyName Microsoft.VisualBasic
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
              '${photo.path.replaceAll('\\', '\\\\')}',
              'OnlyErrorDialogs',
              'SendToRecycleBin'
            )
            '''
          ]);
        }
      }

      // Mark as recycled and save before removing from list
      photo.isRecycled = true;
      photo.save();

      // Remove from photos list if it exists
      if (_photos.contains(photo)) {
        _photos.remove(photo);
      }

      // Also remove from box to ensure persistence
      final box = Hive.box<Photo>('photos');
      final boxPhoto = box.values.firstWhere(
        (p) => p.path == photo.path,
        orElse: () => photo,
      );
      boxPhoto.isRecycled = true;
      boxPhoto.save();

      // Her durumda notifyListeners çağır
      notifyListeners();

      // Eğer indexleme devam ediyorsa, stream'i de güncelle
      if (_isIndexing) {
        _indexingController.add(currentIndexingState);
      }
    } catch (e) {
      debugPrint('Error moving photo to recycle bin: $e');
    }
  }

  void restorePhoto(Photo photo) {
    try {
      photo.isRecycled = false;
      photo.save();

      // Her durumda notifyListeners çağır
      notifyListeners();

      // Eğer indexleme devam ediyorsa, stream'i de güncelle
      if (_isIndexing) {
        _indexingController.add(currentIndexingState);
      }
    } catch (e) {
      debugPrint('Error restoring photo: $e');
    }
  }

  void permanentlyDeletePhoto(Photo photo) {
    try {
      final file = File(photo.path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      photo.delete();

      // Her durumda notifyListeners çağır
      notifyListeners();

      // Eğer indexleme devam ediyorsa, stream'i de güncelle
      if (_isIndexing) {
        _indexingController.add(currentIndexingState);
      }
    } catch (e) {
      debugPrint('Error permanently deleting photo: $e');
    }
  }

  void clearPhotos() {
    _photos.clear();

    // Her durumda notifyListeners çağır
    notifyListeners();

    // Eğer indexleme devam ediyorsa, stream'i de güncelle
    if (_isIndexing) {
      _indexingController.add(currentIndexingState);
    }
  }

  // Tüm fotoğrafları bir kez indeksle - uygulama başlangıcında çağrılır
  void startGlobalIndexing() {
    if (!_isIndexing) {
      debugPrint('Starting global indexing for all photos in the database');

      // Sadece indexlenmemiş fotoğrafları al
      final unindexedPhotos = _photoBox.values.where((photo) => !photo.dimensionsLoaded || photo.width <= 0 || photo.height <= 0).toList();

      if (unindexedPhotos.isNotEmpty) {
        debugPrint('Found ${unindexedPhotos.length} unindexed photos, starting indexing');
        // İndeksleme işlemini başlat
        _startIndexing(unindexedPhotos);
      } else {
        debugPrint('No unindexed photos found, skipping global indexing');
      }
    } else {
      debugPrint('Indexing already in progress, skipping global indexing');
    }
  }

  // Belirli bir klasördeki fotoğrafları indeksle - yeni klasör eklendiğinde çağrılır
  Future<void> indexFolderPhotos(String folderPath) async {
    if (_isIndexing) {
      debugPrint('Indexing already in progress, will index folder $folderPath later');
      return;
    }

    debugPrint('Indexing photos in folder: $folderPath');

    // Klasördeki fotoğrafları yükle
    final List<Photo> folderPhotos = [];
    await _loadPhotosFromSingleFolder(folderPath, null, folderPhotos);

    // İndeksleme işlemini başlat
    if (_filterManager != null && folderPhotos.isNotEmpty) {
      debugPrint('Starting indexing for ${folderPhotos.length} photos in folder: $folderPath');
      _startIndexing(folderPhotos);
    } else {
      debugPrint('No photos to index in folder: $folderPath');
    }
  }

  @override
  void dispose() {
    _indexingController.close();
    super.dispose();
  }
}
