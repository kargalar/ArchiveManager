// main.dart: Uygulamanın giriş noktası ve Provider ile MVVM yapısı kurulumu
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
// Use window_manager on desktop platforms, and a stub implementation on web
import 'package:window_manager/window_manager.dart' if (dart.library.html) 'utils/web_window_manager.dart';
import 'package:provider/provider.dart';
// Model ve Manager importları
import 'models/photo.dart';
import 'models/folder.dart';
import 'models/tag.dart';
import 'models/settings.dart';
import 'models/color_adapter.dart';
import 'models/keyboard_key_adapter.dart';
import 'models/datetime_adapter.dart';
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

  // Sadece desktop platformlarda window manager'ı başlat
  final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  if (isDesktop) {
    await windowManager.ensureInitialized();

    // Pencere kapatma olayını dinle
    windowManager.setPreventClose(true);

    // Minimal pencere ayarları - sadece görünürlük için
    // Gerçek boyut ve konum ayarları daha sonra yüklenecek
    WindowOptions windowOptions = const WindowOptions(
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
    });
  }

  // Hive ve adapter kayıtları
  Hive.registerAdapter(ColorAdapter());
  final appDocDir = await getApplicationDocumentsDirectory();
  final hivePath = '${appDocDir.path}/Archive Manager';
  await Directory(hivePath).create(recursive: true);
  await Hive.initFlutter(hivePath);
  Hive.registerAdapter(DateTimeAdapter());
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(LogicalKeyboardKeyAdapter());
  Hive.registerAdapter(SettingsAdapter());
  final photoBox = await Hive.openBox<Photo>('photos');
  final folderBox = await Hive.openBox<Folder>('folders');
  runApp(MyApp(photoBox: photoBox, folderBox: folderBox));
}

class MyApp extends StatefulWidget {
  final Box<Photo> photoBox;
  final Box<Folder> folderBox;

  const MyApp({super.key, required this.photoBox, required this.folderBox});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  late SettingsManager _settingsManager;
  final bool _isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();

    // Sadece desktop platformlarda window manager'ı kullan
    if (_isDesktop) {
      windowManager.addListener(this);
      windowManager.setMinimumSize(const Size(800, 450));
    }

    _settingsManager = SettingsManager();

    // Uygulama başlatıldığında pencere konumunu ve boyutunu geri yükle (sadece desktop)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('Waiting for settings to initialize...');

      // Ayarların başlatılmasını bekle (en fazla 5 saniye)
      for (int i = 0; i < 50; i++) {
        if (_settingsManager.isInitialized) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('Settings initialized: ${_settingsManager.isInitialized}');

      // Sadece desktop platformlarda pencere ayarlarını uygula
      if (_isDesktop) {
        // Kaydedilen ayarlar varsa onları yükle, yoksa varsayılan ayarları kullan
        final hasSettings = await _settingsManager.restoreWindowPosition();

        if (!hasSettings) {
          debugPrint('Using default window settings');
          // Varsayılan pencere ayarlarını uygula
          await windowManager.setBounds(const Rect.fromLTWH(100, 100, 1280, 720));
          await windowManager.center();
        }

        // Tam ekran durumunu yükle
        if (_settingsManager.isFullscreen) {
          debugPrint('Restoring fullscreen state: true');
          await windowManager.setFullScreen(true);
        }

        // Her durumda pencereyi öne getir
        await windowManager.focus();

        // Debug için mevcut pencere konumunu yazdır
        final bounds = await windowManager.getBounds();
        debugPrint('Current window bounds: ${bounds.width}x${bounds.height} at (${bounds.left},${bounds.top})');
      }
    });
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isDesktop) {
      // Sadece uygulama kapat
      await windowManager.destroy();
    }
  }

  @override
  void onWindowResized() async {
    if (_isDesktop) {
      // Pencere boyutu değiştiğinde kaydet
      await _settingsManager.saveWindowPosition();
    }
  }

  @override
  void onWindowMoved() async {
    if (_isDesktop) {
      // Pencere konumu değiştiğinde kaydet
      await _settingsManager.saveWindowPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Manager providers
        ChangeNotifierProvider(
          create: (context) => FolderManager(widget.folderBox, widget.photoBox),
        ),
        // Create FilterManager and PhotoManager directly as ChangeNotifierProvider
        ChangeNotifierProvider<FilterManager>(
          create: (context) => FilterManager(),
        ),
        ChangeNotifierProvider<PhotoManager>(
          create: (context) {
            final photoManager = PhotoManager(widget.photoBox);
            final filterManager = Provider.of<FilterManager>(context, listen: false);

            // Set up the circular reference
            photoManager.setFilterManager(filterManager);
            filterManager.setPhotoManager(photoManager);

            return photoManager;
          },
        ),
        ChangeNotifierProvider.value(
          value: _settingsManager,
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
          update: (context, folderManager, _) => FileSystemWatcher(widget.folderBox, folderManager.folders, folderManager.missingFolders),
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
