import 'dart:io';
import 'dart:async';
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

  // Timer for periodic memory cleanup
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();

    // Delay setting up the timer to ensure the widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set up periodic memory cleanup every 30 seconds
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _cleanupImageCache();
      });
    });
  }

  @override
  void dispose() {
    // Cancel timer when widget is disposed
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // Method to clean up image cache to prevent memory leaks
  void _cleanupImageCache() {
    try {
      // Clear Flutter's image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Set a smaller image cache size limit
      PaintingBinding.instance.imageCache.maximumSize = 100;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB

      debugPrint('Image cache cleared to prevent memory leaks');
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }

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
                event.logicalKey == LogicalKeyboardKey.digit7 ||
                event.logicalKey == LogicalKeyboardKey.digit8 ||
                event.logicalKey == LogicalKeyboardKey.digit9) {
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
            if (folderManager.selectedFolder == null && folderManager.selectedSection == null) {
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

  // Helper method to build the grid view - optimized version
  Widget _buildGridView(List<Photo> photos, SettingsManager settingsManager, HomeViewModel homeViewModel, PhotoManager photoManager, TagManager tagManager, BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: settingsManager.photosPerRow,
        // Add some spacing between grid items
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      // Use caching for better performance
      cacheExtent: 500, // Cache more items for smoother scrolling
      // Optimize for large lists
      itemCount: photos.length,
      // Use addAutomaticKeepAlives: false for better memory usage
      addAutomaticKeepAlives: false,
      // Use addRepaintBoundaries: true for better rendering performance
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return RepaintBoundary(
          child: MouseRegion(
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

        // Add a timeout to prevent getting stuck in loading state
        Future.delayed(const Duration(seconds: 10), () {
          if (_isLoading && mounted) {
            setState(() {
              _isLoading = false;
              _isSorted = true;
              debugPrint('Sorting timed out after 10 seconds, showing photos anyway');
            });
          }
        });

        // Sort photos in the background
        filterManager.sortPhotos(filteredPhotos).then((_) {
          // When sorting is complete, update the UI
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isSorted = true;
              debugPrint('Sorting completed successfully');
            });
          }
        }).catchError((error) {
          // Handle errors during sorting
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isSorted = true;
              debugPrint('Error during sorting: $error');
            });
          }
        });
      }

      // Show loading indicator while sorting is in progress
      if (_isLoading) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Fotoğraflar sıralanıyor...', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoading = false;
                    _isSorted = true;
                  });
                },
                child: const Text('İptal Et', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    } else {
      // For date and rating sorting, we can do it synchronously
      try {
        filterManager.sortPhotos(filteredPhotos);
        _isSorted = true;
      } catch (e) {
        debugPrint('Error during synchronous sorting: $e');
        // Continue showing photos even if sorting fails
        _isSorted = true;
      }
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
    // Use a more efficient approach with conditional widgets instead of AnimatedContainer
    final bool isSelected = homeViewModel.selectedPhoto == photo;

    return Container(
      decoration: BoxDecoration(
        border: isSelected ? Border.all(color: const Color.fromARGB(255, 179, 179, 179), width: 2) : Border.all(color: Colors.transparent, width: 4),
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
        child: _optimizedImage(
          photo: photo,
          photosPerRow: settingsManager.photosPerRow,
        ),
      ),
    );
  }

  // Optimized image widget with memory caching and memory leak prevention
  Widget _optimizedImage({required Photo photo, required int photosPerRow}) {
    // Calculate appropriate cache size based on grid size - use higher values for better quality
    final int cacheHeight = photosPerRow == 1
        ? 2000
        : photosPerRow == 2
            ? 1500
            : photosPerRow == 3
                ? 1000
                : photosPerRow == 4
                    ? 800
                    : photosPerRow == 5
                        ? 600
                        : photosPerRow == 6
                            ? 500
                            : photosPerRow == 7
                                ? 400
                                : 300;

    // Create a unique key for each image to help with memory management
    final Key imageKey = ValueKey('img_${photo.path}_$cacheHeight');

    // Check if file exists first to prevent errors
    final file = File(photo.path);
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white54),
        ),
      );
    }

    // Use a more memory-efficient approach
    return RepaintBoundary(
      child: Image.file(
        file,
        key: imageKey,
        fit: BoxFit.cover,
        cacheHeight: cacheHeight,
        // Don't set cacheWidth to preserve aspect ratio
        cacheWidth: null, // Let system calculate width based on aspect ratio
        gaplessPlayback: true, // Prevent flickering during image loading
        // Error handling to prevent crashes
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading image: $error');
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54),
            ),
          );
        },
        // Use fade-in animation for smoother loading
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200), // Faster animation
            curve: Curves.easeOut,
            child: child,
          );
        },
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
