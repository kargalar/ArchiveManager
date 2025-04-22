import 'dart:async';
import 'dart:io';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../../models/photo.dart';
import '../../managers/photo_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/settings_manager.dart';
import '../../managers/filter_manager.dart';
import '../../models/sort_state.dart';

// Fotoğrafı tam ekranda gösteren widget.
// Klavye ve mouse ile gezinme, etiketleme, puanlama ve bilgi gösterimi içerir.
class FullScreenImage extends StatefulWidget {
  final Photo photo;

  const FullScreenImage({super.key, required this.photo});

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> with TickerProviderStateMixin {
  late Photo _currentPhoto;
  late bool _autoNext;
  late bool _showInfo;
  late bool _zenMode;
  final FocusNode _focusNode = FocusNode();
  late final Box<Tag> _tagBox;
  final TransformationController _transformationController = TransformationController();
  final double _minScale = 1.0;
  final double _maxScale = 20.0;
  double _currentScale = 1.0;
  bool _isZooming = false;
  bool _isDragging = false;
  Offset? _lastDragPosition;

  // Sorting durumunu yönetmek için
  bool _isLoading = false;
  bool _isSorted = false;
  SortState? _lastResolutionSortState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final filterManager = Provider.of<FilterManager>(context);

    // Sıralama türü değiştiğinde _isSorted değişkenini sıfırla
    if (_lastResolutionSortState != filterManager.resolutionSortState) {
      _lastResolutionSortState = filterManager.resolutionSortState;
      _isSorted = false;
    }
  }

  List<Tag> get tags => _tagBox.values.toList();

  @override
  void initState() {
    super.initState();
    _currentPhoto = widget.photo;
    _tagBox = Hive.box<Tag>('tags');
    _showInfo = context.read<SettingsManager>().showImageInfo;
    _autoNext = context.read<SettingsManager>().fullscreenAutoNext;
    _zenMode = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  // Zoom durumunu animasyonlu şekilde sıfırlar
  void _resetZoom() {
    _currentScale = 1.0;
  }

  // Fare tekerleği ile zoom yapma işlemini gerçekleştirir
  void _handleMouseScroll(PointerScrollEvent event) {
    // Animasyon devam ediyorsa işlem yapma

    // Fare tekerleği yukarı kaydırıldığında zoom in, aşağı kaydırıldığında zoom out yapar
    final delta = event.scrollDelta.dy;
    // Mevcut dönüşüm matrisini al
    final Matrix4 currentTransformation = _transformationController.value;
    // Mevcut ölçeği al
    _currentScale = currentTransformation.getMaxScaleOnAxis();

    // Yeni ölçeği hesapla (tekerlek yukarı = zoom in, tekerlek aşağı = zoom out)
    // Daha küçük değişim faktörü kullanarak daha smooth zoom sağla
    double newScale = delta > 0 ? _currentScale / 1.05 : _currentScale * 1.05;

    // Ölçeği sınırla
    newScale = newScale.clamp(_minScale, _maxScale);

    // Ölçek değişmediyse işlem yapma
    if (newScale == _currentScale) return;

    // Zoom başladığında _isZooming'i true yap
    setState(() {
      _isZooming = true;
    });

    // Ekran boyutlarını al
    final Size viewSize = MediaQuery.of(context).size;

    // Fare pozisyonunu al (yerel koordinatlarda)
    final Offset focalPointScene = event.localPosition;

    // Ekranın merkezini hesapla
    final Offset viewCenter = Offset(viewSize.width / 2, viewSize.height / 2);

    // Fare pozisyonunun merkeze göre farkını hesapla
    final Offset focalPointDelta = focalPointScene - viewCenter;

    // Mevcut dönüşüm matrisinden kaydırma değerlerini al
    final Vector3 currentTranslation = currentTransformation.getTranslation();

    // Yeni dönüşüm matrisini hesapla
    final Matrix4 newTransformation = Matrix4.copy(currentTransformation);

    // Ölçekleme faktörünü hesapla
    final double scaleFactor = newScale / _currentScale;

    // Fare pozisyonuna göre zoom yap
    // 1. Mevcut kaydırma değerlerini sıfırla
    newTransformation.setTranslation(Vector3.zero());

    // 2. Fare pozisyonunu merkeze taşı
    newTransformation.translate(
      focalPointScene.dx,
      focalPointScene.dy,
    );

    // 3. Ölçekle
    newTransformation.scale(scaleFactor);

    // 4. Fare pozisyonunu geri taşı
    newTransformation.translate(
      -focalPointScene.dx,
      -focalPointScene.dy,
    );

    // 5. Mevcut kaydırma değerlerini geri ekle
    newTransformation.translate(
      currentTranslation.x,
      currentTranslation.y,
    );

    // 6. Fare pozisyonuna göre ek kaydırma ekle
    // Bu, zoom yaparken fare pozisyonunun sabit kalmasını sağlar
    newTransformation.translate(
      focalPointDelta.dx * (1 - scaleFactor),
      focalPointDelta.dy * (1 - scaleFactor),
    );

    // Mevcut ölçeği güncelle
    _currentScale = newScale;

    // Zoom işlemi tamamlandığında _isZooming'i false yap
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isZooming = false;
          // Cursor durumu otomatik olarak güncellenecek
          // (_currentScale değerine göre MouseRegion widget'i cursor'u güncelleyecek)
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoManager = Provider.of<PhotoManager>(context);
    final tagManager = Provider.of<TagManager>(context);
    final filterManager = Provider.of<FilterManager>(context);

    final filteredPhotos = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags);

    // Check if we need to sort by resolution
    if (filterManager.resolutionSortState != SortState.none && !_isSorted) {
      // Start sorting in the background if not already loading
      if (!_isLoading) {
        _isLoading = true;
        _isSorted = false;

        // Show loading indicator while sorting
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Sort photos in the background
          filterManager.sortPhotos(filteredPhotos).then((_) {
            // When sorting is complete, update the UI
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isSorted = true;
              });
            }
          });
        });
      }

      // Show loading indicator while sorting is in progress
      if (_isLoading) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Fotoğraflar sıralanıyor...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        );
      }
    } else {
      // For date and rating sorting, we can do it synchronously
      filterManager.sortPhotos(filteredPhotos);
      _isSorted = true;
    }

    return _buildFullScreenView(filteredPhotos);
  }

  Widget _buildFullScreenView(List<Photo> filteredPhotos) {
    final photoManager = Provider.of<PhotoManager>(context);
    final tagManager = Provider.of<TagManager>(context);
    final settingsManager = Provider.of<SettingsManager>(context);
    final tags = tagManager.tags;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final currentIndex = filteredPhotos.indexOf(_currentPhoto);

          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
            setState(() {
              _currentPhoto = filteredPhotos[currentIndex - 1];
              _resetZoom();
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && currentIndex < filteredPhotos.length - 1) {
            setState(() {
              _currentPhoto = filteredPhotos[currentIndex + 1];
              _resetZoom();
            });
          } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
            photoManager.toggleFavorite(_currentPhoto);
            setState(() {});
          } else if (event.logicalKey == LogicalKeyboardKey.delete) {
            final currentIndex = filteredPhotos.indexOf(_currentPhoto);
            photoManager.deletePhoto(_currentPhoto);
            if (filteredPhotos.isEmpty) {
              Navigator.of(context).pop();
            } else {
              setState(() {
                _currentPhoto = filteredPhotos[currentIndex < filteredPhotos.length ? currentIndex : filteredPhotos.length - 1];
                _resetZoom();
              });
            }
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          } else if (event.logicalKey == LogicalKeyboardKey.controlLeft) {
            setState(() {
              _showInfo = !_showInfo;
              settingsManager.setShowImageInfo(_showInfo);
            });
          } else if (event.logicalKey == LogicalKeyboardKey.tab) {
            setState(() {
              _zenMode = !_zenMode;
            });
          } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft) {
            setState(() {
              _autoNext = !_autoNext;
              settingsManager.setFullscreenAutoNext(_autoNext);
            });
          } else {
            for (var tag in tags) {
              if (event.logicalKey == tag.shortcutKey) {
                tagManager.toggleTag(_currentPhoto, tag);
                setState(() {});
                break;
              }
            }
            final key = event.logicalKey.keyLabel;
            if (key.length == 1 && RegExp(r'[1-7]').hasMatch(key)) {
              photoManager.setRating(_currentPhoto, int.parse(key));
              setState(() {});
              if (_autoNext && currentIndex < filteredPhotos.length - 1) {
                setState(() {
                  _currentPhoto = filteredPhotos[currentIndex + 1];
                  _resetZoom();
                });
              }
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MouseRegion(
                cursor: _isDragging
                    ? SystemMouseCursors.grabbing
                    : _isZooming
                        ? SystemMouseCursors.zoomIn
                        : _currentScale > _minScale
                            ? SystemMouseCursors.grab // Zoom yapılmışsa grab cursor göster (sürüklenebilir)
                            : SystemMouseCursors.click, // Zoom yapılmamışsa normal cursor göster
                child: Listener(
                  onPointerDown: (event) {
                    if (event.buttons == kMiddleMouseButton) {
                      // Eğer zoom yapılmışsa sürükleme, değilse çıkış yap
                      if (_currentScale > _minScale) {
                        // Zoom yapılmışsa sürükleme başlat
                        setState(() {
                          _isDragging = true;
                          _lastDragPosition = event.position;
                        });
                      } else {
                        // Zoom yapılmamışsa çıkış yap (ESC gibi)
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  onPointerMove: (event) {
                    if (_isDragging && _lastDragPosition != null) {
                      // Sürükleme hareketi
                      final delta = event.position - _lastDragPosition!;
                      final Matrix4 matrix = Matrix4.copy(_transformationController.value);
                      matrix.translate(delta.dx / _currentScale, delta.dy / _currentScale);
                      _transformationController.value = matrix;
                      _lastDragPosition = event.position;
                    }
                  },
                  onPointerUp: (event) {
                    if (_isDragging) {
                      setState(() {
                        _isDragging = false;
                        _lastDragPosition = null;
                      });
                    }
                  },
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      _handleMouseScroll(pointerSignal);
                    }
                  },
                  child: GestureDetector(
                    onDoubleTapDown: (details) {
                      // Çift tıklama pozisyonunu kaydet
                      _lastDragPosition = details.localPosition;
                    },
                    onDoubleTap: () {
                      setState(() {
                        if (_currentScale > _minScale) {
                          // Eğer zoom yapılmışsa, sıfırla
                          _transformationController.value = Matrix4.identity();
                          _currentScale = _minScale;
                          // Cursor durumu otomatik olarak güncellenecek
                        } else {
                          // Eğer zoom yapılmamışsa, tıklanan noktaya zoom yap
                          if (_lastDragPosition != null) {
                            // Ekran boyutlarını al
                            final Size viewSize = MediaQuery.of(context).size;

                            // Tıklama pozisyonunu al
                            final Offset focalPointScene = _lastDragPosition!;

                            // Ekranın merkezini hesapla
                            final Offset viewCenter = Offset(viewSize.width / 2, viewSize.height / 2);

                            // Tıklama pozisyonunun merkeze göre farkını hesapla
                            final Offset focalPointDelta = focalPointScene - viewCenter;

                            // Yeni dönüşüm matrisini hesapla
                            final Matrix4 matrix = Matrix4.identity();

                            // Ölçekleme faktörünü hesapla
                            final double scaleFactor = 2.0;

                            // Tıklama pozisyonuna göre zoom yap
                            // 1. Tıklama pozisyonunu merkeze taşı
                            matrix.translate(
                              focalPointScene.dx,
                              focalPointScene.dy,
                            );

                            // 2. Ölçekle
                            matrix.scale(scaleFactor);

                            // 3. Tıklama pozisyonunu geri taşı
                            matrix.translate(
                              -focalPointScene.dx,
                              -focalPointScene.dy,
                            );

                            // 4. Tıklama pozisyonuna göre ek kaydırma ekle
                            // Bu, zoom yaparken tıklama pozisyonunun sabit kalmasını sağlar
                            matrix.translate(
                              focalPointDelta.dx * (1 - scaleFactor),
                              focalPointDelta.dy * (1 - scaleFactor),
                            );

                            _transformationController.value = matrix;
                            _currentScale = scaleFactor;
                          } else {
                            // Eğer tıklama pozisyonu yoksa, merkeze zoom yap
                            final Matrix4 matrix = Matrix4.identity();
                            matrix.scale(2.0);
                            _transformationController.value = matrix;
                            _currentScale = 2.0;
                          }
                          // Cursor durumu otomatik olarak güncellenecek
                        }
                      });
                    },
                    child: Center(
                      child: SizedBox.expand(
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: _minScale,
                          maxScale: _maxScale,
                          onInteractionEnd: (details) {
                            // Güncellenen ölçeği kaydet
                            final scale = _transformationController.value.getMaxScaleOnAxis();
                            setState(() {
                              _currentScale = scale;
                              // Zoom durumuna göre cursor güncellenir
                              // (MouseRegion widget'inin cursor özelliği otomatik olarak güncellenecek)
                            });
                          },
                          child: Image.file(
                            File(_currentPhoto.path),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                )),
            if (!_zenMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _autoNext ? Icons.skip_next : Icons.skip_next_outlined,
                              color: _autoNext ? Colors.blue : Colors.white70,
                            ),
                            onPressed: () {
                              final settingsManager = Provider.of<SettingsManager>(context, listen: false);
                              setState(() {
                                _autoNext = !_autoNext;
                                settingsManager.setFullscreenAutoNext(_autoNext);
                              });
                            },
                            tooltip: 'Auto Next (Shift)',
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_currentPhoto.tags.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              children: _currentPhoto.tags
                                  .map((tag) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tag.color,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white24, width: 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black,
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          tag.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          if (_currentPhoto.rating > 0)
                            Row(
                              children: [
                                const Icon(Icons.star, size: 18, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  _currentPhoto.rating.toString(),
                                  style: const TextStyle(color: Colors.amber),
                                ),
                              ],
                            ),
                          IconButton(
                            icon: Icon(
                              _currentPhoto.isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _currentPhoto.isFavorite ? Colors.red : Colors.white70,
                            ),
                            onPressed: () => Provider.of<PhotoManager>(context, listen: false).toggleFavorite(_currentPhoto),
                            tooltip: 'Toggle Favorite (F)',
                          ),
                          IconButton(
                            icon: Icon(Icons.info_outline, color: _showInfo ? Colors.blue : Colors.white70),
                            onPressed: () {
                              final settingsManager = Provider.of<SettingsManager>(context, listen: false);
                              setState(() {
                                _showInfo = !_showInfo;
                                settingsManager.setShowImageInfo(_showInfo);
                              });
                            },
                            tooltip: _showInfo ? 'Hide Info (Ctrl)' : 'Show Info (Ctrl)',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close (ESC)',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_showInfo && !_zenMode)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                bottom: 16,
                right: 16,
                child: FutureBuilder<List<Object>>(
                  future: Future.wait([
                    File(_currentPhoto.path).length(),
                    () async {
                      final completer = Completer<ImageInfo>();
                      final stream = Image.file(File(_currentPhoto.path)).image.resolve(const ImageConfiguration());
                      final listener = ImageStreamListener(
                        (info, _) => completer.complete(info),
                        onError: (exception, stackTrace) => completer.completeError(exception),
                      );
                      stream.addListener(listener);
                      try {
                        return await completer.future;
                      } finally {
                        stream.removeListener(listener);
                      }
                    }(),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();

                    final fileSize = snapshot.data![0] as int;
                    final image = snapshot.data![1] as ImageInfo;
                    final width = image.image.width;
                    final height = image.image.height;

                    String formatFileSize(int size) {
                      if (size < 1024) return '$size B';
                      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
                      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                    }

                    final file = File(_currentPhoto.path);
                    final stat = file.statSync();
                    final creationDate = stat.changed.toLocal();
                    final formattedDate = '${creationDate.day}/${creationDate.month}/${creationDate.year} ${creationDate.hour}:${creationDate.minute.toString().padLeft(2, '0')}';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(179), // 0.7 opacity
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withAlpha(26), // 0.1 opacity
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(51), // 0.2 opacity
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPhoto.path.split('\\').last,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.photo_size_select_actual_outlined, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '${width}x$height',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.sd_storage_outlined, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                formatFileSize(fileSize),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
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
}
