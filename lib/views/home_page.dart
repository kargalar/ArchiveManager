import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/photo.dart';
import '../viewmodels/photo_view_model.dart';
import 'widgets/folder_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Photo? selectedPhoto;

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleKeyEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final viewModel = context.read<PhotoViewModel>();
      if (viewModel.photos.isEmpty) return;

      if (selectedPhoto == null) {
        setState(() {
          selectedPhoto = viewModel.photos[0];
        });
        return;
      }

      final currentIndex = viewModel.photos.indexOf(selectedPhoto!);
      final photosPerRow = viewModel.photosPerRow;
      int newIndex = currentIndex;

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
          currentIndex > 0) {
        newIndex = currentIndex - 1;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
          currentIndex < viewModel.photos.length - 1) {
        newIndex = currentIndex + 1;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          currentIndex >= photosPerRow) {
        newIndex = currentIndex - photosPerRow;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          currentIndex + photosPerRow < viewModel.photos.length) {
        newIndex = currentIndex + photosPerRow;
      } else if (event.logicalKey == LogicalKeyboardKey.enter &&
          selectedPhoto != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _buildFullScreenImage(selectedPhoto!),
          ),
        );
        return;
      } else {
        if (event.logicalKey == LogicalKeyboardKey.keyF) {
          viewModel.toggleFavorite(selectedPhoto!);
          return;
        }
        final key = event.logicalKey.keyLabel;
        if (key.length == 1 &&
            RegExp(r'[1-5]').hasMatch(key) &&
            selectedPhoto != null) {
          viewModel.setRating(selectedPhoto!, int.parse(key));
          return;
        }
        return;
      }

      if (newIndex != currentIndex) {
        setState(() {
          selectedPhoto = viewModel.photos[newIndex];
        });
      }
    }
  }

  Widget _buildFullScreenImage(Photo photo) {
    return StatefulBuilder(
      builder: (context, setState) {
        return RawKeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              final viewModel = context.read<PhotoViewModel>();
              final currentIndex = viewModel.photos.indexOf(photo);

              if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                  currentIndex > 0) {
                setState(() {
                  photo = viewModel.photos[currentIndex - 1];
                });
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                  currentIndex < viewModel.photos.length - 1) {
                setState(() {
                  photo = viewModel.photos[currentIndex + 1];
                });
              } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
                context.read<PhotoViewModel>().toggleFavorite(photo);
                setState(() {});
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
              } else {
                final key = event.logicalKey.keyLabel;
                if (key.length == 1 && RegExp(r'[1-5]').hasMatch(key)) {
                  context
                      .read<PhotoViewModel>()
                      .setRating(photo, int.parse(key));
                  setState(() {});
                }
              }
              final key = event.logicalKey.keyLabel;
              if (key.length == 1 && RegExp(r'[1-5]').hasMatch(key)) {
                context.read<PhotoViewModel>().setRating(photo, int.parse(key));
                setState(() {});
              }
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (photo.rating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: Colors.yellow),
                              const SizedBox(width: 4),
                              Text(
                                photo.rating.toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context
                            .read<PhotoViewModel>()
                            .toggleFavorite(photo),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            photo.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: photo.isFavorite ? Colors.red : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePointerEvent(PointerEvent event) {
    if (event is PointerScrollEvent &&
        RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.controlLeft)) {
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
        title: const Text('Photo Archive Manager'),
        actions: [
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
                final isRoot = !context
                    .watch<PhotoViewModel>()
                    .folderHierarchy
                    .values
                    .any((list) => list.contains(folder));
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
    return Expanded(
      child: FocusScope(
        child: Focus(
          autofocus: true,
          child: Consumer<PhotoViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.selectedFolder == null) {
                return const Center(
                  child: Text('Select a folder to view images'),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: viewModel.photosPerRow,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: viewModel.photos.length,
                itemBuilder: (context, index) {
                  final photo = viewModel.photos[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedPhoto = photo;
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: selectedPhoto == photo
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                          ),
                          child: Image.file(
                            File(photo.path),
                            fit: BoxFit.cover,
                            cacheHeight: viewModel.photosPerRow < 2
                                ? null
                                : viewModel.photosPerRow < 3
                                    ? 2000
                                    : viewModel.photosPerRow < 4
                                        ? 1500
                                        : viewModel.photosPerRow < 5
                                            ? 900
                                            : viewModel.photosPerRow < 6
                                                ? 700
                                                : viewModel.photosPerRow < 7
                                                    ? 500
                                                    : viewModel.photosPerRow < 8
                                                        ? 400
                                                        : viewModel.photosPerRow <
                                                                10
                                                            ? 300
                                                            : 200,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              if (photo.rating > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star,
                                          size: 16, color: Colors.yellow),
                                      const SizedBox(width: 4),
                                      Text(
                                        photo.rating.toString(),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => viewModel.toggleFavorite(photo),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    photo.isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 16,
                                    color: photo.isFavorite
                                        ? Colors.red
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
