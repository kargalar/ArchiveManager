import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _autoNext = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentPhoto = widget.photo;
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
    } else {
      final key = event.logicalKey.keyLabel;
      if (key.length == 1 && RegExp(r'[1-5]').hasMatch(key)) {
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
                      child: Image.file(
                        File(_currentPhoto.path),
                        fit: BoxFit.contain,
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
                                setState(() {
                                  _autoNext = !_autoNext;
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
              ],
            ),
          ),
        );
      },
    );
  }
}
