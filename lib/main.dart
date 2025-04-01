import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:archive_manager_v3/models/folder.dart';
import 'package:archive_manager_v3/models/keyboard_key_adapter.dart';
import 'package:archive_manager_v3/models/settings.dart';
import 'package:archive_manager_v3/models/tag.dart';
import 'package:archive_manager_v3/models/color_adapter.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'models/photo.dart';
import 'viewmodels/photo_view_model.dart';
import 'viewmodels/home_view_model.dart';
import 'views/home_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  Hive.registerAdapter(ColorAdapter());
  final appDocDir = await getApplicationDocumentsDirectory();
  final hivePath = '${appDocDir.path}/Archive Manager';
  await Directory(hivePath).create(recursive: true);
  await Hive.initFlutter(hivePath);
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(LogicalKeyboardKeyAdapter());
  Hive.registerAdapter(SettingsAdapter());
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
