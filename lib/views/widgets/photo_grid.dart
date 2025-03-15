import 'dart:io';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:archive_manager_v3/views/widgets/full_screen_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
            } else if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.digit5) {
              if (homeViewModel.selectedPhoto != null) {
                final rating = int.parse(event.logicalKey.keyLabel);
                photoViewModel.setRating(homeViewModel.selectedPhoto!, rating);
                return KeyEventResult.handled;
              }
            }
            final tags = photoViewModel.tags;
            for (var tag in tags) {
              if (event.logicalKey == tag.shortcutKey && homeViewModel.selectedPhoto != null) {
                var currentTags = List<Tag>.from(homeViewModel.selectedPhoto!.tags);
                if (currentTags.any((t) => t.name == tag.name)) {
                  currentTags.removeWhere((t) => t.name == tag.name);
                } else {
                  currentTags.add(tag);
                }
                homeViewModel.selectedPhoto!.tags = currentTags;
                homeViewModel.selectedPhoto!.save();
                photoViewModel.notifyListeners(); // Notify listeners to update UI

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
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
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
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FullScreenImage(photo: photo),
                        ),
                      );
                    }
                  },
                  child: GestureDetector(
                    onTap: () => homeViewModel.handlePhotoTap(photo),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPhotoContainer(photo, homeViewModel),
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

  Widget _buildPhotoContainer(Photo photo, HomeViewModel homeViewModel) {
    return Container(
      decoration: BoxDecoration(
        border: homeViewModel.selectedPhoto == photo ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Image.file(
        File(photo.path),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPhotoOverlay(Photo photo, PhotoViewModel viewModel) {
    return Stack(
      children: [
        Positioned(
          top: 8,
          right: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (photo.rating > 0)
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
                            photo.rating.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (photo.isFavorite)
                    GestureDetector(
                      onTap: () => viewModel.toggleFavorite(photo),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.favorite,
                          size: 16,
                          color: photo.isFavorite ? Colors.red : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              if (photo.tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: photo.tags
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}
