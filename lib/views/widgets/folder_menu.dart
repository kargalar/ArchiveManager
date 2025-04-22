import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../managers/folder_manager.dart';
import 'folder_item.dart';
import '../dialogs/missing_folders_dialog.dart';

/// A widget that displays the folder navigation menu on the left side of the home page.
/// Shows favorite folders and all folders in a hierarchical structure.
class FolderMenu extends StatelessWidget {
  final double dividerPosition;

  const FolderMenu({
    super.key,
    required this.dividerPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (dividerPosition * 100).toInt(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Favorite Folders Section
          Consumer<FolderManager>(
            builder: (context, folderManager, child) {
              final favoriteFolders = folderManager.favoriteFolders;
              if (favoriteFolders.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
                    child: Row(
                      children: [
                        // Clickable arrow icon for expanding/collapsing
                        InkWell(
                          onTap: () {
                            // Toggle section expansion
                            folderManager.toggleFavoriteSectionExpanded();
                          },
                          child: Icon(
                            folderManager.isFavoriteSectionExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                        // Clickable section title to show all photos
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              // Select section to view all photos
                              folderManager.selectFavoritesSection();
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Favorite Folders',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: folderManager.selectedSection == 'favorites' ? Colors.blue : Colors.amber,
                                  ),
                                ),
                                if (folderManager.selectedSection == 'favorites')
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Icon(Icons.photo_library, color: Colors.blue, size: 14),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Colors.grey),
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
              return Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
                child: Row(
                  children: [
                    // Clickable arrow icon for expanding/collapsing
                    InkWell(
                      onTap: () {
                        // Toggle section expansion
                        folderManager.toggleAllFoldersSectionExpanded();
                      },
                      child: Icon(
                        folderManager.isAllFoldersSectionExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                        size: 16,
                      ),
                    ),
                    // Clickable section title to show all photos
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          // Select section to view all photos
                          folderManager.selectAllFoldersSection();
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.folder, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'All Folders',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: folderManager.selectedSection == 'all' ? Colors.blue : Colors.white,
                              ),
                            ),
                            if (folderManager.selectedSection == 'all')
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.photo_library, color: Colors.blue, size: 14),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Colors.grey),
          Consumer<FolderManager>(
            builder: (context, folderManager, child) {
              if (!folderManager.isAllFoldersSectionExpanded) {
                return const SizedBox.shrink();
              }

              return Expanded(
                child: ListView.builder(
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
              );
            },
          ),
        ],
      ),
    );
  }
}
