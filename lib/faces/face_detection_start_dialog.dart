import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/folder_manager.dart';
import '../managers/photo_manager.dart';
import '../faces/face_detection_service.dart';

class FaceDetectionStartDialog extends StatefulWidget {
  const FaceDetectionStartDialog({super.key});

  @override
  State<FaceDetectionStartDialog> createState() => _FaceDetectionStartDialogState();
}

class _FaceDetectionStartDialogState extends State<FaceDetectionStartDialog> {
  bool _isProcessing = false;
  int _processedCount = 0;
  int _totalCount = 0;

  @override
  Widget build(BuildContext context) {
    final folderManager = Provider.of<FolderManager>(context);
    final photoManager = Provider.of<PhotoManager>(context);

    return AlertDialog(
      title: const Text('Face Detection Settings'),
      content: SizedBox(
        width: 400,
        height: 350,
        child: Column(
          children: [
            const Text('Select folders to include in face detection:'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: folderManager.folders.length,
                itemBuilder: (context, index) {
                  final folderPath = folderManager.folders[index];
                  final isEnabled = folderManager.isFaceDetectionEnabled(folderPath);
                  return SwitchListTile(
                    title: Text(folderManager.getFolderName(folderPath)),
                    subtitle: Text(folderPath, style: const TextStyle(fontSize: 12)),
                    value: isEnabled,
                    onChanged: _isProcessing
                        ? null
                        : (value) {
                            debugPrint('Setting face detection for $folderPath to $value'); // Debug
                            folderManager.setFaceDetectionEnabled(folderPath, value);
                            debugPrint('Face detection enabled folders: ${folderManager.getFaceDetectionEnabledFolders()}'); // Debug
                          },
                  );
                },
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Start Face Detection'),
              onPressed: _canStartDetection(folderManager) && !_isProcessing ? () => _startFaceDetection(folderManager, photoManager) : null,
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _totalCount > 0 ? _processedCount / _totalCount : 0,
              ),
              const SizedBox(height: 8),
              Text('Processing: $_processedCount / $_totalCount photos'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isProcessing = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Stop Processing'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  bool _canStartDetection(FolderManager folderManager) {
    final enabledFolders = folderManager.getFaceDetectionEnabledFolders();
    debugPrint('Can start detection? Enabled folders: $enabledFolders'); // Debug
    return enabledFolders.isNotEmpty;
  }

  Future<void> _startFaceDetection(FolderManager folderManager, PhotoManager photoManager) async {
    setState(() {
      _isProcessing = true;
      _processedCount = 0;
    });

    final faceDetectionService = FaceDetectionService();

    // Initialize the face detection service
    try {
      await faceDetectionService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize face detection service: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize face detection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Get enabled folders for face detection
    final enabledFolders = folderManager.getFaceDetectionEnabledFolders();
    await photoManager.loadPhotosFromMultipleFolders(enabledFolders);

    // Filter photos that need face detection (only from enabled folders)
    final photosNeedingDetection = photoManager.photos.where((photo) {
      debugPrint(photo.faceDetectionDone ? 'Skipping already processed photo: ${photo.path}' : 'Processing photo: ${photo.path}'); // Debug
      // Check if the photo is from an enabled folder
      final photoFolder = photo.path.substring(0, photo.path.lastIndexOf(Platform.pathSeparator));
      return enabledFolders.any((enabledFolder) => photoFolder == enabledFolder || photoFolder.startsWith(enabledFolder + Platform.pathSeparator)) && !photo.faceDetectionDone;
    }).toList();

    setState(() {
      _totalCount = photosNeedingDetection.length;
    });

    // Process each photo for face detection
    for (int i = 0; i < photosNeedingDetection.length; i++) {
      if (!mounted || !_isProcessing) break; // Allow stopping

      final photo = photosNeedingDetection[i];
      await faceDetectionService.processPhotoForFaceDetection(photo);

      setState(() {
        _processedCount = i + 1;
      });

      // Small delay to prevent UI freezing
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (mounted) {
      // Processing completed
      setState(() {
        _isProcessing = false;
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Face detection completed! Processed $_processedCount photos.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
