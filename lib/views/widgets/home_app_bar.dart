// HomePage üst menü ve appbar kısmını widgetlaştırdık
import 'package:archive_manager_v3/models/sort_state.dart';
import 'package:archive_manager_v3/views/dialogs/missing_folders_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../viewmodels/photo_view_model.dart';
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
          Consumer<PhotoViewModel>(
            builder: (context, viewModel, child) {
              return Text(
                viewModel.selectedFolder != null ? viewModel.getFolderName(viewModel.selectedFolder!) : 'Photo Archive Manager',
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
        Consumer<PhotoViewModel>(
          builder: (context, viewModel, child) {
            return Row(
              children: [
                if (viewModel.missingFolders.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.warning, color: Colors.orange, size: 24),
                    tooltip: "Eksik klasörler",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => MissingFoldersDialog(initialMissingFolders: viewModel.missingFolders),
                      );
                    },
                  ),
                if (viewModel.tags.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: viewModel.tags
                            .map((tag) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: InkWell(
                                    onTap: () => viewModel.toggleTagFilter(tag),
                                    onSecondaryTap: () => viewModel.removeTagFilter(tag),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: viewModel.selectedTags.contains(tag) ? tag.color.withOpacity(0.8) : tag.color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: viewModel.selectedTags.contains(tag) ? tag.color : tag.color.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        tag.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: viewModel.selectedTags.contains(tag) ? Colors.white : Colors.white70,
                                          fontWeight: viewModel.selectedTags.contains(tag) ? FontWeight.bold : FontWeight.normal,
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
                  onSecondaryTap: () => viewModel.resetFavoriteFilter(),
                  child: IconButton(
                    icon: Icon(_getFavoriteIcon(viewModel.favoriteFilterMode)),
                    color: _getFavoriteColor(viewModel.favoriteFilterMode),
                    onPressed: () => viewModel.toggleFavoritesFilter(),
                    tooltip: _getFavoriteTooltip(viewModel.favoriteFilterMode),
                  ),
                ),
                GestureDetector(
                  onSecondaryTap: () => viewModel.resetTagFilter(),
                  child: IconButton(
                    icon: Icon(
                      viewModel.tagFilterMode == 'none'
                          ? Icons.label_outline
                          : viewModel.tagFilterMode == 'untagged'
                              ? Icons.label_off
                              : viewModel.tagFilterMode == 'tagged'
                                  ? Icons.label
                                  : Icons.label, // filtered mode
                      color: viewModel.tagFilterMode == 'none'
                          ? Colors.white70
                          : viewModel.tagFilterMode == 'untagged'
                              ? Colors.green
                              : viewModel.tagFilterMode == 'tagged'
                                  ? Colors.blue
                                  : Colors.orange, // filtered mode
                    ),
                    onPressed: () => viewModel.toggleTagFilterMode(),
                    tooltip: viewModel.tagFilterMode == 'none'
                        ? 'Filter by Tags'
                        : viewModel.tagFilterMode == 'untagged'
                            ? 'Show Untagged Only'
                            : viewModel.tagFilterMode == 'tagged'
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
                          values: RangeValues(viewModel.minRatingFilter, viewModel.maxRatingFilter),
                          min: 0,
                          max: 7,
                          divisions: 5,
                          onChanged: (RangeValues values) {
                            viewModel.setRatingFilter(values.start, values.end);
                          },
                        ),
                      ),
                      Text(
                        "${viewModel.minRatingFilter.toInt()}-${viewModel.maxRatingFilter.toInt()}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onSecondaryTap: () {
                    viewModel.setRatingFilter(0, 7);
                    viewModel.resetRatingSort();
                  },
                  child: TextButton.icon(
                    onPressed: viewModel.toggleRatingSort,
                    icon: Icon(
                        viewModel.ratingSortState == SortState.ascending
                            ? Icons.arrow_upward
                            : viewModel.ratingSortState == SortState.descending
                                ? Icons.arrow_downward
                                : Icons.remove,
                        size: 16),
                    label: const Text('Rating'),
                    style: TextButton.styleFrom(
                      foregroundColor: viewModel.ratingSortState != SortState.none ? Colors.blue : Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onSecondaryTap: () {
                    viewModel.resetDateSort();
                  },
                  child: TextButton.icon(
                    onPressed: viewModel.toggleDateSort,
                    icon: Icon(
                        viewModel.dateSortState == SortState.ascending
                            ? Icons.arrow_upward
                            : viewModel.dateSortState == SortState.descending
                                ? Icons.arrow_downward
                                : Icons.remove,
                        size: 16),
                    label: const Text('Date'),
                    style: TextButton.styleFrom(
                      foregroundColor: viewModel.dateSortState != SortState.none ? Colors.blue : Colors.white,
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
