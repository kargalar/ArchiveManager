// main.dart: Uygulamanın giriş noktası ve Provider ile MVVM yapısı kurulumu
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
// Model ve Manager importları
import 'models/photo.dart';
import 'models/folder.dart';
import 'models/tag.dart';
import 'models/settings.dart';
import 'models/color_adapter.dart';
import 'models/keyboard_key_adapter.dart';
import 'managers/folder_manager.dart';
import 'managers/photo_manager.dart';
import 'managers/tag_manager.dart';
import 'managers/settings_manager.dart';
import 'managers/filter_manager.dart';
import 'managers/file_system_watcher.dart';
import 'viewmodels/home_view_model.dart';
// PhotoViewModel artık kullanılmıyor, doğrudan manager sınıfları kullanılıyor
import 'views/home_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Pencere ayarları (Windows için)
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

  // Hive ve adapter kayıtları
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
        // Manager providers
        ChangeNotifierProvider(
          create: (context) => FolderManager(folderBox, photoBox),
        ),
        ChangeNotifierProvider(
          create: (context) => PhotoManager(photoBox),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsManager(),
        ),
        ChangeNotifierProvider(
          create: (context) => FilterManager(),
        ),
        // TagManager needs FilterManager, so we connect them with ProxyProvider
        ChangeNotifierProxyProvider<FilterManager, TagManager>(
          create: (context) => TagManager(),
          update: (context, filterManager, tagManager) {
            tagManager!.setFilterManager(filterManager);
            return tagManager;
          },
        ),
        // FileSystemWatcher needs FolderManager, so we create it with ProxyProvider
        ProxyProvider<FolderManager, FileSystemWatcher>(
          update: (context, folderManager, _) => FileSystemWatcher(folderBox, folderManager.folders, folderManager.missingFolders),
        ),
        // ViewModel providers
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
