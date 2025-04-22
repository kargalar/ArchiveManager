// HomePage üst menü ve appbar kısmını widgetlaştırdık
import 'package:archive_manager_v3/models/sort_state.dart';
import 'package:archive_manager_v3/views/dialogs/missing_folders_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../managers/folder_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/filter_manager.dart';
import '../dialogs/settings_dialog.dart';

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
        Consumer3<FolderManager, TagManager, FilterManager>(
          builder: (context, folderManager, tagManager, filterManager, child) {
            return Row(
              children: [
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
                        children: tagManager.tags
                            .map((tag) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: InkWell(
                                    onTap: () => tagManager.toggleTagFilter(tag),
                                    onSecondaryTap: () => tagManager.removeTagFilter(tag),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: tagManager.selectedTags.contains(tag) ? tag.color.withAlpha(204) : tag.color.withAlpha(51), // 0.8 and 0.2 opacity
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: tagManager.selectedTags.contains(tag) ? tag.color : tag.color.withAlpha(128), // 0.5 opacity
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        tag.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tagManager.selectedTags.contains(tag) ? Colors.white : Colors.white70,
                                          fontWeight: tagManager.selectedTags.contains(tag) ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
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
                          max: 7,
                          divisions: 5,
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
                    filterManager.setRatingFilter(0, 7);
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
