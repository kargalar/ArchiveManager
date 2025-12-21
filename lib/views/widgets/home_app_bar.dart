import 'package:archive_manager_v3/models/sort_state.dart';
import 'package:archive_manager_v3/views/dialogs/missing_folders_dialog.dart';
import 'package:archive_manager_v3/views/dialogs/duplicate_photos_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../managers/folder_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/filter_manager.dart';
import '../../managers/photo_manager.dart';
import '../../models/indexing_state.dart';
import '../../models/photo.dart';
import '../dialogs/settings_dialog.dart';

// Extension to add darken method to Color
extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isMenuExpanded;
  final VoidCallback onMenuToggle;
  final VoidCallback onCreateFolder;
  final double width;
  const HomeAppBar({
    super.key,
    required this.isMenuExpanded,
    required this.onMenuToggle,
    required this.onCreateFolder,
    required this.width,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 20, 20, 20),
      surfaceTintColor: Colors.transparent,
      leadingWidth: 400,
      leading: Row(
        children: [
          const SizedBox(width: 5),
          IconButton(
            icon: Icon(isMenuExpanded ? Icons.menu_open : Icons.menu),
            onPressed: onMenuToggle,
          ),
          const SizedBox(width: 5),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: onCreateFolder,
          ),
          const SizedBox(width: 10),
          Consumer<FolderManager>(
            builder: (context, folderManager, child) {
              return Text(
                folderManager.selectedFolder != null ? folderManager.getFolderName(folderManager.selectedFolder!) : 'Photo Archive Manager',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
      ),
      flexibleSpace: DragToMoveArea(child: Container()),
      actions: [
        Consumer4<FolderManager, TagManager, FilterManager, PhotoManager>(
          builder: (context, folderManager, tagManager, filterManager, photoManager, child) {
            // Filtrelenmiş fotoğraf sayısını hesapla
            final filteredCount = filterManager.filterPhotos(photoManager.photos, tagManager.selectedTags).length;
            return Row(
              children: [
                // Fotoğraf sayısı göstergesi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$filteredCount fotoğraf',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                // Yenile butonu
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Yenile',
                  onPressed: () async {
                    // Seçili klasör varsa onu, yoksa tüm klasörleri yenile
                    if (folderManager.selectedFolder != null) {
                      await photoManager.loadPhotosFromFolder(folderManager.selectedFolder!);
                    } else {
                      await photoManager.loadPhotosFromMultipleFolders(folderManager.folders);
                    }
                  },
                ),
                // Show indexing progress using StreamBuilder - always show regardless of selected folder
                StreamBuilder<IndexingState>(
                  stream: photoManager.indexingStream,
                  initialData: photoManager.currentIndexingState,
                  builder: (context, snapshot) {
                    final indexingState = snapshot.data;
                    // Always show indexing progress if any indexing is happening
                    if (indexingState != null && indexingState.isIndexing) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: LinearProgressIndicator(
                                value: indexingState.progress,
                                backgroundColor: Colors.grey[800],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              indexingState.statusText,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink(); // Empty widget when not indexing
                  },
                ),
                if (folderManager.missingFolders.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.warning, color: Colors.orange, size: 24),
                    tooltip: "Eksik klasörler",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => MissingFoldersDialog(initialMissingFolders: folderManager.missingFolders),
                      );
                    },
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onSecondaryTap: () => filterManager.resetFavoriteFilter(),
                  child: IconButton(
                    icon: Icon(_getFavoriteIcon(filterManager.favoriteFilterMode)),
                    color: _getFavoriteColor(filterManager.favoriteFilterMode),
                    onPressed: () => filterManager.toggleFavoritesFilter(),
                    tooltip: _getFavoriteTooltip(filterManager.favoriteFilterMode),
                  ),
                ),
                // Yeni (görülmemiş) filtre düğmesi: none -> only new -> only non-new -> none
                GestureDetector(
                  onSecondaryTap: () => filterManager.resetNewFilter(),
                  child: IconButton(
                    icon: Icon(_getNewIcon(filterManager.newFilterMode)),
                    color: _getNewColor(filterManager.newFilterMode),
                    onPressed: () => filterManager.toggleNewFilter(),
                    tooltip: _getNewTooltip(filterManager.newFilterMode),
                  ),
                ),

                // Color filter (dominant color category)
                GestureDetector(
                  onSecondaryTap: () => filterManager.resetColorFilter(),
                  child: PopupMenuButton<PhotoColorCategory?>(
                    tooltip: 'Renk Filtresi (sağ tık: temizle)',
                    icon: Icon(
                      Icons.palette,
                      color: filterManager.colorFilter == null ? Colors.white70 : _colorSwatch(filterManager.colorFilter!),
                    ),
                    onSelected: (value) {
                      filterManager.setColorFilter(value);
                    },
                    itemBuilder: (context) {
                      const gridColumns = 6;
                      const gridSpacing = 8.0;
                      const gridWidth = 240.0;
                      final colorCount = PhotoColorCategory.values.length;
                      final gridRows = (colorCount / gridColumns).ceil();
                      final tileSize = (gridWidth - (gridColumns - 1) * gridSpacing) / gridColumns;
                      final gridHeight = gridRows * tileSize + (gridRows - 1) * gridSpacing;

                      return <PopupMenuEntry<PhotoColorCategory?>>[
                        PopupMenuItem<PhotoColorCategory?>(
                          enabled: false,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: SizedBox(
                            width: gridWidth,
                            height: gridHeight,
                            child: GridView.count(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: PhotoColorCategory.values.map((c) {
                                final isSelected = filterManager.colorFilter == c;
                                return InkWell(
                                  onTap: () => Navigator.of(context).pop<PhotoColorCategory?>(c),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _colorSwatch(c),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.white24,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ];
                    },
                  ),
                ),

                GestureDetector(
                  onSecondaryTap: () {
                    filterManager.resetTagFilter();
                    tagManager.clearTagFilters();
                  },
                  child: IconButton(
                    icon: Icon(
                      filterManager.tagFilterMode == 'none'
                          ? Icons.label_outline
                          : filterManager.tagFilterMode == 'untagged'
                              ? Icons.label_off
                              : filterManager.tagFilterMode == 'tagged'
                                  ? Icons.label
                                  : Icons.label, // filtered mode
                      color: filterManager.tagFilterMode == 'none'
                          ? Colors.white70
                          : filterManager.tagFilterMode == 'untagged'
                              ? Colors.green
                              : filterManager.tagFilterMode == 'tagged'
                                  ? Colors.blue
                                  : Colors.orange, // filtered mode
                    ),
                    onPressed: () {
                      if (tagManager.selectedTags.isNotEmpty) {
                        filterManager.setTagFilterMode('filtered');
                      } else {
                        filterManager.toggleTagFilterMode();
                      }
                    },
                    tooltip: filterManager.tagFilterMode == 'none'
                        ? 'Filter by Tags'
                        : filterManager.tagFilterMode == 'untagged'
                            ? 'Show Untagged Only'
                            : filterManager.tagFilterMode == 'tagged'
                                ? 'Show Tagged Only'
                                : 'Clear Tag Filters',
                  ),
                ),
                Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: RangeSlider(
                          values: RangeValues(filterManager.minRatingFilter, filterManager.maxRatingFilter),
                          min: 0,
                          max: 9,
                          divisions: 9,
                          onChanged: (RangeValues values) {
                            filterManager.setRatingFilter(values.start, values.end);
                          },
                        ),
                      ),
                      Text(
                        "${filterManager.minRatingFilter.toInt()}-${filterManager.maxRatingFilter.toInt()}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onSecondaryTap: () {
                    filterManager.setRatingFilter(0, 9);
                    filterManager.resetRatingSort();
                  },
                  child: TextButton.icon(
                    onPressed: () => filterManager.toggleRatingSort(),
                    icon: Icon(
                        filterManager.ratingSortState == SortState.ascending
                            ? Icons.arrow_upward
                            : filterManager.ratingSortState == SortState.descending
                                ? Icons.arrow_downward
                                : Icons.remove,
                        size: 16),
                    label: const Text('Rating'),
                    style: TextButton.styleFrom(
                      foregroundColor: filterManager.ratingSortState != SortState.none ? Colors.blue : Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onSecondaryTap: () {
                    filterManager.resetDateSort();
                  },
                  child: TextButton.icon(
                    onPressed: () => filterManager.toggleDateSort(),
                    icon: Icon(
                        filterManager.dateSortState == SortState.ascending
                            ? Icons.arrow_upward
                            : filterManager.dateSortState == SortState.descending
                                ? Icons.arrow_downward
                                : Icons.remove,
                        size: 16),
                    label: const Text('Date'),
                    style: TextButton.styleFrom(
                      foregroundColor: filterManager.dateSortState != SortState.none ? Colors.blue : Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onSecondaryTap: () {
                    filterManager.resetResolutionSort();
                  },
                  child: TextButton.icon(
                    onPressed: () => filterManager.toggleResolutionSort(),
                    icon: Icon(
                        filterManager.resolutionSortState == SortState.ascending
                            ? Icons.arrow_upward
                            : filterManager.resolutionSortState == SortState.descending
                                ? Icons.arrow_downward
                                : Icons.remove,
                        size: 16),
                    label: const Text('Resolution'),
                    style: TextButton.styleFrom(
                      foregroundColor: filterManager.resolutionSortState != SortState.none ? Colors.blue : Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.tune, color: Colors.white),
          tooltip: 'Özellikler',
          color: const Color.fromARGB(255, 50, 50, 50),
          onSelected: (String value) {
            switch (value) {
              case 'duplicates':
                showDialog(
                  context: context,
                  builder: (_) => const DuplicatePhotosDialog(),
                );
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'duplicates',
              child: Row(
                children: [
                  Icon(Icons.content_copy, color: Colors.white70, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Aynı Fotoğrafları Bul',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => showDialog(context: context, builder: (_) => const SettingsDialog()),
        ),
      ],
    );
  }

  IconData _getFavoriteIcon(String mode) {
    switch (mode) {
      case 'favorites':
        return Icons.favorite;
      case 'non-favorites':
        return Icons.heart_broken;
      default:
        return Icons.favorite_border;
    }
  }

  Color _getFavoriteColor(String mode) {
    switch (mode) {
      case 'favorites':
        return Colors.red;
      case 'non-favorites':
        return Colors.orange;
      default:
        return Colors.white70;
    }
  }

  String _getFavoriteTooltip(String mode) {
    switch (mode) {
      case 'favorites':
        return 'Show Non-Favorites';
      case 'non-favorites':
        return 'Clear Favorite Filter';
      default:
        return 'Show Favorites';
    }
  }

  IconData _getNewIcon(String mode) {
    switch (mode) {
      case 'new':
        return Icons.fiber_new;
      case 'non-new':
        return Icons.new_releases_outlined; // indicates the opposite state subtly
      default:
        return Icons.fiber_new_outlined;
    }
  }

  Color _getNewColor(String mode) {
    switch (mode) {
      case 'new':
        return Colors.greenAccent;
      case 'non-new':
        return Colors.amber;
      default:
        return Colors.white70;
    }
  }

  String _getNewTooltip(String mode) {
    switch (mode) {
      case 'new':
        return 'Sadece yeni (görülmemiş)';
      case 'non-new':
        return 'Sadece görülenler';
      default:
        return 'Yenileri göster';
    }
  }

  static Color _colorSwatch(PhotoColorCategory c) {
    switch (c) {
      case PhotoColorCategory.red:
        return Colors.red;
      case PhotoColorCategory.orange:
        return Colors.orange;
      case PhotoColorCategory.yellow:
        return Colors.yellow;
      case PhotoColorCategory.green:
        return Colors.green;
      case PhotoColorCategory.blue:
        return Colors.blue;
      case PhotoColorCategory.purple:
        return Colors.purple;
      case PhotoColorCategory.pink:
        return Colors.pink;
      case PhotoColorCategory.brown:
        return Colors.brown;
      case PhotoColorCategory.black:
        return Colors.black;
      case PhotoColorCategory.white:
        return Colors.white;
      case PhotoColorCategory.gray:
        return Colors.grey;
    }
  }
}
