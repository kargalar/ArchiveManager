import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../managers/folder_manager.dart';
import 'folder_item.dart';
import '../dialogs/missing_folders_dialog.dart';

/// A widget that displays the folder navigation menu on the left side of the home page.
/// Shows favorite folders and all folders in a hierarchical structure.
class FolderMenu extends StatefulWidget {
  final double dividerPosition;

  const FolderMenu({
    super.key,
    required this.dividerPosition,
  });

  @override
  State<FolderMenu> createState() => _FolderMenuState();
}

class _FolderMenuState extends State<FolderMenu> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
        flex: (widget.dividerPosition * 100).toInt(),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51), // 20% opacity
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.fromLTRB(4, 4, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              _buildSearchBar(context),
              // Favorite Folders Section
              Consumer<FolderManager>(
                builder: (context, folderManager, child) {
                  final favoriteFolders = folderManager.favoriteFolders;
                  if (favoriteFolders.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              // Select section to view all photos
                              folderManager.selectFavoritesSection();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  // Clickable arrow icon for expanding/collapsing
                                  InkWell(
                                    onTap: () {
                                      // Toggle section expansion
                                      folderManager.toggleFavoriteSectionExpanded();
                                    },
                                    child: AnimatedRotation(
                                      turns: folderManager.isFavoriteSectionExpanded ? 0.25 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: const Icon(
                                        Icons.chevron_right,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  // Clickable section title to show all photos
                                  Expanded(
                                    child: Text(
                                      'Favorite Folders',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: folderManager.selectedSection == 'favorites' ? Colors.blue : Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (folderManager.selectedSection == 'favorites')
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4.0),
                                      child: Icon(Icons.photo_library_rounded, color: Colors.blue, size: 16),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (folderManager.isFavoriteSectionExpanded) ...[
                        ...favoriteFolders.map((folder) => FolderItem(
                              folder: folder,
                              level: 0,
                              onMissingFolder: (ctx, missingFolder) {
                                showDialog(context: ctx, builder: (_) => MissingFoldersDialog(initialMissingFolders: [missingFolder]));
                              },
                            )),
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                },
              ),

              // All Folders Section
              Consumer<FolderManager>(
                builder: (context, folderManager, child) {
                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          // Select section to view all photos
                          folderManager.selectAllFoldersSection();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            children: [
                              // Clickable arrow icon for expanding/collapsing
                              InkWell(
                                onTap: () {
                                  // Toggle section expansion
                                  folderManager.toggleAllFoldersSectionExpanded();
                                },
                                child: AnimatedRotation(
                                  turns: folderManager.isAllFoldersSectionExpanded ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.folder_rounded, size: 18),
                              const SizedBox(width: 8),
                              // Clickable section title to show all photos
                              Expanded(
                                child: Text(
                                  'All Folders',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: folderManager.selectedSection == 'all' ? Colors.blue : Colors.white,
                                  ),
                                ),
                              ),
                              if (folderManager.selectedSection == 'all')
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.photo_library_rounded, color: Colors.blue, size: 16),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Consumer<FolderManager>(
                builder: (context, folderManager, child) {
                  if (!folderManager.isAllFoldersSectionExpanded) {
                    return const SizedBox.shrink();
                  }

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: folderManager.folders.length,
                        itemBuilder: (context, index) {
                          final folder = folderManager.folders[index];
                          final isRoot = !folderManager.folderHierarchy.values.any((list) => list.contains(folder));
                          if (!isRoot) return const SizedBox.shrink();
                          return FolderItem(
                            folder: folder,
                            level: 0,
                            onMissingFolder: (ctx, missingFolder) {
                              showDialog(context: ctx, builder: (_) => MissingFoldersDialog(initialMissingFolders: [missingFolder]));
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ));
  }

  // Search bar widget
  Widget _buildSearchBar(BuildContext context) {
    return Consumer<FolderManager>(
      builder: (context, folderManager, child) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF3A3A3A), width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {}); // Rebuild to show/hide clear button
                folderManager.filterFolders(value);
              },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search folders...',
                hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF8A8A8A)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF8A8A8A)),
                        onPressed: () {
                          _searchController.clear();
                          folderManager.filterFolders('');
                          setState(() {}); // Rebuild to hide clear button
                        },
                        constraints: const BoxConstraints(maxHeight: 32, maxWidth: 32),
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
            ),
          ),
        );
      },
    );
  }
}
