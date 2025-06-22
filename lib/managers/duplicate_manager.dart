import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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
          final hash = await _calculateFileHash(photo.path);
          if (hash != null) {
            hashGroups.putIfAbsent(hash, () => []).add(photo);

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

  Future<String?> _calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint('Hash calculation error for $filePath: $e');
      return null;
    }
  }

  void selectAllExceptFirstInAllGroups() {
    for (final group in _duplicateGroups) {
      group.selectAllExceptFirst();
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
