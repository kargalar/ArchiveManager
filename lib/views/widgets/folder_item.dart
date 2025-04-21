import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../viewmodels/photo_view_model.dart';

class FolderItem extends StatelessWidget {
  final String folder;
  final int level;

  const FolderItem({
    super.key,
    required this.folder,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PhotoViewModel>();
    final hasChildren = viewModel.folderHierarchy[folder]?.isNotEmpty ?? false;
    final isExpanded = viewModel.isFolderExpanded(folder);
    final isSelected = viewModel.selectedFolder == folder;
    final folderName = viewModel.getFolderName(folder);
    final isMissing = viewModel.missingFolders.contains(folder); // Check if folder is missing

    // Check if any parent folder is missing
    bool hasParentMissing = false;
    String currentPath = folder;
    while (currentPath.contains(Platform.pathSeparator)) {
      currentPath = currentPath.substring(0, currentPath.lastIndexOf(Platform.pathSeparator));
      if (viewModel.missingFolders.contains(currentPath)) {
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
                  viewModel.removeFolder(folder).then((_) {
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
        InkWell(
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
                        child: const Text('Delete'),
                        onTap: () {
                          // We need to use Future.delayed because onTap is called before the menu is closed
                          Future.delayed(Duration.zero, () {
                            showDeleteConfirmation();
                          });
                        },
                      ),
                      PopupMenuItem(
                        child: const Text('Open in Explorer'),
                        onTap: () => Process.start('explorer.exe', [folder]),
                      ),
                    ],
                  );
                },
          child: InkWell(
            onTap: () => viewModel.selectFolder(folder),
            child: Container(
              padding: EdgeInsets.only(left: 16.0 * level),
              height: 36,
              child: Row(
                children: [
                  if (hasChildren)
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
                        size: 20,
                      ),
                      onPressed: () => viewModel.toggleFolderExpanded(folder),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    const SizedBox(width: 20),
                  const Icon(Icons.folder, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        if (isProblematic) // Conditionally display warning icon
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.warning, color: hasParentMissing ? Colors.red : Colors.orange, size: 16),
                          ),
                        Expanded(
                          child: Text(
                            folderName,
                            style: TextStyle(
                              color: isSelected ? Colors.blue : (hasParentMissing ? Colors.red : (isMissing ? Colors.orange : Colors.white)),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        if (isExpanded && hasChildren)
          ...viewModel.folderHierarchy[folder]!.map(
            (childPath) => FolderItem(folder: childPath, level: level + 1),
          ),
      ],
    );
  }
}
