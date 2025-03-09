import 'dart:io';

import 'package:archive_manager_v3/models/folder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/photo.dart';
import 'viewmodels/photo_view_model.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(FolderAdapter());
  final photoBox = await Hive.openBox<Photo>('photos');
  await Hive.openBox<Folder>('folders');
  runApp(MyApp(photoBox: photoBox));
}

class MyApp extends StatelessWidget {
  final Box<Photo> photoBox;

  const MyApp({super.key, required this.photoBox});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PhotoViewModel(photoBox),
      child: MaterialApp(
        title: 'Photo Archive Manager',
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.blue,
            secondary: Colors.blueAccent,
            surface: Colors.grey[900]!,
            background: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[900],
            elevation: 0,
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

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
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    context.read<PhotoViewModel>().handleKeyEvent(event, selectedPhoto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Archive Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Ayarlar'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Satır Başına Fotoğraf Sayısı'),
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
                              Text('${viewModel.photosPerRow} fotoğraf'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tamam'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left side - Folder List
          Container(
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
                      final folder =
                          context.watch<PhotoViewModel>().folders[index];
                      final hasChildren = context
                              .watch<PhotoViewModel>()
                              .folderHierarchy[folder]
                              ?.isNotEmpty ??
                          false;
                      final isExpanded = context
                          .watch<PhotoViewModel>()
                          .isFolderExpanded(folder);
                      final isRoot = !context
                          .watch<PhotoViewModel>()
                          .folderHierarchy
                          .values
                          .any((list) => list.contains(folder));

                      if (!isRoot) return const SizedBox.shrink();

                      return _buildFolderItem(context, folder, 0);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Right side - Image Grid
          Expanded(
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
                          Image.file(
                            File(photo.path),
                            fit: BoxFit.cover,
                            cacheHeight: 500,
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
        ],
      ),
    );
  }
}

Widget _buildFolderItem(BuildContext context, String folderPath, int level) {
  final viewModel = context.watch<PhotoViewModel>();
  final hasChildren =
      viewModel.folderHierarchy[folderPath]?.isNotEmpty ?? false;
  final isExpanded = viewModel.isFolderExpanded(folderPath);
  final isSelected = viewModel.selectedFolder == folderPath;
  final folderName = viewModel.getFolderName(folderPath);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        onTap: () => viewModel.selectFolder(folderPath),
        child: Container(
          padding: EdgeInsets.only(left: 16.0 * level),
          height: 40,
          child: Row(
            children: [
              if (hasChildren)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                  ),
                  onPressed: () => viewModel.toggleFolderExpanded(folderPath),
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
        ...viewModel.folderHierarchy[folderPath]!.map(
          (childPath) => _buildFolderItem(context, childPath, level + 1),
        ),
    ],
  );
}
