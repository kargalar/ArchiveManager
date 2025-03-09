import 'package:archive_manager_v3/models/folder.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/photo.dart';
import 'models/tag.dart';
import 'viewmodels/photo_view_model.dart';
import 'views/home_page.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(TagAdapter());
  final photoBox = await Hive.openBox<Photo>('photos');
  final folderBox = await Hive.openBox<Folder>('folders');
  final tagBox = await Hive.openBox<Tag>('tags');
  runApp(MyApp(photoBox: photoBox, folderBox: folderBox, tagBox: tagBox));
}

class MyApp extends StatelessWidget {
  final Box<Photo> photoBox;
  final Box<Folder> folderBox;
  final Box<Tag> tagBox;

  const MyApp({super.key, required this.photoBox, required this.folderBox, required this.tagBox});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PhotoViewModel(photoBox, folderBox, tagBox),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Photo Archive Manager',
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.blue,
            secondary: Colors.blueAccent,
            surface: Colors.grey[900]!,
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
