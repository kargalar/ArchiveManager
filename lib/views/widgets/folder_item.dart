import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../managers/folder_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/photo_manager.dart';
import '../../models/photo.dart';
import '../../viewmodels/home_view_model.dart';

// Widget that displays a folder and its subfolders in the folder tree.
// Includes folder selection, deletion, favorite marking, and opening in explorer.
class FolderItem extends StatelessWidget {
  final String folder;
  final int level;
  final void Function(BuildContext context, String folder)? onMissingFolder;

  const FolderItem({
    super.key,
    required this.folder,
    required this.level,
    this.onMissingFolder,
  });

  @override
  Widget build(BuildContext context) {
    final folderManager = context.watch<FolderManager>();
    final hasChildren = folderManager.folderHierarchy[folder]?.isNotEmpty ?? false;
    final isExpanded = folderManager.isFolderExpanded(folder);
    final isSelected = folderManager.selectedFolder == folder;
    final folderName = folderManager.getFolderName(folder);
    final isMissing = folderManager.missingFolders.contains(folder); // Check if folder is missing
    final isFavorite = folderManager.isFavorite(folder); // Check if folder is a favorite

    // Check if any parent folder is missing
    bool hasParentMissing = false;
    String currentPath = folder;
    while (currentPath.contains(Platform.pathSeparator)) {
      currentPath = currentPath.substring(0, currentPath.lastIndexOf(Platform.pathSeparator));
      if (folderManager.missingFolders.contains(currentPath)) {
        hasParentMissing = true;
        break;
      }
    }

    // Folder is problematic if it's missing or has a missing parent
    final isProblematic = isMissing || hasParentMissing;

    void showRemoveConfirmation() {
      showDialog(
        context: context,
        builder: (BuildContext confirmContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 16),
                const Text('Remove from List'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remove this folder from the application list? The folder will remain on your computer.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folderName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                if (folderManager.folderHierarchy[folder]?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'All subfolders will also be removed from the list.',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(confirmContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // Close the confirmation dialog
                  Navigator.of(confirmContext).pop();

                  // Then show a loading dialog
                  final loadingDialogKey = GlobalKey<State>();
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) {
                      return Dialog(
                        key: loadingDialogKey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              const CircularProgressIndicator(),
                              const SizedBox(width: 24),
                              Text(
                                'Removing from list...',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  // Remove the folder from list only
                  folderManager.removeFolderFromList(folder).then((_) {
                    // Close the loading dialog if it's still open
                    if (loadingDialogKey.currentContext != null) {
                      Navigator.of(loadingDialogKey.currentContext!).pop();
                    }
                  }).catchError((error) {
                    // Close the loading dialog if it's still open
                    if (loadingDialogKey.currentContext != null) {
                      Navigator.of(loadingDialogKey.currentContext!).pop();
                    }
                    // Show error dialog if the widget is still mounted
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (BuildContext errorContext) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
                                ),
                                const SizedBox(width: 16),
                                const Text('Error'),
                              ],
                            ),
                            content: Text('Failed to remove folder from list: $error'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(errorContext).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  });
                },
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );
    }

    void showDeleteConfirmation() {
      showDialog(
        context: context,
        builder: (BuildContext confirmContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 16),
                const Text('Delete Folder'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to permanently delete this folder? It will be moved to the recycle bin.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folderName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                if (folderManager.folderHierarchy[folder]?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'All subfolders will also be deleted.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(confirmContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // Close the confirmation dialog
                  Navigator.of(confirmContext).pop();

                  // Then show a loading dialog
                  final loadingDialogKey = GlobalKey<State>();
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) {
                      return Dialog(
                        key: loadingDialogKey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              const CircularProgressIndicator(),
                              const SizedBox(width: 24),
                              Text(
                                'Deleting folder...',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  // Delete the folder permanently to recycle bin
                  folderManager.deleteFolderToRecycleBin(folder).then((_) {
                    // Close the loading dialog if it's still open
                    if (loadingDialogKey.currentContext != null) {
                      Navigator.of(loadingDialogKey.currentContext!).pop();
                    }
                  }).catchError((error) {
                    // Close the loading dialog if it's still open
                    if (loadingDialogKey.currentContext != null) {
                      Navigator.of(loadingDialogKey.currentContext!).pop();
                    }
                    // Show error dialog if the widget is still mounted
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (BuildContext errorContext) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
                                ),
                                const SizedBox(width: 16),
                                const Text('Error'),
                              ],
                            ),
                            content: Text('Failed to delete folder: $error'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(errorContext).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  });
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<Photo>(
          // onWillAcceptWithDetails: (data) => data != null,
          onAcceptWithDetails: (details) async {
            final photoManager = Provider.of<PhotoManager>(context, listen: false);
            final homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
            // If dragging a selected photo, move all selected photos
            if (homeViewModel.hasSelectedPhotos && homeViewModel.selectedPhotos.contains(details.data)) {
              for (var photo in List<Photo>.from(homeViewModel.selectedPhotos)) {
                await photoManager.movePhotoToFolder(photo, folder);
              }
              homeViewModel.clearPhotoSelections();
            } else {
              // Single photo move
              await photoManager.movePhotoToFolder(details.data, folder);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Padding(
              padding: EdgeInsets.only(left: 8.0 * level),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3A3A3A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected ? Border.all(color: Colors.blue.withAlpha(50), width: 1) : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onSecondaryTap: isProblematic
                        ? null
                        : () {
                            final RenderBox button = context.findRenderObject() as RenderBox;
                            final position = button.localToGlobal(Offset.zero);
                            showMenu(
                              context: context,
                              position: RelativeRect.fromLTRB(
                                position.dx,
                                position.dy + button.size.height,
                                position.dx + button.size.width,
                                position.dy + button.size.height + 100,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 8,
                              items: [
                                PopupMenuItem(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isFavorite ? Colors.amber.withAlpha(30) : Colors.grey.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                          size: 16,
                                          color: isFavorite ? Colors.amber : Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Future.delayed(Duration.zero, () {
                                      folderManager.toggleFavorite(folder);
                                    });
                                  },
                                ),
                                PopupMenuItem(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.orange),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Remove from List', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                  onTap: () {
                                    // We need to use Future.delayed because onTap is called before the menu is closed
                                    Future.delayed(Duration.zero, () {
                                      showRemoveConfirmation();
                                    });
                                  },
                                ),
                                // Tag with... submenu
                                PopupMenuItem(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.label, size: 16, color: Colors.green),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Tag with...', style: TextStyle(fontSize: 13)),
                                      const Spacer(),
                                      const Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                  onTap: () {
                                    Future.delayed(Duration.zero, () {
                                      _showTagMenu(context, folder);
                                    });
                                  },
                                ),
                                PopupMenuItem(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Delete Permanently', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                  onTap: () {
                                    // We need to use Future.delayed because onTap is called before the menu is closed
                                    Future.delayed(Duration.zero, () {
                                      showDeleteConfirmation();
                                    });
                                  },
                                ),
                                PopupMenuItem(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.folder_open_rounded, size: 16, color: Colors.blue),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Open in Explorer', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                  onTap: () => Process.start('explorer.exe', [folder]),
                                ),
                              ],
                            );
                          },
                    onTap: () {
                      final folderExists = Directory(folder).existsSync();
                      if (!folderExists) {
                        if (onMissingFolder != null) {
                          onMissingFolder!(context, folder);
                        }
                      } else {
                        folderManager.clearSectionSelection(); // Clear any section selection
                        folderManager.selectFolder(folder);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      child: Row(
                        children: [
                          if (hasChildren)
                            Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withAlpha(30) : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => folderManager.toggleFolderExpanded(folder),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: AnimatedRotation(
                                      turns: isExpanded ? 0.25 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: isSelected ? Colors.blue : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 8),
                          Icon(
                            isFavorite ? Icons.folder_special_rounded : Icons.folder_rounded,
                            size: 20,
                            color: isFavorite ? Colors.amber : (isSelected ? Colors.blue : null),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isProblematic || !Directory(folder).existsSync())
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4.0),
                                        child: Icon(Icons.warning_amber_rounded, color: hasParentMissing ? Colors.red : Colors.orange, size: 16),
                                      ),
                                    Expanded(
                                      child: Text(
                                        folderName,
                                        style: TextStyle(
                                          color: isSelected ? Colors.blue : (hasParentMissing ? Colors.red : (isMissing ? Colors.orange : Colors.white)),
                                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                // Show auto-tags if any exist
                                Consumer<FolderManager>(
                                  builder: (context, folderManager, child) {
                                    final allTags = <String, dynamic>{}; // Map to avoid duplicates by tag id

                                    // Get all parent paths for this folder
                                    final parentPaths = _getParentPaths(folder);

                                    // Collect auto-tags from all parent paths
                                    for (var path in parentPaths) {
                                      final folderObj = folderManager.getFolderObject(path);
                                      if (folderObj?.autoTags.isNotEmpty == true) {
                                        for (var tag in folderObj!.autoTags) {
                                          allTags[tag.id] = tag;
                                        }
                                      }
                                    }

                                    // Also add auto-tags from the current folder itself
                                    final currentFolderObj = folderManager.getFolderObject(folder);
                                    if (currentFolderObj?.autoTags.isNotEmpty == true) {
                                      for (var tag in currentFolderObj!.autoTags) {
                                        allTags[tag.id] = tag;
                                      }
                                    }

                                    if (allTags.isNotEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: allTags.values.map((tag) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: tag.color.withAlpha(80),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: tag.color.withAlpha(120),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Text(
                                                tag.name,
                                                style: TextStyle(
                                                  color: tag.color,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (isExpanded && hasChildren)
          ...folderManager.folderHierarchy[folder]!.map(
            (childPath) => FolderItem(
              folder: childPath,
              level: level + 1,
              onMissingFolder: onMissingFolder,
            ),
          ),
      ],
    );
  }

  void _showTagMenu(BuildContext context, String folderPath) {
    final tagManager = Provider.of<TagManager>(context, listen: false);
    final folderManager = Provider.of<FolderManager>(context, listen: false);
    final photoManager = Provider.of<PhotoManager>(context, listen: false);

    final folder = folderManager.getFolderObject(folderPath);
    if (folder == null) return;

    // Get all available tags
    final availableTags = tagManager.tags;

    if (availableTags.isEmpty) {
      // Show message if no tags exist
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Text('No Tags Available'),
              ],
            ),
            content: const Text('Create some tags first to use auto-tagging.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.label, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Auto-Tag Folder')),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select tags to automatically apply to all photos in this folder:',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 500),
                      child: SingleChildScrollView(
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 4.5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: availableTags.length,
                          itemBuilder: (context, index) {
                            final tag = availableTags[index];
                            final isSelected = folder.hasAutoTag(tag);
                            return Container(
                              decoration: BoxDecoration(
                                color: isSelected ? tag.color.withAlpha(30) : Colors.grey.withAlpha(10),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? tag.color.withAlpha(100) : Colors.grey.withAlpha(30),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: tag.color.withAlpha(50),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.label,
                                    color: tag.color,
                                    size: 16,
                                  ),
                                ),
                                title: Text(
                                  tag.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Transform.scale(
                                  scale: 0.8,
                                  child: Checkbox(
                                    value: isSelected,
                                    activeColor: tag.color,
                                    onChanged: (value) async {
                                      setState(() {
                                        if (value == true) {
                                          folder.addAutoTag(tag);
                                          // Apply the tag to existing photos in the folder
                                          photoManager.applyAutoTagsToFolderPhotos(folderPath, [tag]);
                                        } else {
                                          folder.removeAutoTag(tag);
                                          // Remove the tag from photos in the folder (only auto-applied ones)
                                          photoManager.removeAutoTagFromFolderPhotos(folderPath, tag);
                                        }
                                      });
                                      // Save the folder object
                                      await folder.save();
                                      // FolderManager'ı güncelle ki UI anında yenilensin
                                      folderManager.triggerTagUpdate();
                                    },
                                  ),
                                ),
                                onTap: () async {
                                  setState(() {
                                    if (folder.hasAutoTag(tag)) {
                                      folder.removeAutoTag(tag);
                                      photoManager.removeAutoTagFromFolderPhotos(folderPath, tag);
                                    } else {
                                      folder.addAutoTag(tag);
                                      photoManager.applyAutoTagsToFolderPhotos(folderPath, [tag]);
                                    }
                                  });
                                  // Save the folder object
                                  await folder.save();
                                  // FolderManager'ı güncelle ki UI anında yenilensin
                                  folderManager.triggerTagUpdate();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Get all parent directory paths for a folder path
  List<String> _getParentPaths(String folderPath) {
    final List<String> paths = [];
    final separator = Platform.pathSeparator;
    final parts = folderPath.split(separator);

    // Remove the folder name (last part)
    parts.removeLast();

    // Build cumulative paths
    String currentPath = '';
    for (var part in parts) {
      if (part.isNotEmpty) {
        currentPath += (currentPath.isEmpty ? '' : separator) + part;
        paths.add(currentPath);
      }
    }

    return paths;
  }
}
