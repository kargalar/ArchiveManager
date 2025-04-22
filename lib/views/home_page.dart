import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../managers/folder_manager.dart';
import '../managers/photo_manager.dart';
import '../managers/tag_manager.dart';
import '../managers/settings_manager.dart';
import '../viewmodels/home_view_model.dart';
import 'widgets/photo_grid.dart';
import 'widgets/full_screen_image.dart';
import 'dialogs/missing_folders_dialog.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/folder_menu.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeViewModel _homeViewModel;
  bool _isMenuExpanded = true;
  late double _dividerPosition;

  @override
  void initState() {
    super.initState();
    _homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
    ServicesBinding.instance.keyboard.addHandler(_handleKeyboardEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);

    final folderManager = Provider.of<FolderManager>(context, listen: false);
    final photoManager = Provider.of<PhotoManager>(context, listen: false);
    final settingsManager = Provider.of<SettingsManager>(context, listen: false);

    // Ayarlardan bölünmüş görünüm konumunu yükle
    _dividerPosition = settingsManager.dividerPosition;

    // SettingsManager'daki değişiklikleri dinle
    settingsManager.addListener(() {
      if (mounted && _dividerPosition != settingsManager.dividerPosition) {
        setState(() {
          _dividerPosition = settingsManager.dividerPosition;
        });
        debugPrint('DividerPosition updated from settings: $_dividerPosition');
      }
    });
    debugPrint('Initial DividerPosition: $_dividerPosition');

    // Klasör veya bölüm seçildiğinde fotoğrafları yükle
    folderManager.addListener(() {
      if (folderManager.selectedFolder != null) {
        // Load photos from a single selected folder
        photoManager.loadPhotosFromFolder(folderManager.selectedFolder!);
      } else if (folderManager.selectedSection == 'favorites') {
        // Load photos from all favorite folders
        if (folderManager.favoriteFolders.isNotEmpty) {
          photoManager.loadPhotosFromMultipleFolders(folderManager.favoriteFolders);
        } else {
          photoManager.clearPhotos();
        }
      } else if (folderManager.selectedSection == 'all') {
        // Load photos from all folders
        if (folderManager.folders.isNotEmpty) {
          photoManager.loadPhotosFromMultipleFolders(folderManager.folders);
        } else {
          photoManager.clearPhotos();
        }
      } else {
        photoManager.clearPhotos();
      }
    });

    final missingFolders = folderManager.missingFolders;
    if (missingFolders.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(context: context, builder: (_) => MissingFoldersDialog(initialMissingFolders: missingFolders));
      });
    }
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyboardEvent);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  bool _handleKeyboardEvent(KeyEvent event) {
    _handleKeyEvent(event);
    return false; // Let other handlers process the event too
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final folderManager = context.read<FolderManager>();
      final photoManager = context.read<PhotoManager>();
      final tagManager = context.read<TagManager>();
      final settingsManager = context.read<SettingsManager>();

      // F11 tuşuna basıldığında tam ekran modunu aç/kapat
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        settingsManager.toggleFullscreen();
        return;
      }

      _homeViewModel.handleKeyEvent(event, context, folderManager, photoManager, tagManager);
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
    if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
      final delta = event.scrollDelta.dy;
      final settingsManager = Provider.of<SettingsManager>(context, listen: false);
      if (delta < 0) {
        settingsManager.setPhotosPerRow(settingsManager.photosPerRow + 1);
      } else if (delta > 0) {
        settingsManager.setPhotosPerRow(settingsManager.photosPerRow - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(
        isMenuExpanded: _isMenuExpanded,
        onMenuToggle: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
        onCreateFolder: () async {
          final folderManager = Provider.of<FolderManager>(context, listen: false);
          final result = await FilePicker.platform.getDirectoryPath();
          if (result != null && mounted) {
            folderManager.addFolder(result);
          }
        },
        width: MediaQuery.of(context).size.width,
      ),
      body: Row(
        children: [
          if (_isMenuExpanded) ...[
            FolderMenu(dividerPosition: _dividerPosition),
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _dividerPosition += details.delta.dx / MediaQuery.of(context).size.width;
                  _dividerPosition = _dividerPosition.clamp(0.1, 0.3);
                });
              },
              onPanEnd: (_) {
                final settingsManager = Provider.of<SettingsManager>(context, listen: false);
                settingsManager.setDividerPosition(_dividerPosition);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 0.5,
                    color: Colors.grey[300],
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            flex: ((1 - _dividerPosition) * 100).toInt(),
            child: _buildPhotoGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() => const PhotoGrid();
}
