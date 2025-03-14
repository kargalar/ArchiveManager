import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/sort_state.dart';
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
          _buildPhotoGrid(),
        ],
      ),
    );
  }

  Widget _buildFolderList() {
    return Container(
      width: 250,
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
    final nameController = TextEditingController();
    final shortcutController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Photos per Row'),
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
              const Divider(),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Consumer<PhotoViewModel>(
                builder: (context, viewModel, child) {
                  return Column(
                    children: [
                      ...viewModel.tags.map((tag) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: tag.tagColor,
                              radius: 12,
                            ),
                            title: Text(tag.name),
                            subtitle: Text('Shortcut: ${tag.shortcut}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => viewModel.removeTag(tag),
                            ),
                          )),
                      const Divider(),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tag Name',
                          hintText: 'Enter tag name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Color: '),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Pick a color'),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: selectedColor,
                                      onColorChanged: (color) {
                                        selectedColor = color;
                                      },
                                      pickerAreaHeightPercent: 0.8,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: selectedColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: shortcutController,
                        decoration: const InputDecoration(
                          labelText: 'Shortcut Key',
                          hintText: 'Enter a single character',
                        ),
                        maxLength: 1,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (nameController.text.isNotEmpty && shortcutController.text.isNotEmpty) {
                            viewModel.addTag(
                              nameController.text,
                              selectedColor,
                              shortcutController.text,
                            );
                            nameController.clear();
                            shortcutController.clear();
                          }
                        },
                        child: const Text('Add Tag'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
