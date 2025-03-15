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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeViewModel _homeViewModel;
  bool _isMenuExpanded = true;

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
        leading: IconButton(
          icon: Icon(_isMenuExpanded ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
        ),
        flexibleSpace: DragToMoveArea(
          child: Container(),
        ),
        title: Consumer<PhotoViewModel>(
          builder: (context, viewModel, child) {
            return Text(viewModel.selectedFolder != null ? viewModel.getFolderName(viewModel.selectedFolder!) : 'Photo Archive Manager');
          },
        ),
        actions: [
          Consumer<PhotoViewModel>(
            builder: (context, viewModel, child) {
              IconData arrowIcon;
              switch (viewModel.sortState) {
                case SortState.ascending:
                  arrowIcon = Icons.arrow_upward;
                  break;
                case SortState.descending:
                  arrowIcon = Icons.arrow_downward;
                  break;
                default:
                  arrowIcon = Icons.remove;
              }
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.favorite,
                      color: viewModel.showFavoritesOnly ? Colors.red : Colors.white,
                    ),
                    onPressed: () => viewModel.toggleFavoritesFilter(),
                    tooltip: 'Show Favorites Only',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.star_border_purple500_outlined,
                      color: viewModel.showUnratedOnly ? Colors.yellow : Colors.white,
                    ),
                    onPressed: () => viewModel.toggleUnratedFilter(),
                    tooltip: 'Show Unrated Only',
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
                            max: 5,
                            divisions: 5,
                            // labels: RangeLabels(
                            //   viewModel.minRatingFilter.toStringAsFixed(0),
                            //   viewModel.maxRatingFilter.toStringAsFixed(0),
                            // ),
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
                  TextButton.icon(
                    onPressed: viewModel.toggleSortState,
                    icon: Icon(arrowIcon, size: 16),
                    label: const Text('Rating'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
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
          _buildFolderList(),
          Expanded(
            child: _buildPhotoGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isMenuExpanded ? 250 : 0,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder),
            title: const Text('Add Folder'),
            onTap: () async {
              final result = await FilePicker.platform.getDirectoryPath();
              if (result != null) {
                context.read<PhotoViewModel>().addFolder(result);
              }
            },
          ),
          Expanded(
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
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return const PhotoGrid();
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                        const SizedBox(height: 24),
                        const Text('Tag Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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
                                        .map((tag) => Card(
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
                                                trailing: IconButton(
                                                  icon: const Icon(Icons.delete),
                                                  onPressed: () {
                                                    viewModel.deleteTag(tag);
                                                  },
                                                ),
                                              ),
                                            ))
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
