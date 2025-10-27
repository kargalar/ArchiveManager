import 'dart:async';
import 'dart:io';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:archive_manager_v3/viewmodels/home_view_model.dart';
import 'package:archive_manager_v3/viewmodels/fullscreen_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:super_drag_and_drop/super_drag_and_drop.dart' as sdd;
import '../../models/photo.dart';
import '../../managers/photo_manager.dart';
import '../../managers/settings_manager.dart';
import '../../managers/filter_manager.dart';
import '../../utils/photo_sorter.dart';
import 'common/photo_action_buttons.dart';
import 'common/tag_chips.dart';

// Fotoğrafı tam ekranda gösteren widget.
// Klavye ve mouse ile gezinme, etiketleme, puanlama ve bilgi gösterimi içerir.
class FullScreenImage extends StatefulWidget {
  final Photo photo;
  final List<Photo> filteredPhotos; // Tam ekran moduna girdiğindeki filtrelenmiş liste

  // Static flag to track if we're in fullscreen mode
  static bool isActive = false;

  const FullScreenImage({
    super.key,
    required this.photo,
    required this.filteredPhotos, // Filtrelenmiş listeyi parametre olarak al
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> with TickerProviderStateMixin {
  late FullScreenViewModel _viewModel;
  late List<Photo> _frozenFilteredPhotos;
  late bool _autoNext;
  late bool _showInfo;
  late bool _showNotes;
  late bool _zenMode;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();
  final TextEditingController _notesController = TextEditingController();
  late final Box<Tag> _tagBox;
  final TransformationController _transformationController = TransformationController();
  final double _minScale = 1.0;
  final double _maxScale = 20.0;
  double _currentScale = 1.0;
  bool _isZooming = false;
  bool _isDragging = false;
  Offset? _lastDragPosition;
  DateTime? _middleMouseDownTime;

  // Key to access this screen's DragItemWidget state for multi-item drag
  final GlobalKey<sdd.DragItemWidgetState> _dragKey = GlobalKey<sdd.DragItemWidgetState>();

  List<Tag> get tags => _tagBox.values.toList();

  @override
  void initState() {
    super.initState();

    // Sıralanmış listeyi al
    final filterManager = context.read<FilterManager>();
    _frozenFilteredPhotos = PhotoSorter.sort(
      widget.filteredPhotos,
      ratingSortState: filterManager.ratingSortState,
      dateSortState: filterManager.dateSortState,
      resolutionSortState: filterManager.resolutionSortState,
    );

    // ViewModel'i oluştur
    _viewModel = FullScreenViewModel(
      initialPhoto: widget.photo,
      allPhotos: _frozenFilteredPhotos,
    );

    // Image cache'i yapılandır
    _viewModel.configureImageCache(context);

    _tagBox = Hive.box<Tag>('tags');
    _showInfo = context.read<SettingsManager>().showImageInfo;
    _showNotes = context.read<SettingsManager>().showNotes;
    _autoNext = context.read<SettingsManager>().fullscreenAutoNext;
    _notesController.text = _viewModel.currentPhoto.note;
    _zenMode = false;
    FullScreenImage.isActive = true;

    // ViewModel'i dinle
    _viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();

      // İlk cache yönetimini başlat
      _viewModel.manageCacheForCurrentPhoto(context);

      // Cache monitörünü başlat
      _viewModel.startCacheMonitoring();
    });
  }

  // ViewModel değiştiğinde çağrılır
  void _onViewModelChanged() {
    if (mounted) {
      setState(() {
        // Not controller'ı güncelle
        _notesController.text = _viewModel.currentPhoto.note;
      });
    }
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
    newTransformation.translateByVector3(
      Vector3(focalPointScene.dx, focalPointScene.dy, 0.0),
    );

    // 3. Ölçekle
    newTransformation.scaleByVector3(Vector3(scaleFactor, scaleFactor, 1.0));

    // 4. Fare pozisyonunu geri taşı
    newTransformation.translateByVector3(
      Vector3(-focalPointScene.dx, -focalPointScene.dy, 0.0),
    );

    // 5. Mevcut kaydırma değerlerini geri ekle
    newTransformation.translateByVector3(
      Vector3(currentTranslation.x, currentTranslation.y, 0.0),
    );

    // 6. Fare pozisyonuna göre ek kaydırma ekle
    // Bu, zoom yaparken fare pozisyonunun sabit kalmasını sağlar
    newTransformation.translateByVector3(
      Vector3(
        focalPointDelta.dx * (1 - scaleFactor),
        focalPointDelta.dy * (1 - scaleFactor),
        0.0,
      ),
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
    FullScreenImage.isActive = false;
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _focusNode.dispose();
    _notesFocusNode.dispose();
    _notesController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterManager = Provider.of<FilterManager>(context);
    final homeViewModel = Provider.of<HomeViewModel>(context);

    // Use frozen filtered list for consistent fullscreen experience
    List<Photo> filteredPhotos = _frozenFilteredPhotos;

    // Use PhotoSorter utility to sort photos - same as PhotoGrid
    List<Photo> sortedPhotos = PhotoSorter.sort(
      filteredPhotos,
      ratingSortState: filterManager.ratingSortState,
      dateSortState: filterManager.dateSortState,
      resolutionSortState: filterManager.resolutionSortState,
    );

    return _buildFullScreenView(sortedPhotos, homeViewModel);
  }

  // Sonraki fotoğrafa geçme işlemini gerçekleştirir
  void _moveToNextPhoto(List<Photo> filteredPhotos) async {
    await _viewModel.moveToNext(context);
    _resetZoom();
  }

  // Puan verme işlemini gerçekleştirir ve gerekirse sonraki fotoğrafa geçer
  void _handleRating(List<Photo> filteredPhotos) {
    // Eğer otomatik geçiş açıksa ve son fotoğraf değilse sonraki fotoğrafa geç
    if (_autoNext) {
      final currentIndex = filteredPhotos.indexOf(_viewModel.currentPhoto);
      if (currentIndex < filteredPhotos.length - 1) {
        // Kısa bir gecikme ekleyerek kullanıcının puanı görmesini sağla
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _moveToNextPhoto(filteredPhotos);
          }
        });
      }
    }
  }

  Widget _buildFullScreenView(List<Photo> filteredPhotos, HomeViewModel homeViewModel) {
    final photoManager = Provider.of<PhotoManager>(context);
    final settingsManager = Provider.of<SettingsManager>(context);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          // ESC tuşu her zaman çalışsın
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Future.microtask(() {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
            return;
          }

          // Not yazılıyorsa diğer kısayolları devre dışı bırak
          if (_notesFocusNode.hasFocus) {
            return;
          }

          final currentIndex = filteredPhotos.indexOf(_viewModel.currentPhoto);

          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _viewModel.canGoPrevious) {
            // HomeViewModel'deki seçili fotoğrafı güncelle
            homeViewModel.setSelectedPhoto(filteredPhotos[currentIndex - 1]);
            _viewModel.moveToPrevious(context);
            _resetZoom();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && _viewModel.canGoNext) {
            // HomeViewModel'deki seçili fotoğrafı güncelle
            homeViewModel.setSelectedPhoto(filteredPhotos[currentIndex + 1]);
            _viewModel.moveToNext(context);
            _resetZoom();
          } else if (event.logicalKey == LogicalKeyboardKey.delete) {
            // Use Future.microtask to avoid setState during build
            Future.microtask(() async {
              // Fotoğrafı sil
              photoManager.deletePhoto(_viewModel.currentPhoto);

              // ViewModel'de silme işlemi ve cache güncelleme
              // ignore: use_build_context_synchronously
              await _viewModel.deleteCurrentAndMoveNext(context);

              // Eğer tüm fotoğraflar silindiyse çık
              if (_viewModel.allPhotos.isEmpty && mounted) {
                Navigator.of(context).pop();
              } else if (mounted) {
                // HomeViewModel'i güncelle
                homeViewModel.setSelectedPhoto(_viewModel.currentPhoto);
                _resetZoom();
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.controlLeft) {
            setState(() {
              _showInfo = !_showInfo;
              settingsManager.setShowImageInfo(_showInfo);
            });
          } else if (event.logicalKey == LogicalKeyboardKey.keyN) {
            setState(() {
              _showNotes = !_showNotes;
              settingsManager.setShowNotes(_showNotes);
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
          } else if (event.logicalKey == LogicalKeyboardKey.f11) {
            // F11 tuşuna basıldığında tam ekran modunu aç/kapat
            settingsManager.toggleFullscreen();
          } else if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.enter) {
            // Boşluk veya Enter tuşuna basıldığında seçim durumunu değiştir
            homeViewModel.togglePhotoSelection(_viewModel.currentPhoto);
          } else {
            // Handle number keys for rating (0-9)
            final key = event.logicalKey.keyLabel;
            if (key.length == 1 && RegExp(r'[0-9]').hasMatch(key)) {
              final rating = int.parse(key);
              // Use Future.microtask to avoid setState during build
              Future.microtask(() {
                if (!mounted) return;
                final photoManager = Provider.of<PhotoManager>(context, listen: false);
                photoManager.setRating(_viewModel.currentPhoto, rating, allowToggle: false);
                // Current photo is being interacted with, mark viewed
                _viewModel.currentPhoto.markViewed();
                // Tam ekranda da state'i güncelle
                setState(() {
                  // Bu sadece UI'ı yeniden render etmek için
                });
                _handleRating(filteredPhotos);
              });
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MouseRegion(
                cursor:
                    // ! şimdilik böyle kalacak çünkü windows da varsayılanında grab ve grabbing
                    _isDragging
                        ? SystemMouseCursors.basic
                        : _isZooming
                            ? SystemMouseCursors.basic
                            : _currentScale > _minScale
                                ? SystemMouseCursors.basic // Zoom yapılmışsa grab cursor göster (sürüklenebilir)
                                : SystemMouseCursors.basic, // Zoom yapılmamışsa normal cursor göster
                child: Listener(
                  onPointerDown: (event) {
                    if (event.buttons == kMiddleMouseButton) {
                      // Orta tuş basıldığında zamanı kaydet
                      _middleMouseDownTime = DateTime.now();

                      // Başlangıç pozisyonunu kaydet
                      _lastDragPosition = event.position;
                    }
                  },
                  onPointerMove: (event) {
                    // Orta tuş basılı ve hareket varsa ve zoom yapılmışsa sürükleme başlat
                    if (event.buttons == kMiddleMouseButton && _lastDragPosition != null && _currentScale > _minScale) {
                      // Hareket mesafesini hesapla
                      final moveDistance = (event.position - _lastDragPosition!).distance;

                      // Belirli bir eşik değerini aşarsa sürükleme moduna geç
                      if (moveDistance > 5.0) {
                        setState(() {
                          _isDragging = true;
                        });
                      }

                      if (_isDragging) {
                        // Sürükleme hareketi
                        final delta = event.position - _lastDragPosition!;
                        final Matrix4 matrix = Matrix4.copy(_transformationController.value);
                        matrix.translateByVector3(Vector3(delta.dx / _currentScale, delta.dy / _currentScale, 0.0));
                        _transformationController.value = matrix;
                        _lastDragPosition = event.position;
                      }
                    }
                  },
                  onPointerUp: (event) {
                    // Orta tuş bırakıldığında
                    if (_middleMouseDownTime != null) {
                      // Sadece sürükleme yapmadıysa çıkış yap
                      // Sürükleme başlamışsa, hızlı bırakılsa bile çıkış yapma
                      if (!_isDragging) {
                        Navigator.of(context).pop();
                      }

                      _middleMouseDownTime = null;
                    }

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
                            matrix.translateByVector3(
                              Vector3(focalPointScene.dx, focalPointScene.dy, 0.0),
                            );

                            // 2. Ölçekle
                            matrix.scaleByVector3(Vector3(scaleFactor, scaleFactor, 1.0));

                            // 3. Tıklama pozisyonunu geri taşı
                            matrix.translateByVector3(
                              Vector3(-focalPointScene.dx, -focalPointScene.dy, 0.0),
                            );

                            // 4. Tıklama pozisyonuna göre ek kaydırma ekle
                            // Bu, zoom yaparken tıklama pozisyonunun sabit kalmasını sağlar
                            matrix.translateByVector3(
                              Vector3(
                                focalPointDelta.dx * (1 - scaleFactor),
                                focalPointDelta.dy * (1 - scaleFactor),
                                0.0,
                              ),
                            );

                            _transformationController.value = matrix;
                            _currentScale = scaleFactor;
                          } else {
                            // Eğer tıklama pozisyonu yoksa, merkeze zoom yap
                            final Matrix4 matrix = Matrix4.identity();
                            matrix.scaleByVector3(Vector3(2.0, 2.0, 1.0));
                            _transformationController.value = matrix;
                            _currentScale = 2.0;
                          }
                          // Cursor durumu otomatik olarak güncellenecek
                        }
                      });
                    },
                    child: Center(
                      child: SizedBox.expand(
                        child: sdd.DragItemWidget(
                          key: _dragKey,
                          dragItemProvider: (request) async {
                            final item = sdd.DragItem();
                            try {
                              // Her DragItem yalnızca mevcut fotoğrafı temsil eder
                              debugPrint('Preparing drag item for current photo: ${_viewModel.currentPhoto.path}');
                              item.add(sdd.Formats.fileUri(Uri.file(_viewModel.currentPhoto.path)));
                            } catch (e) {
                              debugPrint('DragItemProvider error: $e');
                              return null;
                            }
                            return item;
                          },
                          allowedOperations: () => [sdd.DropOperation.copy],
                          child: sdd.DraggableWidget(
                            // Provide multi-item drag when multiple photos are selected
                            dragItemsProvider: (ctx) {
                              final vm = Provider.of<HomeViewModel>(ctx, listen: false);
                              final List<sdd.DragItemWidgetState> items = [];
                              final self = _dragKey.currentState;
                              if (self != null) items.add(self);

                              if (vm.hasSelectedPhotos) {
                                // Note: In fullscreen we only have this one DragItemWidget.
                                // Returning single item here allows native drop to still include this photo.
                                // The grid view is the primary place for multi-select multi-drag.
                                // If desired in the future, we can render hidden DragItemWidgets for the rest.
                              }
                              return items;
                            },
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
                              child: Image(
                                image: FileImage(File(_viewModel.currentPhoto.path)),
                                fit: BoxFit.contain,
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) {
                                    return child;
                                  }
                                  // Yüklenirken loading göster
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeIn,
                                    child: child,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )),
            // Sürükleme bilgisi gösterimi
            if (homeViewModel.hasSelectedPhotos && !_zenMode)
              Positioned(
                top: 60,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(204), // 0.8 opacity
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51), // 0.2 opacity
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_handle, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Sürükle bırak: ${homeViewModel.selectedPhotos.length} fotoğraf kopyalanacak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Cache monitor overlay (sağ üst köşe) - DETAYLI
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(204), // 0.8 opacity
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha(51), // 0.2 opacity
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(77), // 0.3 opacity
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlık
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.memory, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        const Text(
                          'Cache Monitor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Genel bilgi
                    Text(
                      'Total: ${_viewModel.cachedImagesCount} images (${_viewModel.cachedImagesSizeMB}MB)',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    // Detaylı liste
                    ...() {
                      final cacheStatus = _viewModel.getCacheStatusList();
                      return cacheStatus.map((status) {
                        final isCurrent = status['label'] == 'CURRENT';
                        final isCached = status['isCached'] as bool;
                        final label = status['label'] as String;
                        final fileName = status['fileName'] as String;

                        // Dosya adını kısalt
                        final shortName = fileName.length > 20 ? '${fileName.substring(0, 17)}...' : fileName;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Durum ikonu
                              Icon(
                                isCached ? Icons.check_circle : Icons.pending,
                                size: 12,
                                color: isCached ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              // Label
                              SizedBox(
                                width: 60,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isCurrent ? Colors.blue : Colors.white70,
                                    fontSize: 9,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Dosya adı
                              Flexible(
                                child: Text(
                                  shortName,
                                  style: TextStyle(
                                    color: isCurrent ? Colors.blue : Colors.white60,
                                    fontSize: 9,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    }(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    Row(
                      children: [
                        TagChips(tags: _viewModel.currentPhoto.tags),
                        RatingDisplay(rating: _viewModel.currentPhoto.rating),
                        // Selection status icon
                        SelectionIconButton(
                          photo: _viewModel.currentPhoto,
                          onPressed: () => homeViewModel.togglePhotoSelection(_viewModel.currentPhoto),
                        ),
                        // Favorite icon
                        FavoriteIconButton(
                          photo: _viewModel.currentPhoto,
                          onPressed: () {
                            final photoManager = Provider.of<PhotoManager>(context, listen: false);
                            photoManager.toggleFavorite(_viewModel.currentPhoto);

                            setState(() {});

                            // Eğer otomatik geçiş açıksa, sonraki fotoğrafa geç
                            if (_autoNext) {
                              final currentIndex = filteredPhotos.indexOf(_viewModel.currentPhoto);
                              if (currentIndex < filteredPhotos.length - 1) {
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  if (mounted) {
                                    _moveToNextPhoto(filteredPhotos);
                                  }
                                });
                              }
                            }
                          },
                        ),
                        InfoIconButton(
                          isActive: _showInfo,
                          onPressed: () {
                            final settingsManager = Provider.of<SettingsManager>(context, listen: false);
                            setState(() {
                              _showInfo = !_showInfo;
                              settingsManager.setShowImageInfo(_showInfo);
                            });
                          },
                        ),
                        NotesIconButton(
                          isActive: _showNotes,
                          onPressed: () {
                            final settingsManager = Provider.of<SettingsManager>(context, listen: false);
                            setState(() {
                              _showNotes = !_showNotes;
                              settingsManager.setShowNotes(_showNotes);
                            });
                          },
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
                    File(_viewModel.currentPhoto.path).length(),
                    () async {
                      final completer = Completer<ImageInfo>();
                      final stream = Image.file(File(_viewModel.currentPhoto.path)).image.resolve(const ImageConfiguration());
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
                      if (size < 1024 * 1024) {
                        return '${(size / 1024).toStringAsFixed(1)} KB';
                      }
                      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                    }

                    final file = File(_viewModel.currentPhoto.path);
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
                            _viewModel.currentPhoto.path.split('\\').last,
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
                          // Seçili fotoğraf sayısını göster
                          if (homeViewModel.hasSelectedPhotos) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(51), // 0.2 opacity
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.withAlpha(102)), // 0.4 opacity
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library, size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${homeViewModel.selectedPhotos.length} seçili',
                                    style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            // Notes panel
            if (_showNotes && !_zenMode)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                bottom: 16,
                left: 16,
                child: Container(
                  width: 400,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.note, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Notlar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.save, color: Colors.white70, size: 18),
                            onPressed: () {
                              _viewModel.currentPhoto.updateNote(_notesController.text);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Not kaydedildi'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            tooltip: 'Not Kaydet',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      KeyboardListener(
                        focusNode: FocusNode(skipTraversal: true),
                        onKeyEvent: (event) {
                          // TextField için tüm tuş olaylarını engelle (ESC hariç)
                          if (event.logicalKey == LogicalKeyboardKey.escape) {
                            return; // ESC'yi yukarı gönder
                          }
                          // Diğer tüm tuşları durdur
                        },
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            debugPrint('TextField focus changed: $hasFocus');
                          },
                          child: TextField(
                            controller: _notesController,
                            focusNode: _notesFocusNode,
                            maxLines: 6,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Bu fotoğraf için notlarınızı buraya yazın...',
                              hintStyle: TextStyle(color: Colors.white.withAlpha(128)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white.withAlpha(51)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.blue),
                              ),
                              filled: true,
                              fillColor: Colors.black.withAlpha(77), // 0.3 opacity
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            onChanged: (value) {
                              // Auto-save after a short delay
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (_notesController.text == value) {
                                  _viewModel.currentPhoto.updateNote(value);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
