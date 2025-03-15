import 'package:archive_manager_v3/models/folder.dart';
import 'package:archive_manager_v3/models/keyboard_key_adapter.dart';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:archive_manager_v3/models/color_adapter.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/photo.dart';
import 'viewmodels/photo_view_model.dart';
import 'viewmodels/home_view_model.dart';
import 'views/home_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  Hive.registerAdapter(ColorAdapter());
  await Hive.initFlutter();
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(LogicalKeyboardKeyAdapter());
  final photoBox = await Hive.openBox<Photo>('photos');
  final folderBox = await Hive.openBox<Folder>('folders');
  runApp(MyApp(photoBox: photoBox, folderBox: folderBox));
}

class MyApp extends StatelessWidget {
  final Box<Photo> photoBox;
  final Box<Folder> folderBox;

  const MyApp({super.key, required this.photoBox, required this.folderBox});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => PhotoViewModel(photoBox, folderBox),
        ),
        ChangeNotifierProvider(
          create: (context) => HomeViewModel(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
