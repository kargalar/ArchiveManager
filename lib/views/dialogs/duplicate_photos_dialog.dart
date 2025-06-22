import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../managers/duplicate_manager.dart';
import '../../managers/photo_manager.dart';
import 'dart:io';

class DuplicatePhotosDialog extends StatefulWidget {
  const DuplicatePhotosDialog({super.key});

  @override
  State<DuplicatePhotosDialog> createState() => _DuplicatePhotosDialogState();
}

class _DuplicatePhotosDialogState extends State<DuplicatePhotosDialog> {
  late DuplicateManager _duplicateManager;
  bool _isDeletingFiles = false;

  @override
  void initState() {
    super.initState();
    _duplicateManager = DuplicateManager();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDuplicateScan();
    });
  }

  void _startDuplicateScan() {
    final photoManager = Provider.of<PhotoManager>(context, listen: false);
    _duplicateManager.scanForDuplicates(photoManager.photos);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _duplicateManager,
      child: Dialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 30),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve kontroller
              Row(
                children: [
                  const Icon(
                    Icons.content_copy,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Aynı Fotoğraflar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Consumer<DuplicateManager>(
                    builder: (context, duplicateManager, child) {
                      if (duplicateManager.isScanning) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              duplicateManager.selectAllExceptFirstInAllGroups();
                            },
                            icon: const Icon(Icons.select_all, size: 16),
                            label: const Text('İlk Hariç Tümünü Seç'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              duplicateManager.clearAllSelections();
                            },
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Seçimi Temizle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // İstatistikler ve durum
              Consumer<DuplicateManager>(
                builder: (context, duplicateManager, child) {
                  if (duplicateManager.isScanning) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: duplicateManager.scanProgress,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          duplicateManager.scanStatus,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      _buildStatCard(
                        'Toplam Grup',
                        duplicateManager.duplicateGroupsCount.toString(),
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Toplam Aynı Fotoğraf',
                        duplicateManager.totalDuplicates.toString(),
                        Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Silinmek Üzere Seçilen',
                        duplicateManager.totalSelectedForDeletion.toString(),
                        Colors.red,
                      ),
                      const Spacer(),
                      if (duplicateManager.totalSelectedForDeletion > 0)
                        ElevatedButton.icon(
                          onPressed: _isDeletingFiles ? null : _deleteSelectedFiles,
                          icon: _isDeletingFiles
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_forever, size: 16),
                          label: Text(_isDeletingFiles ? 'Siliniyor...' : 'Seçilenleri Sil (${duplicateManager.totalSelectedForDeletion})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Aynı fotoğraf grupları listesi
              Expanded(
                child: Consumer<DuplicateManager>(
                  builder: (context, duplicateManager, child) {
                    if (duplicateManager.isScanning) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Aynı fotoğraflar taranıyor...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    }

                    if (duplicateManager.duplicateGroups.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Harika! Aynı fotoğraf bulunamadı.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: duplicateManager.duplicateGroups.length,
                      itemBuilder: (context, index) {
                        final group = duplicateManager.duplicateGroups[index];
                        return _buildDuplicateGroup(group, index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateGroup(DuplicateGroup group, int groupIndex) {
    return Card(
      color: const Color.fromARGB(255, 40, 40, 40),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Grup ${groupIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${group.photos.length} fotoğraf',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    group.fileSizeFormatted,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    group.selectAllExceptFirst();
                    setState(() {});
                  },
                  child: const Text('İlk Hariç Seç'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: group.photos.length,
                itemBuilder: (context, photoIndex) {
                  final photo = group.photos[photoIndex];
                  final isSelected = group.selectedForDeletion[photoIndex];

                  return GestureDetector(
                    onTap: () {
                      group.toggleSelection(photoIndex);
                      setState(() {});
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.red : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(
                              File(photo.path),
                              width: 100,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 100,
                                  height: 120,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          if (photoIndex == 0)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ORİJİNAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedFiles() async {
    if (_isDeletingFiles) return;

    final selectedCount = _duplicateManager.totalSelectedForDeletion;
    if (selectedCount == 0) return;

    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 40, 40, 40),
        title: const Text(
          'Dosyaları Sil',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$selectedCount fotoğraf kalıcı olarak silinecek. Bu işlem geri alınamaz.\n\nDevam etmek istiyor musunuz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeletingFiles = true;
    });

    try {
      final deletedCount = await _duplicateManager.deleteSelectedDuplicates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount fotoğraf başarıyla silindi.'),
            backgroundColor: Colors.green,
          ),
        );

        // PhotoManager'ı güncelle
        final photoManager = Provider.of<PhotoManager>(context, listen: false);
        photoManager.removePhotosFromList(_duplicateManager.allSelectedPhotos);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya silme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingFiles = false;
        });
      }
    }
  }
}
