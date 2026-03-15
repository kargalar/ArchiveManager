import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../managers/folder_manager.dart';
import '../managers/photo_manager.dart';
import '../managers/settings_manager.dart';
import '../viewmodels/home_view_model.dart';
import '../services/input_controller.dart';
import 'widgets/full_screen_image.dart';
import 'widgets/photo_grid.dart';
import 'dialogs/missing_folders_dialog.dart';
import 'dialogs/settings_dialog.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/folder_menu.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeViewModel _homeViewModel;
  late InputController _inputController;
  bool _isMenuExpanded = true;
  bool _showExpandIcon = false;
  bool _isSettingsPanelOpen = false;
  double _folderMenuWidth = 250; // Fixed initial width for folder menu

  @override
  void initState() {
    super.initState();
    _homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
    _inputController = InputController();
    ServicesBinding.instance.keyboard.addHandler(_handleKeyboardEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);

    final folderManager = Provider.of<FolderManager>(context, listen: false);
    final photoManager = Provider.of<PhotoManager>(context, listen: false);
    final settingsManager = Provider.of<SettingsManager>(context, listen: false);

    // Load folder menu width from settings
    _folderMenuWidth = settingsManager.folderMenuWidth;

    // Listen for changes in SettingsManager
    settingsManager.addListener(() {
      if (mounted && _folderMenuWidth != settingsManager.folderMenuWidth) {
        setState(() {
          _folderMenuWidth = settingsManager.folderMenuWidth;
        });
      }
    });

    // Klasör veya bölüm seçildiğinde fotoğrafları yükle - optimized version
    String? lastSelectedFolder;
    String? lastSelectedSection;

    folderManager.addListener(() {
      // Only reload photos if the selection has actually changed
      if (folderManager.selectedFolder != lastSelectedFolder || folderManager.selectedSection != lastSelectedSection) {
        // Update tracking variables
        lastSelectedFolder = folderManager.selectedFolder;
        lastSelectedSection = folderManager.selectedSection;

        // Load photos based on selection
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
    // Fullscreen açıkken klavye event'lerini HomePage tarafında işlemeyelim.
    if (FullScreenImage.isActive) {
      return false;
    }
    // Dialog açıkken kısayolları devre dışı bırak
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    // TextField gibi text input'lara focus varken kısayolları devre dışı bırak
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      bool isTextInput = false;
      primaryFocus.context!.visitAncestorElements((element) {
        if (element.widget is EditableText) {
          isTextInput = true;
          return false;
        }
        return true;
      });
      if (isTextInput) {
        return false; // Text input'taysa event'i serbest bırak
      }
    }
    // Sadece KeyDown ve arrow tuşlarında KeyRepeat işle
    final isArrowKey = event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (event is! KeyDownEvent && !(event is KeyRepeatEvent && isArrowKey)) {
      return false; // KeyUp vb. olayları serbest bırak
    }
    // InputController ile handle et
    _inputController.processKeyEvent(event, context, _homeViewModel);
    return true; // Kısayol işlendi, event'i tüket (handled)
  }

  void _handlePointerEvent(PointerEvent event) {
    // Fullscreen açıkken pointer (Ctrl+Scroll) grid ayarlarını değiştirmesin.
    if (FullScreenImage.isActive) {
      return;
    }
    final settingsManager = Provider.of<SettingsManager>(context, listen: false);
    _inputController.handlePointerEvent(event, context, settingsManager);
  }

  void _toggleSettingsPanel() {
    setState(() => _isSettingsPanelOpen = !_isSettingsPanelOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(
        isSettingsPanelOpen: _isSettingsPanelOpen,
        onSettingsToggle: _toggleSettingsPanel,
        width: MediaQuery.of(context).size.width,
      ),
      body: Stack(
        children: [
          Row(
            children: [
              if (_isMenuExpanded) ...[
                GestureDetector(
                  onTap: () => setState(() => _isMenuExpanded = false),
                  child: FolderMenu(width: _folderMenuWidth),
                ),
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _folderMenuWidth += details.delta.dx;
                      _folderMenuWidth = _folderMenuWidth.clamp(200.0, 400.0); // Limit width between 200 and 400 pixels
                    });
                  },
                  onPanEnd: (_) {
                    final settingsManager = Provider.of<SettingsManager>(context, listen: false);
                    settingsManager.setFolderMenuWidth(_folderMenuWidth);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: Container(
                      width: 8,
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: 2,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: const PhotoGrid(),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: _isSettingsPanelOpen ? 420 : 0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: SizedBox(
                  width: 420,
                  child: _isSettingsPanelOpen ? SettingsPanel(onClose: _toggleSettingsPanel) : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          if (!_isMenuExpanded)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _showExpandIcon ? 80 : 30, // Much wider when showing icon, and 30 to detect hover easily
              child: MouseRegion(
                onEnter: (_) => setState(() => _showExpandIcon = true),
                onExit: (_) => setState(() => _showExpandIcon = false),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isMenuExpanded = true;
                    _showExpandIcon = false;
                  }),
                  child: _showExpandIcon
                      ? Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: const Icon(Icons.arrow_forward_ios, size: 24, color: Colors.white),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
