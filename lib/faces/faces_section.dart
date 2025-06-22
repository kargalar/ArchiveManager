import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../faces/face_filter_manager.dart';
import '../managers/photo_manager.dart';

class FacesSection extends StatelessWidget {
  const FacesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final faceFilterManager = Provider.of<FaceFilterManager>(context);
    final photoManager = Provider.of<PhotoManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faces Section'),
      ),
      body: ListView.builder(
        itemCount: photoManager.photos.length,
        itemBuilder: (context, index) {
          final photo = photoManager.photos[index];
          return ListTile(
            title: Text(photo.path),
            subtitle: Text('Faces detected: ${photo.faces.length}'),
            onTap: () {
              if (photo.faces.isNotEmpty) {
                faceFilterManager.selectFace(photo.faces.first);
                Navigator.pop(context);
              }
            },
          );
        },
      ),
    );
  }
}
