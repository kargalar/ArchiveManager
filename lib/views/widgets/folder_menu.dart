import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../managers/folder_manager.dart';
import '../../faces/face_filter_manager.dart';
import '../../faces/face.dart';
import 'folder_item.dart';
import '../dialogs/missing_folders_dialog.dart';

/// A widget that displays the folder navigation menu on the left side of the home page.
/// Shows favorite folders and all folders in a hierarchical structure.
class FolderMenu extends StatefulWidget {
  final double width;

  const FolderMenu({
    super.key,
    this.width = 250, // Default fixed width of 250 pixels
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
    return SizedBox(
      width: widget.width,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 8,
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

            // Main content area (search results or regular sections)
            Expanded(
              child: Consumer<FolderManager>(
                builder: (context, folderManager, child) {
                  // If search is active, show only search results
                  if (folderManager.isSearchActive) {
                    return _buildSearchResults(context, folderManager);
                  }

                  // Otherwise show regular sections (Favorites and All Folders)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Favorite Folders Section
                      _buildFavoriteFoldersSection(context, folderManager),

                      // All Folders Section
                      _buildAllFoldersSection(context, folderManager),

                      // Faces section
                      _buildFacesSection(context, folderManager),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Search bar widget
  Widget _buildSearchBar(BuildContext context) {
    return Consumer<FolderManager>(
      builder: (context, folderManager, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
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
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12.0, right: 8.0),
                  child: Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A8A8A)),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              _searchController.clear();
                              folderManager.filterFolders('');
                              setState(() {}); // Rebuild to hide clear button
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF8A8A8A)),
                            ),
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                isDense: true,
              ),
            ),
          ),
        );
      },
    );
  }

  // Search results widget
  Widget _buildSearchResults(BuildContext context, FolderManager folderManager) {
    final filteredFolders = folderManager.filteredFolders;

    if (filteredFolders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withAlpha(128)),
            const SizedBox(height: 16),
            const Text(
              'No folders found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: filteredFolders.length,
              itemBuilder: (context, index) {
                final folder = filteredFolders[index];

                return FolderItem(
                  folder: folder,
                  level: 0, // Tüm arama sonuçlarını aynı seviyede göster
                  onMissingFolder: (ctx, missingFolder) {
                    showDialog(
                      context: ctx,
                      builder: (_) => MissingFoldersDialog(initialMissingFolders: [missingFolder]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Favorite folders section widget
  Widget _buildFavoriteFoldersSection(BuildContext context, FolderManager folderManager) {
    final favoriteFolders = folderManager.favoriteFolders;
    if (favoriteFolders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                // Select section to view all photos
                folderManager.selectFavoritesSection();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Clickable arrow icon for expanding/collapsing
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            // Toggle section expansion
                            folderManager.toggleFavoriteSectionExpanded();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: AnimatedRotation(
                              turns: folderManager.isFavoriteSectionExpanded ? 0.25 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 10),
                    // Clickable section title to show all photos
                    Expanded(
                      child: Text(
                        'Favorites',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: folderManager.selectedSection == 'favorites' ? Colors.blue : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (folderManager.isFavoriteSectionExpanded)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                ...favoriteFolders.map((folder) => FolderItem(
                      folder: folder,
                      level: 0,
                      onMissingFolder: (ctx, missingFolder) {
                        showDialog(context: ctx, builder: (_) => MissingFoldersDialog(initialMissingFolders: [missingFolder]));
                      },
                    )),
              ],
            ),
          ),
      ],
    );
  }

  // All folders section widget
  Widget _buildAllFoldersSection(BuildContext context, FolderManager folderManager) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  // Select section to view all photos
                  folderManager.selectAllFoldersSection();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Clickable arrow icon for expanding/collapsing
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              // Toggle section expansion
                              folderManager.toggleAllFoldersSectionExpanded();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: AnimatedRotation(
                                turns: folderManager.isAllFoldersSectionExpanded ? 0.25 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.folder_rounded, size: 18),
                      const SizedBox(width: 10),
                      // Clickable section title to show all photos
                      Expanded(
                        child: Text(
                          'All',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: folderManager.selectedSection == 'all' ? Colors.blue : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (folderManager.isAllFoldersSectionExpanded)
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
            ),
        ],
      ),
    );
  }

  // Faces section widget
  Widget _buildFacesSection(BuildContext context, FolderManager folderManager) {
    final faceFilterManager = Provider.of<FaceFilterManager>(context);
    final uniqueFaces = faceFilterManager.uniqueFaces;
    final facePhotoCount = faceFilterManager.facePhotoCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                // Clear face selection to show all photos with faces
                faceFilterManager.clearSelectedFace();
                folderManager.selectFacesSection();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Clickable arrow icon for expanding/collapsing
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            // Toggle section expansion
                            folderManager.toggleFacesSectionExpanded();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: AnimatedRotation(
                              turns: folderManager.isFacesSectionExpanded ? 0.25 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.face_rounded, color: Colors.blue, size: 18),
                    const SizedBox(width: 10),
                    // Clickable section title to show all photos
                    Expanded(
                      child: Text(
                        'Faces (${uniqueFaces.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: folderManager.selectedSection == 'faces' ? Colors.blue : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (folderManager.isFacesSectionExpanded)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                ...uniqueFaces.map((face) => _buildFaceItem(context, face, facePhotoCount[face.id] ?? 0, faceFilterManager, folderManager)),
              ],
            ),
          ),
      ],
    );
  }

  // Individual face item widget
  Widget _buildFaceItem(BuildContext context, Face face, int photoCount, FaceFilterManager faceFilterManager, FolderManager folderManager) {
    final isSelected = faceFilterManager.selectedFace?.id == face.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            // Select this face to filter photos
            faceFilterManager.selectFace(face);
            folderManager.selectFacesSection();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                // Face avatar/icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(50),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.blue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Face info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        face.label ?? 'Person ${face.id.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.blue : Colors.white,
                        ),
                      ),
                      Text(
                        '$photoCount photos',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.blue.withAlpha(180) : const Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.blue,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
