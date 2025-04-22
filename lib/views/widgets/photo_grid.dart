import 'dart:io';
import 'package:archive_manager_v3/views/widgets/full_screen_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../managers/folder_manager.dart';
import '../../managers/photo_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/settings_manager.dart';
import '../../managers/filter_manager.dart';
import '../../models/sort_state.dart';
import '../../viewmodels/home_view_model.dart';

// Fotoğrafları grid (ızgara) şeklinde gösteren widget.
// Seçim, etiketleme, puanlama ve bağlam menüsü içerir.
class PhotoGrid extends StatefulWidget {
  const PhotoGrid({super.key});

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
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

  @override
  Widget build(BuildContext context) {
    final folderManager = Provider.of<FolderManager>(context);
    final photoManager = Provider.of<PhotoManager>(context);
    final tagManager = Provider.of<TagManager>(context);
    final settingsManager = Provider.of<SettingsManager>(context);
    final homeViewModel = Provider.of<HomeViewModel>(context);
    final filterManager = Provider.of<FilterManager>(context);

    return FocusScope(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.keyF) {
              if (homeViewModel.selectedPhoto != null) {
                photoManager.toggleFavorite(homeViewModel.selectedPhoto!);
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
                photoManager.setRating(homeViewModel.selectedPhoto!, rating);
                return KeyEventResult.handled;
              }
            }
            final tags = tagManager.tags;
            for (var tag in tags) {
              if (event.logicalKey == tag.shortcutKey && homeViewModel.selectedPhoto != null) {
                tagManager.toggleTag(homeViewModel.selectedPhoto!, tag);
                break;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            if (folderManager.selectedFolder == null) {
              return const Center(
                child: Text('Select a folder to view images'),
              );
            }

            return _buildGrid(context, folderManager, photoManager, tagManager, settingsManager, filterManager, homeViewModel);
          },
        ),
      ),
    );
  }

  // Helper method to build the grid view
  Widget _buildGridView(List<Photo> photos, SettingsManager settingsManager, HomeViewModel homeViewModel, PhotoManager photoManager, TagManager tagManager, BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: settingsManager.photosPerRow,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
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
                _showPhotoContextMenu(context, photo, photoManager, tagManager, details.globalPosition);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPhotoContainer(photo, homeViewModel, context, settingsManager),
                  _buildPhotoOverlay(photo, tagManager),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, FolderManager folderManager, PhotoManager photoManager, TagManager tagManager, SettingsManager settingsManager, FilterManager filterManager, HomeViewModel homeViewModel) {
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
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fotoğraflar sıralanıyor...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      }
    } else {
      // For date and rating sorting, we can do it synchronously
      filterManager.sortPhotos(filteredPhotos);
      _isSorted = true;
    }

    return Column(
      children: [
        Expanded(
          child: _buildGridView(filteredPhotos, settingsManager, homeViewModel, photoManager, tagManager, context),
        ),
      ],
    );
  }

  Widget _buildPhotoContainer(Photo photo, HomeViewModel homeViewModel, BuildContext context, SettingsManager settingsManager) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        border: homeViewModel.selectedPhoto == photo ? Border.all(color: const Color.fromARGB(255, 179, 179, 179), width: 2) : Border.all(color: Colors.transparent, width: 4),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51), // 0.2 opacity
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
          cacheHeight: settingsManager.photosPerRow == 1
              ? 4000
              : settingsManager.photosPerRow == 2
                  ? 2000
                  : settingsManager.photosPerRow == 3
                      ? 1000
                      : settingsManager.photosPerRow == 4
                          ? 700
                          : settingsManager.photosPerRow == 5
                              ? 600
                              : settingsManager.photosPerRow == 6
                                  ? 500
                                  : settingsManager.photosPerRow == 7
                                      ? 400
                                      : 300,
        ),
      ),
    );
  }

  void _showPhotoContextMenu(BuildContext context, Photo photo, PhotoManager photoManager, TagManager tagManager, Offset tapPosition) {
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
          onTap: () => photoManager.toggleFavorite(photo),
        ),
        PopupMenuItem(
          child: const Text('Sil'),
          onTap: () => photoManager.deletePhoto(photo),
        ),
      ],
    );
  }

  Widget _buildPhotoOverlay(Photo photo, TagManager tagManager) {
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
