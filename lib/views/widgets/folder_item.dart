import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../managers/folder_manager.dart';
import '../../models/photo.dart';
import '../../managers/photo_manager.dart';
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
                            child: Row(
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
}
