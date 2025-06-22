import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/photo.dart';

class PhotoComparisonDialog extends StatefulWidget {
  final List<Photo> photos;
  final int groupIndex;

  const PhotoComparisonDialog({
    super.key,
    required this.photos,
    required this.groupIndex,
  });

  @override
  State<PhotoComparisonDialog> createState() => _PhotoComparisonDialogState();
}

class _PhotoComparisonDialogState extends State<PhotoComparisonDialog> {
  int _leftPhotoIndex = 0;
  int _rightPhotoIndex = 1;
  double _dividerPosition = 0.5;

  final TransformationController _leftController = TransformationController();
  final TransformationController _rightController = TransformationController();

  @override
  void initState() {
    super.initState();
    if (widget.photos.length < 2) {
      _rightPhotoIndex = 0;
    }
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.95,
        child: Column(
          children: [
            // Başlık ve kontroller
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color.fromARGB(255, 30, 30, 30),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.compare, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Fotoğraf Karşılaştırması - Grup ${widget.groupIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fotoğraf seçicileri
                  Row(
                    children: [
                      // Sol fotoğraf seçici
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sol Fotoğraf:',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            DropdownButton<int>(
                              value: _leftPhotoIndex,
                              dropdownColor: const Color.fromARGB(255, 50, 50, 50),
                              style: const TextStyle(color: Colors.white),
                              items: widget.photos.asMap().entries.map((entry) {
                                final index = entry.key;
                                final photo = entry.value;
                                final fileName = photo.path.split('\\').last;
                                final file = File(photo.path);
                                final fileSize = file.existsSync() ? file.lengthSync() : 0;
                                final fileSizeFormatted = _formatFileSize(fileSize);

                                return DropdownMenuItem<int>(
                                  value: index,
                                  child: Text(
                                    '$fileName ($fileSizeFormatted)',
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _leftPhotoIndex = value;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Sağ fotoğraf seçici
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sağ Fotoğraf:',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            DropdownButton<int>(
                              value: _rightPhotoIndex,
                              dropdownColor: const Color.fromARGB(255, 50, 50, 50),
                              style: const TextStyle(color: Colors.white),
                              items: widget.photos.asMap().entries.map((entry) {
                                final index = entry.key;
                                final photo = entry.value;
                                final fileName = photo.path.split('\\').last;
                                final file = File(photo.path);
                                final fileSize = file.existsSync() ? file.lengthSync() : 0;
                                final fileSizeFormatted = _formatFileSize(fileSize);

                                return DropdownMenuItem<int>(
                                  value: index,
                                  child: Text(
                                    '$fileName ($fileSizeFormatted)',
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _rightPhotoIndex = value;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Zoom ve pan kontrolleri
                ],
              ),
            ),

            // Karşılaştırma alanı
            Expanded(
              child: _buildSideBySideComparison(),
            ),

            // Alt bilgi paneli
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color.fromARGB(255, 30, 30, 30),
              child: Row(
                children: [
                  Expanded(child: _buildPhotoInfo(widget.photos[_leftPhotoIndex], 'Sol')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPhotoInfo(widget.photos[_rightPhotoIndex], 'Sağ')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySideComparison() {
    return Container(
      color: Colors.black,
      child: InteractiveViewer(
        transformationController: _leftController,
        minScale: 0.1,
        maxScale: 5.0,
        onInteractionUpdate: (details) {
          // Sync zoom and pan with right photo
          _rightController.value = _leftController.value;
        },
        child: Stack(
          children: [
            // Ana fotoğraf görüntüleme alanı
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Sağ fotoğraf (arka plan - her zaman görünür)
                  Positioned.fill(
                    child: Image.file(
                      File(widget.photos[_rightPhotoIndex].path),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 64,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Sol fotoğraf (üst katman - clip edilecek)
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _LeftImageClipper(_dividerPosition),
                      child: Image.file(
                        File(widget.photos[_leftPhotoIndex].path),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[600],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 64,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Sürüklenebilir ayırıcı çizgi - şimdi transform edilmiş alan içinde
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Positioned(
                              left: constraints.maxWidth * _dividerPosition - 2,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  // Global koordinatları widget koordinatlarına çevir
                                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                  final localPosition = renderBox.globalToLocal(details.globalPosition);

                                  setState(() {
                                    final newPosition = localPosition.dx / constraints.maxWidth;
                                    _dividerPosition = newPosition.clamp(0.05, 0.95);
                                  });
                                },
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeLeftRight,
                                  child: Container(
                                    width: 2,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black, width: 0.2),
                                      borderRadius: BorderRadius.circular(2),
                                      color: Colors.white.withAlpha(150),
                                    ),
                                  ),
                                ),
                              ),
                            ), // Sol üst köşe - sol fotoğraf indikator
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SOL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),

                            // Sağ üst köşe - sağ fotoğraf indikator
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SAĞ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoInfo(Photo photo, String side) {
    final file = File(photo.path);
    final fileName = photo.path.split('\\').last;
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final fileSizeFormatted = _formatFileSize(fileSize);
    final lastModified = file.existsSync() ? file.lastModifiedSync() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$side Fotoğraf',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Dosya: $fileName',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Boyut: $fileSizeFormatted',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (photo.width > 0 && photo.height > 0)
          Text(
            'Çözünürlük: ${photo.width}x${photo.height}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        if (lastModified != null)
          Text(
            'Tarih: ${lastModified.day}/${lastModified.month}/${lastModified.year}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Custom clipper to show only left portion of the image
class _LeftImageClipper extends CustomClipper<Rect> {
  final double dividerPosition;

  _LeftImageClipper(this.dividerPosition);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      0,
      0,
      size.width * dividerPosition,
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    return oldClipper is _LeftImageClipper && oldClipper.dividerPosition != dividerPosition;
  }
}
