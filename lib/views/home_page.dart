import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../viewmodels/photo_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'widgets/folder_item.dart';
import 'widgets/photo_grid.dart';
import 'widgets/full_screen_image.dart';
import 'dialogs/missing_folders_dialog.dart';
import 'widgets/home_app_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeViewModel _homeViewModel;
  bool _isMenuExpanded = true;
  double _dividerPosition = 0.3;

  @override
  void initState() {
    super.initState();
    _homeViewModel = Provider.of<HomeViewModel>(context, listen: false);
    RawKeyboard.instance.addListener(_handleKeyEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
    final missingFolders = Provider.of<PhotoViewModel>(context, listen: false).missingFolders;
    if (missingFolders.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(context: context, builder: (_) => MissingFoldersDialog(initialMissingFolders: missingFolders));
      });
    }
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final photoViewModel = context.read<PhotoViewModel>();
      _homeViewModel.handleKeyEvent(event, context, photoViewModel);
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
    if (event is PointerScrollEvent && RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlLeft)) {
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
      appBar: HomeAppBar(
        isMenuExpanded: _isMenuExpanded,
        onMenuToggle: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
        onCreateFolder: () async {
          final result = await FilePicker.platform.getDirectoryPath();
          if (result != null) {
            context.read<PhotoViewModel>().addFolder(result);
          }
        },
        width: MediaQuery.of(context).size.width,
      ),
      body: Row(
        children: [
          if (_isMenuExpanded) ...[
            Expanded(
              flex: (_dividerPosition * 100).toInt(),
              child: ListView.builder(
                itemCount: context.watch<PhotoViewModel>().folders.length,
                itemBuilder: (context, index) {
                  final folder = context.watch<PhotoViewModel>().folders[index];
                  final isRoot = !context.watch<PhotoViewModel>().folderHierarchy.values.any((list) => list.contains(folder));
                  if (!isRoot) return const SizedBox.shrink();
                  return FolderItem(
                    folder: folder,
                    level: 0,
                    onMissingFolder: (ctx, missingFolder) {
                      showDialog(context: ctx, builder: (_) => MissingFoldersDialog(initialMissingFolders: [missingFolder]));
                    },
                  );
                },
              ),
            ),
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _dividerPosition += details.delta.dx / MediaQuery.of(context).size.width;
                  _dividerPosition = _dividerPosition.clamp(0.1, 0.3);
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 1,
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
