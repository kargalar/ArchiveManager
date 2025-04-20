import 'dart:io';
import 'package:archive_manager_v3/views/widgets/full_screen_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../viewmodels/photo_view_model.dart';
import '../../viewmodels/home_view_model.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Focus(
        autofocus: true,
        onKey: (node, event) {
          if (event is RawKeyDownEvent) {
            final homeViewModel = context.read<HomeViewModel>();
            final photoViewModel = context.read<PhotoViewModel>();
            if (event.logicalKey == LogicalKeyboardKey.keyF) {
              if (homeViewModel.selectedPhoto != null) {
                photoViewModel.toggleFavorite(homeViewModel.selectedPhoto!);
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.digit4 ||
                event.logicalKey == LogicalKeyboardKey.digit5 ||
                event.logicalKey == LogicalKeyboardKey.digit6 ||
                event.logicalKey == LogicalKeyboardKey.digit7) {
              if (homeViewModel.selectedPhoto != null) {
                final rating = int.parse(event.logicalKey.keyLabel);
                photoViewModel.setRating(homeViewModel.selectedPhoto!, rating);
                return KeyEventResult.handled;
              }
            }
            final tags = photoViewModel.tags;
            for (var tag in tags) {
              if (event.logicalKey == tag.shortcutKey && homeViewModel.selectedPhoto != null) {
                photoViewModel.toggleTag(homeViewModel.selectedPhoto!, tag);
                break;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Consumer2<PhotoViewModel, HomeViewModel>(
          builder: (context, photoViewModel, homeViewModel, child) {
            if (photoViewModel.selectedFolder == null) {
              return const Center(
                child: Text('Select a folder to view images'),
              );
            }

            return _buildGrid(context, photoViewModel, homeViewModel);
          },
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, PhotoViewModel photoViewModel, HomeViewModel homeViewModel) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: photoViewModel.photosPerRow,
            ),
            itemCount: photoViewModel.filteredPhotos.length,
            itemBuilder: (context, index) {
              final photo = photoViewModel.filteredPhotos[index];
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Listener(
                  onPointerDown: (event) {
                    if (event.buttons == kMiddleMouseButton) {
                      homeViewModel.handlePhotoTap(photo);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImage(photo: photo),
                        ),
                      );
                    }
                  },
                  child: GestureDetector(
                    onTap: () => homeViewModel.handlePhotoTap(photo),
                    onSecondaryTapDown: (details) {
                      homeViewModel.handlePhotoTap(photo);
                      _showPhotoContextMenu(context, photo, photoViewModel, details.globalPosition);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPhotoContainer(photo, homeViewModel, context),
                        _buildPhotoOverlay(photo, photoViewModel),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoContainer(Photo photo, HomeViewModel homeViewModel, BuildContext context) {
    final photoViewModel = context.read<PhotoViewModel>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        border: homeViewModel.selectedPhoto == photo ? Border.all(color: const Color.fromARGB(255, 179, 179, 179), width: 2) : Border.all(color: Colors.transparent, width: 4),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(photo.path),
          fit: BoxFit.cover,
          cacheHeight: photoViewModel.photosPerRow == 1
              ? 4000
              : photoViewModel.photosPerRow == 2
                  ? 2000
                  : photoViewModel.photosPerRow == 3
                      ? 1000
                      : photoViewModel.photosPerRow == 4
                          ? 700
                          : photoViewModel.photosPerRow == 5
                              ? 600
                              : photoViewModel.photosPerRow == 6
                                  ? 500
                                  : photoViewModel.photosPerRow == 7
                                      ? 400
                                      : 300,
        ),
      ),
    );
  }

  void _showPhotoContextMenu(BuildContext context, Photo photo, PhotoViewModel viewModel, Offset tapPosition) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          tapPosition,
          tapPosition,
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const Text('Favorilere Ekle/Çıkar'),
          onTap: () => viewModel.toggleFavorite(photo),
        ),
        PopupMenuItem(
          child: const Text('Sil'),
          onTap: () => viewModel.deletePhoto(photo),
        ),
      ],
    );
  }

  Widget _buildPhotoOverlay(Photo photo, PhotoViewModel viewModel) {
    return Stack(
      children: [
        if (photo.tags.isNotEmpty)
          Positioned(
            bottom: 6,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: photo.tags
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
                  ],
                ),
              ],
            ),
          ),
        Positioned(
          top: 6,
          right: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (photo.rating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            photo.rating.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 6),
                  if (photo.isFavorite)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: photo.isFavorite ? Colors.pink.shade300 : Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
