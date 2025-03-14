import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
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
                  child: Text(
                    folderName,
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
