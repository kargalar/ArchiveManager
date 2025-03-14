import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../viewmodels/photo_view_model.dart';
import '../../viewmodels/home_view_model.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FocusScope(
        child: Focus(
          autofocus: true,
          onKey: (node, event) {
            if (event is RawKeyDownEvent) {
              final homeViewModel = context.read<HomeViewModel>();
              final photoViewModel = context.read<PhotoViewModel>();
              if (event.logicalKey == LogicalKeyboardKey.keyF) {
                if (homeViewModel.selectedPhoto != null) {
                  photoViewModel.toggleFavorite(homeViewModel.selectedPhoto!);
                  return KeyEventResult.handled;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                  event.logicalKey == LogicalKeyboardKey.digit2 ||
                  event.logicalKey == LogicalKeyboardKey.digit3 ||
                  event.logicalKey == LogicalKeyboardKey.digit4 ||
                  event.logicalKey == LogicalKeyboardKey.digit5) {
                if (homeViewModel.selectedPhoto != null) {
                  final rating = int.parse(event.logicalKey.keyLabel);
                  photoViewModel.setRating(
                      homeViewModel.selectedPhoto!, rating);
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: Consumer2<PhotoViewModel, HomeViewModel>(
            builder: (context, photoViewModel, homeViewModel, child) {
              if (photoViewModel.selectedFolder == null) {
                return const Center(
                  child: Text('Select a folder to view images'),
                );
              }

              return Column(
                children: [
                  _buildSortingControls(photoViewModel),
                  Expanded(
                    child: _buildGrid(context, photoViewModel, homeViewModel),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSortingControls(PhotoViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<String>(
        value: null,
        hint: const Text('Sort by Rating'),
        items: const [
          DropdownMenuItem(value: 'asc', child: Text('Rating (Low to High)')),
          DropdownMenuItem(value: 'desc', child: Text('Rating (High to Low)')),
          DropdownMenuItem(value: 'clear', child: Text('Clear Sort')),
        ],
        onChanged: (value) {
          if (value == 'asc') {
            viewModel.sortPhotosByRating(ascending: true);
          } else if (value == 'desc') {
            viewModel.sortPhotosByRating(ascending: false);
          } else {
            viewModel.selectFolder(viewModel.selectedFolder);
          }
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context, PhotoViewModel photoViewModel,
      HomeViewModel homeViewModel) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: photoViewModel.photosPerRow,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photoViewModel.photos.length,
      itemBuilder: (context, index) {
        final photo = photoViewModel.photos[index];
        return GestureDetector(
          onTap: () => homeViewModel.handlePhotoTap(photo),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPhotoContainer(photo, homeViewModel),
              _buildPhotoOverlay(photo, photoViewModel),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoContainer(Photo photo, HomeViewModel homeViewModel) {
    return Container(
      decoration: BoxDecoration(
        border: homeViewModel.selectedPhoto == photo
            ? Border.all(color: Colors.blue, width: 2)
            : null,
      ),
      child: Image.file(
        File(photo.path),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPhotoOverlay(Photo photo, PhotoViewModel viewModel) {
    return Stack(
      children: [
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              if (photo.rating > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }
}
