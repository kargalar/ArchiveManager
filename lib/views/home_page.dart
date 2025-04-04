import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';
import '../models/sort_state.dart';
import '../models/tag.dart';
import '../viewmodels/photo_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'widgets/folder_item.dart';
import 'widgets/photo_grid.dart';
import 'widgets/full_screen_image.dart';
import 'widgets/keyboard_shortcuts_guide.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeViewModel _homeViewModel;
  bool _isMenuExpanded = true;
  double _dividerPosition = 0.3;

  @override
  void initState() {
    super.initState();
    _homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
    RawKeyboard.instance.addListener(_handleKeyEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final photoViewModel = context.read<PhotoViewModel>();
      _homeViewModel.handleKeyEvent(event, context, photoViewModel);

      // ve zaten tam ekranda değilse
      if (event.logicalKey == LogicalKeyboardKey.enter && _homeViewModel.selectedPhoto != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenImage(photo: _homeViewModel.selectedPhoto!),
          ),
        );
      }
    }
  }

  void _handlePointerEvent(PointerEvent event) {
    if (event is PointerScrollEvent && RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlLeft)) {
      final delta = event.scrollDelta.dy;
      final viewModel = context.read<PhotoViewModel>();
      if (delta < 0) {
        viewModel.setPhotosPerRow(viewModel.photosPerRow + 1);
      } else if (delta > 0) {
        viewModel.setPhotosPerRow(viewModel.photosPerRow - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 20, 20, 20),
        surfaceTintColor: Colors.transparent,
        leadingWidth: 400,
        leading: Row(
          children: [
            SizedBox(width: 5),
            IconButton(
              icon: Icon(_isMenuExpanded ? Icons.menu_open : Icons.menu),
              onPressed: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
            ),
            SizedBox(width: 5),
            IconButton(
              icon: Icon(Icons.create_new_folder),
              onPressed: () async {
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  // ignore: use_build_context_synchronously
                  context.read<PhotoViewModel>().addFolder(result);
                }
              },
            ),
            SizedBox(width: 10),
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
        flexibleSpace: DragToMoveArea(
          child: Container(),
        ),
        actions: [
          Consumer<PhotoViewModel>(
            builder: (context, viewModel, child) {
              return Row(
                children: [
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
                      icon: Icon(
                        _getFavoriteIcon(viewModel.favoriteFilterMode),
                        color: _getFavoriteColor(viewModel.favoriteFilterMode),
                      ),
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
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // _buildFolderList(),
          if (_isMenuExpanded) ...[
            Expanded(
              flex: (_dividerPosition * 100).toInt(),
              child: ListView.builder(
                itemCount: context.watch<PhotoViewModel>().folders.length,
                itemBuilder: (context, index) {
                  final folder = context.watch<PhotoViewModel>().folders[index];
                  final isRoot = !context.watch<PhotoViewModel>().folderHierarchy.values.any((list) => list.contains(folder));
                  if (!isRoot) return const SizedBox.shrink();
                  return FolderItem(folder: folder, level: 0);
                },
              ),
            ),
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _dividerPosition += details.delta.dx / MediaQuery.of(context).size.width;
                  _dividerPosition = _dividerPosition.clamp(0.1, 0.3);
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 1,
                    color: Colors.grey[300],
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            flex: ((1 - _dividerPosition) * 100).toInt(),
            child: _buildPhotoGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return const PhotoGrid();
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

  void _showEditTagDialog(BuildContext context, Tag tag) {
    final TextEditingController controller = TextEditingController(text: tag.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tag Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final photoViewModel = Provider.of<PhotoViewModel>(context, listen: false);
                photoViewModel.updateTagName(tag, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4, maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Klavye kısayolları rehberi
                        const KeyboardShortcutsGuide(),
                        const Text('Photos per Row', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Consumer<PhotoViewModel>(
                          builder: (context, viewModel, child) {
                            return Column(
                              children: [
                                Slider(
                                  value: viewModel.photosPerRow.toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  label: viewModel.photosPerRow.toString(),
                                  onChanged: (value) {
                                    viewModel.setPhotosPerRow(value.toInt());
                                  },
                                ),
                                Text('${viewModel.photosPerRow} photos'),
                              ],
                            );
                          },
                        ),
                        Row(
                          children: [
                            const Text('Tag Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Tag'),
                              onPressed: () => _showAddTagDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Consumer<PhotoViewModel>(
                          builder: (context, viewModel, child) {
                            final tags = viewModel.tagBox.values.toList();
                            return tags.isEmpty
                                ? const Text('No tags created yet')
                                : Column(
                                    children: tags
                                        .map(
                                          (tag) => Card(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            child: ListTile(
                                                leading: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: tag.color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                title: Text(tag.name),
                                                subtitle: Text('Shortcut: ${tag.shortcutKey.keyLabel}'),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit),
                                                      onPressed: () => _showEditTagDialog(
                                                        context,
                                                        tag,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete),
                                                      onPressed: () {
                                                        viewModel.deleteTag(tag);
                                                      },
                                                    ),
                                                  ],
                                                )),
                                          ),
                                        )
                                        .toList(),
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    LogicalKeyboardKey? selectedShortcutKey;

    final List<Color> predefinedColors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4, maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add New Tag', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tag Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Select Color:', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (context, setColorState) => SizedBox(
                    height: 150,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: predefinedColors.length,
                      itemBuilder: (context, index) {
                        final color = predefinedColors[index];
                        return InkWell(
                          onTap: () {
                            setColorState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color ? Colors.white : Colors.grey,
                                width: selectedColor == color ? 2 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Shortcut Key: '),
                    const SizedBox(width: 8),
                    StatefulBuilder(
                      builder: (context, setShortcutState) => Row(
                        children: [
                          Text(selectedShortcutKey?.keyLabel ?? 'None'),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Press a key'),
                                  content: RawKeyboardListener(
                                    focusNode: FocusNode()..requestFocus(),
                                    onKey: (event) {
                                      if (event is RawKeyDownEvent) {
                                        selectedShortcutKey = event.logicalKey;
                                        setShortcutState(() {});
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: const SizedBox(
                                      height: 100,
                                      child: Center(
                                        child: Text('Press any key to set as shortcut'),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: const Text('Set Shortcut'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty && selectedShortcutKey != null) {
                          final tag = Tag(
                            name: nameController.text,
                            color: selectedColor,
                            shortcutKey: selectedShortcutKey!,
                          );
                          context.read<PhotoViewModel>().addTag(tag);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
