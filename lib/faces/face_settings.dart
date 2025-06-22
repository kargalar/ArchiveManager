import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../faces/face_filter_manager.dart';
import '../faces/faces_section.dart'; // Import the FacesSection widget
import '../faces/face_detection_start_dialog.dart';
import '../managers/photo_manager.dart';

class FaceSettingsDialog extends StatelessWidget {
  const FaceSettingsDialog({super.key});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Face Detection Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              final faceFilterManager = Provider.of<FaceFilterManager>(context, listen: false);
              final photoManager = Provider.of<PhotoManager>(context, listen: false);
              faceFilterManager.resetFilters(photos: photoManager.photos);

              // Show confirmation message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Face detection data reset for all photos'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Reset Face Filters'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FacesSection()),
              );
            },
            child: const Text('Go to Faces Section'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Start Face Detection'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const FaceDetectionStartDialog(),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
