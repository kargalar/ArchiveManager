import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../managers/folder_manager.dart';

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

    void showDeleteConfirmation() {
      // First close the confirmation dialog
      showDialog(
        context: context,
        builder: (BuildContext confirmContext) {
          return AlertDialog(
            title: const Text('Delete Folder'),
            content: Text('Are you sure you want to delete "$folderName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(confirmContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
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
                        child: const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 20),
                              Text('Deleting folder...'),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  // Delete the folder
                  folderManager.removeFolder(folder).then((_) {
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
                            title: const Text('Error'),
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
        Padding(
          padding: EdgeInsets.only(left: 8.0 * level),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF3A3A3A) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
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
                          items: [
                            PopupMenuItem(
                              child: Row(
                                children: [
                                  Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: isFavorite ? Colors.amber : null),
                                  const SizedBox(width: 8),
                                  Text(isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                                ],
                              ),
                              onTap: () {
                                Future.delayed(Duration.zero, () {
                                  folderManager.toggleFavorite(folder);
                                });
                              },
                            ),
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete'),
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
                              child: const Row(
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Open in Explorer'),
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
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Row(
                    children: [
                      if (hasChildren)
                        InkWell(
                          onTap: () => folderManager.toggleFolderExpanded(folder),
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 4),
                      Icon(
                        isFavorite ? Icons.folder_special_rounded : Icons.folder_rounded,
                        size: 20,
                        color: isFavorite ? Colors.amber : (isSelected ? Colors.blue : null),
                      ),
                      const SizedBox(width: 8),
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
