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

    final currentIndex = viewModel.photos.indexOf(_currentPhoto);

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
      setState(() {
        _currentPhoto = viewModel.photos[currentIndex - 1];
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && currentIndex < viewModel.photos.length - 1) {
      setState(() {
        _currentPhoto = viewModel.photos[currentIndex + 1];
      });
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      viewModel.toggleFavorite(_currentPhoto);
      setState(() {});
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      final currentIndex = viewModel.photos.indexOf(_currentPhoto);
      viewModel.deletePhoto(_currentPhoto);
      if (viewModel.photos.isEmpty) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _currentPhoto = viewModel.photos[currentIndex < viewModel.photos.length ? currentIndex : viewModel.photos.length - 1];
        });
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final photoViewModel = context.read<PhotoViewModel>();
      setState(() {
        _showInfo = !_showInfo;
        photoViewModel.setShowImageInfo(_showInfo);
      });
    } else {
      for (var tag in tags) {
        if (event.logicalKey == tag.shortcutKey) {
          var currentTags = List<Tag>.from(_currentPhoto.tags);
          if (currentTags.any((t) => t.name == tag.name)) {
            currentTags.removeWhere((t) => t.name == tag.name);
          } else {
            currentTags.add(tag);
          }
          setState(() {
            _currentPhoto.tags = currentTags;
            _currentPhoto.save();
          });
          viewModel.notifyListeners();
          break;
        }
      }
      final key = event.logicalKey.keyLabel;
      if (key.length == 1 && RegExp(r'[1-7]').hasMatch(key)) {
        viewModel.setRating(_currentPhoto, int.parse(key));
        setState(() {});
        if (_autoNext && currentIndex < viewModel.photos.length - 1) {
          setState(() {
            _currentPhoto = viewModel.photos[currentIndex + 1];
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
                      child: SizedBox.expand(
                        child: Image.file(
                          File(_currentPhoto.path),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                final photoViewModel = context.read<PhotoViewModel>();
                                setState(() {
                                  _autoNext = !_autoNext;
                                  photoViewModel.setFullscreenAutoNext(_autoNext);
                                });
                              },
                              child: Icon(
                                Icons.skip_next,
                                size: 16,
                                color: _autoNext ? Colors.blue : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_currentPhoto.rating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: Colors.yellow),
                              const SizedBox(width: 4),
                              Text(
                                _currentPhoto.rating.toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => viewModel.toggleFavorite(_currentPhoto),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _currentPhoto.isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: _currentPhoto.isFavorite ? Colors.red : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                if (_currentPhoto.tags.isNotEmpty)
                  Positioned(
                    top: 48,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: _currentPhoto.tags
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tag.color.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                if (_showInfo)
                  Positioned(
                    bottom: 8,
                    right: 8,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.3),
                          child: Text(
                            '${_currentPhoto.path.split('\\').last}\n${width}x$height - ${formatFileSize(fileSize)}\n$formattedDate',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            softWrap: true,
                            overflow: TextOverflow.visible,
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
