import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/photo.dart';
import 'viewmodels/photo_view_model.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(PhotoAdapter());
  final photoBox = await Hive.openBox<Photo>('photos');
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
                      final folder = context.watch<PhotoViewModel>().folders[index];
                      return ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(folder),
                        selected: folder == context.watch<PhotoViewModel>().selectedFolder,
                        onTap: () {
                          context.read<PhotoViewModel>().selectFolder(folder);
                        },
                      );
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
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
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              children: [
                                if (photo.rating > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, size: 16, color: Colors.yellow),
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
                                  onTap: () => viewModel.toggleFavorite(photo),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      photo.isFavorite ? Icons.favorite : Icons.favorite_border,
                                      size: 16,
                                      color: photo.isFavorite ? Colors.red : Colors.white,
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
                  ),
          ),
        ],
      ),
    );
  }
}
