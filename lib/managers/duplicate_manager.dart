import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/photo.dart';

class DuplicateGroup {
  final String hash;
  final List<Photo> photos;
  late List<bool> selectedForDeletion;

  DuplicateGroup({required this.hash, required this.photos}) {
    selectedForDeletion = List.generate(photos.length, (index) => false);
  }

  int get fileSize => photos.isNotEmpty ? File(photos.first.path).lengthSync() : 0;

  String get fileSizeFormatted {
    final bytes = fileSize;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void toggleSelection(int index) {
    if (index >= 0 && index < selectedForDeletion.length) {
      selectedForDeletion[index] = !selectedForDeletion[index];
    }
  }

  void selectAllExceptFirst() {
    for (int i = 1; i < selectedForDeletion.length; i++) {
      selectedForDeletion[i] = true;
    }
    if (selectedForDeletion.isNotEmpty) {
      selectedForDeletion[0] = false;
    }
  }

  void selectAllExceptLargest() {
    // Önce tüm seçimleri temizle
    for (int i = 0; i < selectedForDeletion.length; i++) {
      selectedForDeletion[i] = false;
    }

    if (photos.isEmpty) return;

    // En büyük dosyayı bul
    int largestIndex = 0;
    int largestSize = 0;

    for (int i = 0; i < photos.length; i++) {
      try {
        final file = File(photos[i].path);
        if (file.existsSync()) {
          final size = file.lengthSync();
          if (size > largestSize) {
            largestSize = size;
            largestIndex = i;
          }
        }
      } catch (e) {
        // Dosya okunamıyorsa geç
        continue;
      }
    }

    // En büyük dosya hariç diğerlerini seç
    for (int i = 0; i < selectedForDeletion.length; i++) {
      if (i != largestIndex) {
        selectedForDeletion[i] = true;
      }
    }
  }

  List<Photo> get selectedPhotos {
    final selected = <Photo>[];
    for (int i = 0; i < photos.length; i++) {
      if (selectedForDeletion[i]) {
        selected.add(photos[i]);
      }
    }
    return selected;
  }

  int get selectedCount => selectedForDeletion.where((selected) => selected).length;
}

class DuplicateManager extends ChangeNotifier {
  List<DuplicateGroup> _duplicateGroups = [];
  bool _isScanning = false;
  bool _shouldCancelScan = false;
  double _scanProgress = 0.0;
  String _scanStatus = '';
  int _totalFilesToScan = 0;
  int _scannedFiles = 0;

  List<DuplicateGroup> get duplicateGroups => _duplicateGroups;
  bool get isScanning => _isScanning;
  double get scanProgress => _scanProgress;
  String get scanStatus => _scanStatus;
  int get totalDuplicates => _duplicateGroups.fold(0, (sum, group) => sum + group.photos.length);
  int get duplicateGroupsCount => _duplicateGroups.length;

  void cancelScan() {
    _shouldCancelScan = true;
  }

  Future<void> scanForDuplicates(List<Photo> photos) async {
    if (_isScanning) return;

    _isScanning = true;
    _shouldCancelScan = false;
    _scanProgress = 0.0;
    _scanStatus = 'Tarama başlatılıyor...';
    _totalFilesToScan = photos.length;
    _scannedFiles = 0;
    _duplicateGroups.clear();
    notifyListeners();

    try {
      final Map<String, List<Photo>> hashGroups = {};

      for (int i = 0; i < photos.length && !_shouldCancelScan; i++) {
        final photo = photos[i];
        _scanStatus = 'Taranıyor: ${photo.path.split('\\').last}';
        _scannedFiles = i + 1;
        _scanProgress = _scannedFiles / _totalFilesToScan;
        try {
          final hash = await _calculateImageHash(photo.path);
          if (hash != null) {
            // Mevcut hash'ler ile benzerlik kontrolü yap
            String? matchingKey;
            for (final existingKey in hashGroups.keys) {
              if (_areHashesSimilar(existingKey, hash)) {
                matchingKey = existingKey;
                break;
              }
            }

            if (matchingKey != null) {
              // Benzer hash bulundu, bu gruba ekle
              hashGroups[matchingKey]!.add(photo);
            } else {
              // Yeni grup oluştur
              hashGroups[hash] = [photo];
            }

            // Gerçek zamanlı olarak aynı fotoğrafları güncelle
            _updateDuplicateGroups(hashGroups);
          }
        } catch (e) {
          debugPrint('Dosya hash hesaplanamadı: ${photo.path} - $e');
        }

        // Her 5 dosyada bir UI'ı güncelle ve kısa mola ver
        if (i % 5 == 0) {
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      if (_shouldCancelScan) {
        _scanStatus = 'Tarama iptal edildi';
      } else {
        // Final güncelleme - sadece birden fazla fotoğrafı olan grupları al
        _updateDuplicateGroups(hashGroups);
        _scanStatus = 'Tarama tamamlandı';
      }
    } catch (e) {
      _scanStatus = 'Tarama hatası: $e';
      debugPrint('Duplicate scan error: $e');
    } finally {
      _isScanning = false;
      _shouldCancelScan = false;
      if (!_shouldCancelScan) {
        _scanProgress = 1.0;
      }
      notifyListeners();
    }
  }

  void _updateDuplicateGroups(Map<String, List<Photo>> hashGroups) {
    // Sadece birden fazla fotoğrafı olan grupları al
    _duplicateGroups = hashGroups.entries.where((entry) => entry.value.length > 1).map((entry) => DuplicateGroup(hash: entry.key, photos: entry.value)).toList();

    // Gruplari dosya boyutuna göre sırala (büyükten küçüğe)
    _duplicateGroups.sort((a, b) => b.fileSize.compareTo(a.fileSize));
  }

  // Gelişmiş duplicate detection - hem file hash hem de perceptual hash kullanıyor
  Future<String?> _calculateImageHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // Önce dosya hash'ini hesapla (tam kopya tespiti için)
      final bytes = await file.readAsBytes();
      final fileHash = md5.convert(bytes).toString();

      // Perceptual hash hesapla (benzer görüntü tespiti için)
      String? perceptualHash;
      try {
        final image = img.decodeImage(bytes);
        if (image != null) {
          perceptualHash = _calculatePerceptualHash(image);
        }
      } catch (e) {
        debugPrint('Perceptual hash calculation failed for $filePath: $e');
      } // Composite hash oluştur: file_hash|perceptual_hash
      return '$fileHash|${perceptualHash ?? 'null'}';
    } catch (e) {
      debugPrint('Image hash calculation error for $filePath: $e');
      return null;
    }
  }

  // Gelişmiş perceptual hash (DCT tabanlı - daha hassas)
  String _calculatePerceptualHash(img.Image image) {
    // Daha büyük boyuta indirgele (64x64) - çok daha fazla detay için
    final resized = img.copyResize(image, width: 64, height: 64);

    // Gri tonlamaya çevir
    final grayscale = img.grayscale(resized);

    // Multi-level block analysis
    final hashes = <String>[];

    // 8x8 blocks (64 total)
    hashes.add(_calculateBlockHash(grayscale, 8, 64));

    // 16x16 blocks (16 total) - more general features
    hashes.add(_calculateBlockHash(grayscale, 16, 64));

    // Gradient-based hash
    hashes.add(_calculateGradientHash(grayscale));

    return hashes.join(':');
  }

  String _calculateBlockHash(img.Image grayscale, int blockSize, int imageSize) {
    final blockCount = (imageSize / blockSize).floor();
    final blockAverages = <double>[];

    for (int by = 0; by < blockCount; by++) {
      for (int bx = 0; bx < blockCount; bx++) {
        double sum = 0;
        int count = 0;

        for (int y = by * blockSize; y < (by + 1) * blockSize && y < imageSize; y++) {
          for (int x = bx * blockSize; x < (bx + 1) * blockSize && x < imageSize; x++) {
            final pixel = grayscale.getPixel(x, y);
            sum += pixel.luminance * 255;
            count++;
          }
        }

        if (count > 0) {
          blockAverages.add(sum / count);
        }
      }
    }

    if (blockAverages.isEmpty) return '';

    // Genel ortalama
    final average = blockAverages.reduce((a, b) => a + b) / blockAverages.length;

    // Hash oluştur
    final hash = StringBuffer();
    for (final blockAvg in blockAverages) {
      hash.write(blockAvg > average ? '1' : '0');
    }

    return hash.toString();
  }

  String _calculateGradientHash(img.Image grayscale) {
    final gradients = <double>[];

    // Calculate gradients across the image
    for (int y = 1; y < 63; y += 2) {
      for (int x = 1; x < 63; x += 2) {
        final center = grayscale.getPixel(x, y);
        final right = grayscale.getPixel(x + 1, y);
        final bottom = grayscale.getPixel(x, y + 1);

        final horizontalGrad = (right.luminance - center.luminance).abs();
        final verticalGrad = (bottom.luminance - center.luminance).abs();

        gradients.add((horizontalGrad + verticalGrad) * 255);
      }
    }

    if (gradients.isEmpty) return '';

    final average = gradients.reduce((a, b) => a + b) / gradients.length;
    final hash = StringBuffer();

    for (final grad in gradients) {
      hash.write(grad > average ? '1' : '0');
    }

    return hash.toString();
  } // Gelişmiş hash karşılaştırması

  int _hammingDistance(String hash1, String hash2) {
    // Yeni hash formatı: "8x8blocks:16x16blocks:gradients"
    final parts1 = hash1.split(':');
    final parts2 = hash2.split(':');

    if (parts1.length != 3 || parts2.length != 3) {
      // Basit hash formatı için fallback
      if (hash1.length != hash2.length) return hash1.length;

      int distance = 0;
      for (int i = 0; i < hash1.length; i++) {
        if (hash1[i] != hash2[i]) distance++;
      }
      return distance;
    }

    // Her bir hash tipini karşılaştır ve ağırlıklı toplam hesapla
    final block8Distance = _simpleHammingDistance(parts1[0], parts2[0]);
    final block16Distance = _simpleHammingDistance(parts1[1], parts2[1]);
    final gradientDistance = _simpleHammingDistance(parts1[2], parts2[2]);

    // Ağırlıklı toplam: 8x8 bloklar en önemli, gradientler orta, 16x16 bloklar genel yapı için
    final weightedDistance = (block8Distance * 0.5 + gradientDistance * 0.3 + block16Distance * 0.2);

    return weightedDistance.round();
  }

  int _simpleHammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) return hash1.length;

    int distance = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) distance++;
    }
    return distance;
  }

  bool _areHashesSimilar(String hash1, String hash2, {int threshold = 25}) {
    final parts1 = hash1.split('|');
    final parts2 = hash2.split('|');

    if (parts1.length != 2 || parts2.length != 2) return false;

    final fileHash1 = parts1[0];
    final fileHash2 = parts2[0];
    final perceptualHash1 = parts1[1];
    final perceptualHash2 = parts2[1];

    // Tam kopya kontrolü (aynı dosya)
    if (fileHash1 == fileHash2) return true;

    // Perceptual hash kontrolü (benzer görüntü)
    if (perceptualHash1 != 'null' && perceptualHash2 != 'null') {
      final distance = _hammingDistance(perceptualHash1, perceptualHash2);

      debugPrint('Comparing perceptual hashes:');
      debugPrint('Hash1: ${perceptualHash1.substring(0, 20)}...');
      debugPrint('Hash2: ${perceptualHash2.substring(0, 20)}...');
      debugPrint('Distance: $distance (threshold: $threshold)');

      // Gelişmiş threshold - composite hash için ayarlandı
      return distance <= threshold;
    }

    return false;
  }

  void selectAllExceptFirstInAllGroups() {
    for (final group in _duplicateGroups) {
      group.selectAllExceptFirst();
    }
    notifyListeners();
  }

  void selectAllExceptLargestInAllGroups() {
    for (final group in _duplicateGroups) {
      group.selectAllExceptLargest();
    }
    notifyListeners();
  }

  void clearAllSelections() {
    for (final group in _duplicateGroups) {
      for (int i = 0; i < group.selectedForDeletion.length; i++) {
        group.selectedForDeletion[i] = false;
      }
    }
    notifyListeners();
  }

  int get totalSelectedForDeletion {
    return _duplicateGroups.fold(0, (sum, group) => sum + group.selectedCount);
  }

  List<Photo> get allSelectedPhotos {
    final selected = <Photo>[];
    for (final group in _duplicateGroups) {
      selected.addAll(group.selectedPhotos);
    }
    return selected;
  }

  Future<int> deleteSelectedDuplicates() async {
    int deletedCount = 0;
    final photosToDelete = allSelectedPhotos;

    for (final photo in photosToDelete) {
      try {
        final file = File(photo.path);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
          debugPrint('Deleted duplicate: ${photo.path}');
        }
      } catch (e) {
        debugPrint('Failed to delete duplicate: ${photo.path} - $e');
      }
    }

    // Silinen fotoğrafları gruplardan kaldır
    _duplicateGroups.removeWhere((group) {
      group.photos.removeWhere((photo) => photosToDelete.contains(photo));
      return group.photos.length <= 1;
    });

    // Seçimleri güncelle
    for (final group in _duplicateGroups) {
      group.selectedForDeletion = List.generate(group.photos.length, (index) => false);
    }

    notifyListeners();
    return deletedCount;
  }

  void clearResults() {
    _duplicateGroups.clear();
    _scanProgress = 0.0;
    _scanStatus = '';
    _scannedFiles = 0;
    _totalFilesToScan = 0;
    notifyListeners();
  }
}
