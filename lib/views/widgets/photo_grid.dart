import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:archive_manager_v3/models/sort_state.dart';
import 'package:archive_manager_v3/viewmodels/home_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../models/tag.dart';
import '../../managers/folder_manager.dart';
import '../../managers/photo_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/settings_manager.dart';
import '../../managers/filter_manager.dart';
import 'full_screen_image.dart';

class PhotoGrid extends StatefulWidget {
  const PhotoGrid({super.key});

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  // Sorting durumunu yönetmek için
  SortState? _lastResolutionSortState;
  SortState? _lastDateSortState;
  SortState? _lastRatingSortState;

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

      // Initialize sort state tracking
      final filterManager = Provider.of<FilterManager>(context, listen: false);
      _lastResolutionSortState = filterManager.resolutionSortState;
      _lastDateSortState = filterManager.dateSortState;
      _lastRatingSortState = filterManager.ratingSortState;

      // Force a sort on initial load if needed
      if (filterManager.resolutionSortState != SortState.none || filterManager.dateSortState != SortState.none || filterManager.ratingSortState != SortState.none) {
        debugPrint('Initial sort state detected, will trigger sort on first build');
        setState(() {}); // Trigger a rebuild to apply sorting
      }
    });
  }

  @override
  void dispose() {
    // Cancel timer when widget is disposed
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // Periodically clean up image cache to prevent memory leaks
  void _cleanupImageCache() {
    try {
      // Clear Flutter's image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      ImageCache().clear();
      ImageCache().clearLiveImages();
    } catch (e) {
      debugPrint('Error cleaning up image cache: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final filterManager = Provider.of<FilterManager>(context);

    // Herhangi bir sıralama türü değiştiğinde yeniden render et
    bool sortStateChanged = false;

    // Çözünürlük sıralaması değişti mi?
    if (_lastResolutionSortState != filterManager.resolutionSortState) {
      _lastResolutionSortState = filterManager.resolutionSortState;
      sortStateChanged = true;
      debugPrint('Resolution sort state changed to: ${filterManager.resolutionSortState}');
    }

    // Tarih sıralaması değişti mi?
    if (_lastDateSortState != filterManager.dateSortState) {
      _lastDateSortState = filterManager.dateSortState;
      sortStateChanged = true;
      debugPrint('Date sort state changed to: ${filterManager.dateSortState}');
    }

    // Puan sıralaması değişti mi?
    if (_lastRatingSortState != filterManager.ratingSortState) {
      _lastRatingSortState = filterManager.ratingSortState;
      sortStateChanged = true;
      debugPrint('Rating sort state changed to: ${filterManager.ratingSortState}');
    }

    // Herhangi bir sıralama değiştiyse, yeniden render et
    if (sortStateChanged) {
      // Use Future.microtask to avoid setState during build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            debugPrint('Sort state changed, triggering rebuild to apply new sort');
          });
        }
      });
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

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (homeViewModel.selectedPhoto != null) {
            if (event.logicalKey == LogicalKeyboardKey.delete) {
              // Use Future.microtask to avoid setState during build
              Future.microtask(() {
                photoManager.deletePhoto(homeViewModel.selectedPhoto!);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
              // Use Future.microtask to avoid setState during build
              Future.microtask(() {
                photoManager.toggleFavorite(homeViewModel.selectedPhoto!);
              });
            } else {
              final key = event.logicalKey.keyLabel;
              if (key.length == 1 && RegExp(r'[1-9]').hasMatch(key)) {
                // Use Future.microtask to avoid setState during build
                Future.microtask(() {
                  photoManager.setRating(homeViewModel.selectedPhoto!, int.parse(key));
                });
              }

              final tags = tagManager.tags;
              for (var tag in tags) {
                if (event.logicalKey == tag.shortcutKey) {
                  // Use Future.microtask to avoid setState during build
                  Future.microtask(() {
                    tagManager.toggleTag(homeViewModel.selectedPhoto!, tag);
                  });
                  break;
                }
              }
            }
          }
        }
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
    );
  }

  Widget _buildGrid(BuildContext context, FolderManager folderManager, PhotoManager photoManager, TagManager tagManager, SettingsManager settingsManager, FilterManager filterManager, HomeViewModel homeViewModel) {
    // Get filtered photos
    List<Photo> filteredPhotos = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags);

    // Create a copy of the filtered photos to sort
    List<Photo> sortedPhotos = List.from(filteredPhotos);

    // Sort photos directly here instead of using FilterManager
    if (filterManager.ratingSortState != SortState.none) {
      debugPrint('Sorting by rating: ${filterManager.ratingSortState}');

      // Log some ratings before sort
      if (sortedPhotos.isNotEmpty) {
        debugPrint('Sample ratings before sort:');
        for (int i = 0; i < math.min(5, sortedPhotos.length); i++) {
          debugPrint('Photo ${i + 1}: rating=${sortedPhotos[i].rating}, path=${sortedPhotos[i].path}');
        }
      }

      if (filterManager.ratingSortState == SortState.ascending) {
        debugPrint('Sorting ratings ascending');
        sortedPhotos.sort((a, b) => a.rating.compareTo(b.rating));
      } else {
        debugPrint('Sorting ratings descending');
        sortedPhotos.sort((a, b) => b.rating.compareTo(a.rating));
      }

      // Log some ratings after sort
      if (sortedPhotos.isNotEmpty) {
        debugPrint('Sample ratings after sort:');
        for (int i = 0; i < math.min(5, sortedPhotos.length); i++) {
          debugPrint('Photo ${i + 1}: rating=${sortedPhotos[i].rating}, path=${sortedPhotos[i].path}');
        }
      }
    } else if (filterManager.dateSortState != SortState.none) {
      debugPrint('Sorting by date: ${filterManager.dateSortState}');

      if (filterManager.dateSortState == SortState.ascending) {
        debugPrint('Sorting dates ascending');
        sortedPhotos.sort((a, b) {
          final dateA = a.dateModified;
          final dateB = b.dateModified;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        });
      } else {
        debugPrint('Sorting dates descending');
        sortedPhotos.sort((a, b) {
          final dateA = a.dateModified;
          final dateB = b.dateModified;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
      }
    } else if (filterManager.resolutionSortState != SortState.none) {
      debugPrint('Sorting by resolution: ${filterManager.resolutionSortState}');

      if (filterManager.resolutionSortState == SortState.ascending) {
        debugPrint('Sorting resolutions ascending');
        sortedPhotos.sort((a, b) => a.resolution.compareTo(b.resolution));
      } else {
        debugPrint('Sorting resolutions descending');
        sortedPhotos.sort((a, b) => b.resolution.compareTo(a.resolution));
      }
    } else {
      debugPrint('No sorting applied, using default order');
    }

    return Column(
      children: [
        // Selection status bar - only visible when photos are selected
        if (homeViewModel.hasSelectedPhotos)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade800,
            child: Row(
              children: [
                Text(
                  '${homeViewModel.selectedPhotos.length} fotoğraf seçildi',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  tooltip: 'Seçili Fotoğrafları Sil',
                  onPressed: () {
                    // Show confirmation dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Fotoğrafları Sil'),
                        content: Text('${homeViewModel.selectedPhotos.length} fotoğrafı silmek istediğinize emin misiniz?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Delete all selected photos
                              List<Photo> photosToDelete = List.from(homeViewModel.selectedPhotos);
                              for (var photo in photosToDelete) {
                                photoManager.deletePhoto(photo);
                              }
                              homeViewModel.clearPhotoSelections();
                            },
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Favorite button
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  tooltip: 'Favorilere Ekle/Çıkar',
                  onPressed: () => homeViewModel.toggleFavoriteForSelectedPhotos(photoManager),
                ),
                // Rating buttons
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    icon: Icon(Icons.star, color: Colors.amber),
                    tooltip: '$i Puan Ver',
                    onPressed: () => homeViewModel.setRatingForSelectedPhotos(photoManager, i),
                  ),
                const SizedBox(width: 8),

                // Tag dropdown menu
                if (tagManager.tags.isNotEmpty)
                  PopupMenuButton<Tag>(
                    tooltip: 'Etiket Ekle/Çıkar',
                    icon: const Icon(Icons.label, color: Colors.white),
                    itemBuilder: (context) => tagManager.tags
                        .map((tag) => PopupMenuItem<Tag>(
                              value: tag,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: tag.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(tag.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onSelected: (tag) => homeViewModel.toggleTagForSelectedPhotos(tagManager, tag),
                  ),
                const SizedBox(width: 16),
                // Clear selection button
                TextButton.icon(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  label: const Text('Seçimi Temizle', style: TextStyle(color: Colors.white)),
                  onPressed: () => homeViewModel.clearPhotoSelections(),
                ),
              ],
            ),
          ),
        Expanded(
          child: _buildGridView(sortedPhotos, settingsManager, homeViewModel, photoManager, tagManager, context),
        ),
      ],
    );
  }

  // Helper method to build the grid view - optimized version
  Widget _buildGridView(List<Photo> sortedPhotos, SettingsManager settingsManager, HomeViewModel homeViewModel, PhotoManager photoManager, TagManager tagManager, BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: settingsManager.photosPerRow,
        // Add some spacing between grid items
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      // Use caching for better performance
      cacheExtent: 500, // Cache more items for smoother scrolling
      // Optimize for large lists
      itemCount: sortedPhotos.length,
      // Use addAutomaticKeepAlives: false for better memory usage
      addAutomaticKeepAlives: false,
      // Use addRepaintBoundaries: true for better rendering performance
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final photo = sortedPhotos[index];
        return RepaintBoundary(
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons == kMiddleMouseButton) {
                // Tıklanan fotoğrafı seçili fotoğraf olarak ayarla
                homeViewModel.setSelectedPhoto(photo);

                // Tam ekran görünümüne geç
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    settings: const RouteSettings(name: 'fullscreen_image'),
                    pageBuilder: (context, animation, secondaryAnimation) => FullScreenImage(photo: photo),
                  ),
                );
              }
            },
            child: GestureDetector(
              onTap: () {
                // Get keyboard modifiers using HardwareKeyboard
                final bool isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

                // Check if selection mode is active (any photos are selected)
                final bool selectionModeActive = homeViewModel.hasSelectedPhotos;

                // If Ctrl is pressed or selection mode is active, toggle selection
                if (isCtrlPressed || selectionModeActive) {
                  homeViewModel.togglePhotoSelection(photo);
                } else {
                  // Normal tap behavior when no selection is active
                  homeViewModel.handlePhotoTap(photo, isCtrlPressed: isCtrlPressed);
                }
              },
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

  Widget _buildPhotoContainer(Photo photo, HomeViewModel homeViewModel, BuildContext context, SettingsManager settingsManager) {
    // Check if this photo is the currently selected photo or is in the selected photos list
    final bool isCurrentlySelected = homeViewModel.selectedPhoto == photo;
    final bool isMultiSelected = photo.isSelected;

    // Track hover state for showing selection icon
    bool isHovered = false;

    return StatefulBuilder(builder: (context, setState) {
      return Container(
        decoration: BoxDecoration(
          border: isMultiSelected
              ? Border.all(color: Colors.blue, width: 2)
              : isCurrentlySelected
                  ? Border.all(color: const Color.fromARGB(255, 179, 179, 179), width: 2)
                  : Border.all(color: Colors.transparent, width: 4),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51), // 0.2 opacity
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo image
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _optimizedImage(
                  photo: photo,
                  photosPerRow: settingsManager.photosPerRow,
                ),
              ),

              // Selection icon (visible on hover or when selected)
              if (isHovered || isMultiSelected)
                Positioned(
                  top: 0,
                  left: 0,
                  child: GestureDetector(
                    onTap: () {
                      // Toggle selection without affecting the current selected photo
                      homeViewModel.togglePhotoSelection(photo);
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: isMultiSelected ? Colors.blue : Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.check,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
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
    final homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
    final bool hasSelectedPhotos = homeViewModel.hasSelectedPhotos;

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
        if (hasSelectedPhotos)
          PopupMenuItem(
            child: const Text('Seçili Fotoğrafları Favorilere Ekle/Çıkar'),
            onTap: () => homeViewModel.toggleFavoriteForSelectedPhotos(photoManager),
          )
        else
          PopupMenuItem(
            child: const Text('Favorilere Ekle/Çıkar'),
            onTap: () => photoManager.toggleFavorite(photo),
          ),

        if (hasSelectedPhotos)
          PopupMenuItem(
            child: const Text('Seçili Fotoğrafları Sil'),
            onTap: () {
              List<Photo> photosToDelete = List.from(homeViewModel.selectedPhotos);
              for (var selectedPhoto in photosToDelete) {
                photoManager.deletePhoto(selectedPhoto);
              }
              homeViewModel.clearPhotoSelections();
            },
          )
        else
          PopupMenuItem(
            child: const Text('Sil'),
            onTap: () => photoManager.deletePhoto(photo),
          ),

        if (hasSelectedPhotos)
          PopupMenuItem(
            child: const Text('Seçimi Temizle'),
            onTap: () => homeViewModel.clearPhotoSelections(),
          )
        else
          PopupMenuItem(
            child: const Text('Seç'),
            onTap: () => homeViewModel.togglePhotoSelection(photo),
          ),

        // Rating options for selected photos
        if (hasSelectedPhotos)
          for (int rating = 1; rating <= 5; rating++)
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text('Seçili Fotoğraflara $rating Puan Ver'),
                ],
              ),
              onTap: () => homeViewModel.setRatingForSelectedPhotos(photoManager, rating),
            ),

        // Tag options for selected photos
        if (hasSelectedPhotos && tagManager.tags.isNotEmpty)
          PopupMenuItem(
            onTap: null,
            child: const Text('Seçili Fotoğraflara Etiket Ekle/Çıkar'),
          ),

        // Show all available tags for selected photos
        if (hasSelectedPhotos)
          for (var tag in tagManager.tags)
            PopupMenuItem(
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tag.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(tag.name),
                ],
              ),
              onTap: () => homeViewModel.toggleTagForSelectedPhotos(tagManager, tag),
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
