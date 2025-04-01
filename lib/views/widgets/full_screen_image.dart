import 'dart:async';
import 'dart:io';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../viewmodels/photo_view_model.dart';

class FullScreenImage extends StatefulWidget {
  final Photo photo;

  const FullScreenImage({super.key, required this.photo});

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late Photo _currentPhoto;
  late bool _autoNext;
  late bool _showInfo;
  final FocusNode _focusNode = FocusNode();
  late final Box<Tag> _tagBox;

  List<Tag> get tags => _tagBox.values.toList();

  @override
  void initState() {
    super.initState();
    _currentPhoto = widget.photo;
    _tagBox = Hive.box<Tag>('tags');
    _showInfo = context.read<PhotoViewModel>().showImageInfo;
    _autoNext = context.read<PhotoViewModel>().fullscreenAutoNext;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _handleKeyEvent(RawKeyEvent event, PhotoViewModel viewModel) {
    if (event is! RawKeyDownEvent) return;

    final filteredPhotos = viewModel.filteredPhotos;
    final currentIndex = filteredPhotos.indexOf(_currentPhoto);

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
      setState(() {
        _currentPhoto = filteredPhotos[currentIndex - 1];
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && currentIndex < filteredPhotos.length - 1) {
      setState(() {
        _currentPhoto = filteredPhotos[currentIndex + 1];
      });
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      viewModel.toggleFavorite(_currentPhoto);
      setState(() {});
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      final filteredPhotos = viewModel.filteredPhotos;
      final currentIndex = filteredPhotos.indexOf(_currentPhoto);
      viewModel.deletePhoto(_currentPhoto);
      if (filteredPhotos.isEmpty) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _currentPhoto = filteredPhotos[currentIndex < filteredPhotos.length ? currentIndex : filteredPhotos.length - 1];
        });
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else if (event.logicalKey == LogicalKeyboardKey.controlLeft) {
      final photoViewModel = context.read<PhotoViewModel>();
      setState(() {
        _showInfo = !_showInfo;
        photoViewModel.setShowImageInfo(_showInfo);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft) {
      final photoViewModel = context.read<PhotoViewModel>();
      setState(() {
        _autoNext = !_autoNext;
        photoViewModel.setFullscreenAutoNext(_autoNext);
      });
    } else {
      for (var tag in tags) {
        if (event.logicalKey == tag.shortcutKey) {
          viewModel.toggleTag(_currentPhoto, tag);
          setState(() {});
          break;
        }
      }
      final key = event.logicalKey.keyLabel;
      if (key.length == 1 && RegExp(r'[1-7]').hasMatch(key)) {
        viewModel.setRating(_currentPhoto, int.parse(key));
        setState(() {});
        if (_autoNext && currentIndex < filteredPhotos.length - 1) {
          setState(() {
            _currentPhoto = filteredPhotos[currentIndex + 1];
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoViewModel>(
      builder: (context, viewModel, child) {
        return RawKeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKey: (event) => _handleKeyEvent(event, viewModel),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Listener(
                    onPointerDown: (event) {
                      if (event.buttons == kMiddleMouseButton) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Center(
                      child: Hero(
                        tag: _currentPhoto.path,
                        child: SizedBox.expand(
                          child: Image.file(
                            File(_currentPhoto.path),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
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
                                final photoViewModel = context.read<PhotoViewModel>();
                                setState(() {
                                  _autoNext = !_autoNext;
                                  photoViewModel.setFullscreenAutoNext(_autoNext);
                                });
                              },
                              tooltip: 'Auto Next',
                            ),
                            if (_currentPhoto.rating > 0)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, size: 18, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      _currentPhoto.rating.toString(),
                                      style: const TextStyle(color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _currentPhoto.isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _currentPhoto.isFavorite ? Colors.red : Colors.white70,
                              ),
                              onPressed: () => viewModel.toggleFavorite(_currentPhoto),
                              tooltip: 'Toggle Favorite',
                            ),
                            IconButton(
                              icon: Icon(Icons.info_outline, color: _showInfo ? Colors.blue : Colors.white70),
                              onPressed: () {
                                final photoViewModel = context.read<PhotoViewModel>();
                                setState(() {
                                  _showInfo = !_showInfo;
                                  photoViewModel.setShowImageInfo(_showInfo);
                                });
                              },
                              tooltip: _showInfo ? 'Hide Info' : 'Show Info',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_currentPhoto.tags.isNotEmpty)
                  Positioned(
                    top: 80,
                    right: 16,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.3),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: _currentPhoto.tags
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tag.color.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: tag.color.withOpacity(0.6)),
                                  ),
                                  child: Text(
                                    tag.name,
                                    style: TextStyle(
                                      color: tag.color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                if (_showInfo)
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
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
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
      },
    );
  }
}
