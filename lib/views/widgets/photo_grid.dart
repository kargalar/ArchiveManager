import 'dart:async';
import 'dart:io';
import 'package:archive_manager_v3/models/sort_state.dart';
import 'package:archive_manager_v3/viewmodels/home_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart' as sdd;
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../models/tag.dart';
import '../../managers/folder_manager.dart';
import '../../managers/photo_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/settings_manager.dart';
import '../../managers/filter_manager.dart';
import '../../utils/photo_sorter.dart';
import 'full_screen_image.dart';

class PhotoGrid extends StatefulWidget {
  const PhotoGrid({super.key});

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  // Scroll controller to enable programmatic scrolling
  final ScrollController _scrollController = ScrollController();

  // Keep a DragItemWidgetState key per photo so we can build multi-item drags
  final Map<String, GlobalKey<sdd.DragItemWidgetState>> _dragKeysByPath = {};

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
        setState(() {}); // Trigger a rebuild to apply sorting
      }
    });
  }

  @override
  void dispose() {
    // Cancel timer and dispose scroll controller when widget is disposed
    _cleanupTimer?.cancel();
    _scrollController.dispose();
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
    }

    // Tarih sıralaması değişti mi?
    if (_lastDateSortState != filterManager.dateSortState) {
      _lastDateSortState = filterManager.dateSortState;
      sortStateChanged = true;
    }

    // Puan sıralaması değişti mi?
    if (_lastRatingSortState != filterManager.ratingSortState) {
      _lastRatingSortState = filterManager.ratingSortState;
      sortStateChanged = true;
    }

    // Herhangi bir sıralama değiştiyse, yeniden render et
    if (sortStateChanged) {
      // Use Future.microtask to avoid setState during build
      Future.microtask(() {
        if (mounted) {
          setState(() {});
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
              if (key.length == 1 && RegExp(r'[0-9]').hasMatch(key)) {
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

    // Use PhotoSorter utility to sort photos
    List<Photo> sortedPhotos = PhotoSorter.sort(
      filteredPhotos,
      ratingSortState: filterManager.ratingSortState,
      dateSortState: filterManager.dateSortState,
      resolutionSortState: filterManager.resolutionSortState,
    );

    return Column(
      children: [
        // Selection status bar - only visible when photos are selected
        if (homeViewModel.hasSelectedPhotos)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
    return LayoutBuilder(builder: (context, constraints) {
      // Keep selected item visible when navigating with arrow keys
      final selected = homeViewModel.selectedPhoto;
      final selectedIndex = selected != null ? sortedPhotos.indexOf(selected) : -1;

      if (selectedIndex >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Compute tile height (square tiles with default aspectRatio=1)
          final photosPerRow = settingsManager.photosPerRow;
          // Grid padding and spacing
          const double horizontalPadding = 16; // EdgeInsets.all(8)
          const double topPadding = 8;
          const double mainAxisSpacing = 0;
          final double tileWidth = (constraints.maxWidth - horizontalPadding) / photosPerRow;
          final double tileHeight = tileWidth; // aspect ratio 1.0

          final int row = selectedIndex ~/ photosPerRow;
          final double itemTop = topPadding + row * (tileHeight + mainAxisSpacing);
          final double itemBottom = itemTop + tileHeight;

          final double viewportTop = _scrollController.offset;
          final double viewportBottom = viewportTop + constraints.maxHeight;

          double? targetOffset;
          const double viewportPadding = 8;

          if (itemTop < viewportTop + viewportPadding) {
            targetOffset = (itemTop - viewportPadding).clamp(0.0, _scrollController.position.maxScrollExtent);
          } else if (itemBottom > viewportBottom - viewportPadding) {
            targetOffset = (itemBottom - constraints.maxHeight + viewportPadding).clamp(0.0, _scrollController.position.maxScrollExtent);
          }

          if (targetOffset != null && (targetOffset - viewportTop).abs() > 1.0) {
            // Check if scroll controller is currently animating
            if (_scrollController.position.isScrollingNotifier.value) {
              // If already scrolling, jump immediately to avoid lag during key repeat
              _scrollController.jumpTo(targetOffset);
            } else {
              // Otherwise use smooth animation
              _scrollController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
              );
            }
          }
        });
      }

      return GridView.builder(
        controller: _scrollController,
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

          // The interactive tile with existing behavior
          final Widget tile = RepaintBoundary(
            child: Listener(
              onPointerDown: (event) {
                if (event.buttons == kMiddleMouseButton) {
                  // Tıklanan fotoğrafı seçili fotoğraf olarak ayarla
                  homeViewModel.setSelectedPhoto(photo);

                  // Mark as viewed when opening fullscreen via middle click
                  photo.markViewed();

                  // Tam ekran görünümüne geç
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      settings: const RouteSettings(name: 'fullscreen_image'),
                      pageBuilder: (context, animation, secondaryAnimation) => FullScreenImage(
                        photo: photo,
                        filteredPhotos: sortedPhotos,
                      ),
                    ),
                  );
                }
              },
              child: GestureDetector(
                onTap: () {
                  // Get keyboard modifiers
                  final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                  final bool isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
                  final bool selectionModeActive = homeViewModel.hasSelectedPhotos;

                  // Mark as viewed on any tap interaction
                  photo.markViewed();

                  // Shift+click: select range from anchor (primary selected) to tapped photo
                  if (isShiftPressed && homeViewModel.selectedPhoto != null) {
                    homeViewModel.selectRange(sortedPhotos, photo);
                  }
                  // Ctrl+click or existing selection: toggle individual selection
                  else if (isCtrlPressed || selectionModeActive) {
                    homeViewModel.togglePhotoSelection(photo);
                  }
                  // Otherwise, normal selection
                  else {
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

          // Wrap tile with native drag source for dragging to Desktop/Explorer
          return sdd.DragItemWidget(
            // Assign a persistent key so we can reference this item when building multi-drag
            key: _dragKeysByPath.putIfAbsent(photo.path, () => GlobalKey<sdd.DragItemWidgetState>()),
            dragItemProvider: (request) async {
              final item = sdd.DragItem();
              try {
                // Her DragItem bu karo ile ilişkili tek bir dosyayı temsil etsin
                debugPrint('Preparing drag item for: ${photo.path}');
                item.add(sdd.Formats.fileUri(Uri.file(photo.path)));
              } catch (e) {
                debugPrint('DragItemProvider error: $e');
                return null;
              }
              return item;
            },
            allowedOperations: () => [sdd.DropOperation.copy],
            child: sdd.DraggableWidget(
              // Build a multi-item drag when there are selected photos
              dragItemsProvider: (ctx) {
                final vm = Provider.of<HomeViewModel>(ctx, listen: false);
                final List<sdd.DragItemWidgetState> items = [];

                // Always include this tile as primary item if available
                final key = _dragKeysByPath[photo.path];
                final currentState = key?.currentState;
                if (currentState != null) {
                  items.add(currentState);
                }

                // If multi-select is active, include other visible selected tiles
                if (vm.hasSelectedPhotos) {
                  for (final selected in vm.selectedPhotos) {
                    if (selected.path == photo.path) continue; // already added
                    final skey = _dragKeysByPath[selected.path];
                    final sState = skey?.currentState;
                    if (sState != null) {
                      items.add(sState);
                    }
                  }
                }

                // This returns 1..N items (one per file). Platforms like Windows Explorer
                // will treat this as a multi-file drag and copy all of them.
                return items;
              },
              child: tile,
            ),
          );
        },
      );
    });
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
                        padding: const EdgeInsets.all(5),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.favorite, size: 16, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Text('Seçili Fotoğrafları Favorilere Ekle/Çıkar'),
              ],
            ),
            onTap: () => homeViewModel.toggleFavoriteForSelectedPhotos(photoManager),
          )
        else
          PopupMenuItem(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.favorite_outline, size: 16, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Text('Favorilere Ekle/Çıkar'),
              ],
            ),
            onTap: () => photoManager.toggleFavorite(photo),
          ),

        if (hasSelectedPhotos)
          PopupMenuItem(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Text('Seçili Fotoğrafları Sil'),
              ],
            ),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Text('Sil'),
              ],
            ),
            onTap: () => photoManager.deletePhoto(photo),
          ),

        if (hasSelectedPhotos)
          PopupMenuItem(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                const Text('Seçimi Temizle'),
              ],
            ),
            onTap: () => homeViewModel.clearPhotoSelections(),
          )
        else
          PopupMenuItem(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.folder_open_outlined, size: 16, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text('Windows\'ta Göster'),
              ],
            ),
            onTap: () => photoManager.openInExplorer(photo),
          ),
        PopupMenuItem(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              const Text('Seç'),
            ],
          ),
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
        // Show NEW badge if photo not viewed yet
        if (!photo.isViewed)
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(102), // 0.4 opacity
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Yeni',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
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
          right: 0,
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
