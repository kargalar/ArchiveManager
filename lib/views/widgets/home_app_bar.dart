// HomePage üst menü ve appbar kısmını widgetlaştırdık
import 'package:archive_manager_v3/models/sort_state.dart';
import 'package:archive_manager_v3/views/dialogs/missing_folders_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../managers/folder_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/filter_manager.dart';
import '../../managers/photo_manager.dart';
import '../../models/indexing_state.dart';
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
            return Row(
              children: [
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
                if (tagManager.tags.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: tagManager.tags.map((tag) {
                          final isPositive = filterManager.positiveTagFilters.contains(tag);
                          final isNegative = filterManager.negativeTagFilters.contains(tag);
                          Color bgColor;
                          Color borderColor;
                          Color textColor;
                          List<BoxShadow> boxShadow = [];
                          IconData? icon;
                          if (isPositive) {
                            bgColor = tag.color;
                            borderColor = tag.color.darken(0.2);
                            textColor = Colors.white;
                            icon = Icons.check;
                            boxShadow = [
                              BoxShadow(
                                color: tag.color.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ];
                          } else if (isNegative) {
                            bgColor = Colors.grey[900]!;
                            borderColor = tag.color;
                            textColor = tag.color;
                            icon = Icons.close;
                            boxShadow = [
                              BoxShadow(
                                color: tag.color.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ];
                          } else {
                            bgColor = tag.color.withAlpha(30);
                            borderColor = tag.color.withAlpha(80);
                            textColor = Colors.white70;
                            icon = null;
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => filterManager.toggleTagTriState(tag),
                              onSecondaryTap: () {
                                // Sadece bu tag'in durumunu sıfırla
                                if (filterManager.positiveTagFilters.contains(tag)) {
                                  filterManager.positiveTagFilters.remove(tag);
                                }
                                if (filterManager.negativeTagFilters.contains(tag)) {
                                  filterManager.negativeTagFilters.remove(tag);
                                }
                                // Filtre modunu güncelle
                                if (filterManager.positiveTagFilters.isEmpty && filterManager.negativeTagFilters.isEmpty) {
                                  filterManager.setTagFilterMode('none');
                                }
                                // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                                filterManager.notifyListeners();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isPositive ? 2 : 1,
                                  ),
                                  boxShadow: boxShadow,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (icon != null) ...[
                                      Icon(icon, size: 16, color: textColor),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      tag.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textColor,
                                        fontWeight: isPositive ? FontWeight.bold : FontWeight.normal,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
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
}
