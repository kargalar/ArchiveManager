// Eksik klasörler için gösterilen dialog widget'ı
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../managers/folder_manager.dart';

class MissingFoldersDialog extends StatelessWidget {
  final List<String> initialMissingFolders;
  const MissingFoldersDialog({super.key, required this.initialMissingFolders});

  @override
  Widget build(BuildContext context) {
    final folderManager = Provider.of<FolderManager>(context, listen: false);
    List<String> filteredMissingFolders = initialMissingFolders.where((folder) {
      return !folderManager.isSubfolderOfMissingFolder(folder);
    }).toList();
    List<String> currentMissingFolders = List.from(filteredMissingFolders);
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Eksik Klasörler'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aşağıdaki klasörler bulunamadı. Lütfen yeni bir yol seçin veya kaldırın:'),
                  const SizedBox(height: 16),
                  if (currentMissingFolders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('Tüm klasör sorunları çözüldü.', style: TextStyle(color: Colors.green)),
                    )
                  else
                    ...currentMissingFolders.map((folderPath) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  folderManager.getFolderName(folderPath),
                                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final result = await FilePicker.platform.getDirectoryPath();
                                  if (result != null && context.mounted) {
                                    // Loading dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (BuildContext loadingContext) {
                                        return const Dialog(
                                          child: Padding(
                                            padding: EdgeInsets.all(20.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(),
                                                SizedBox(width: 20),
                                                Text('Replacing folder...'),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                    await folderManager.replaceFolder(folderPath, result);
                                    if (context.mounted && Navigator.canPop(context)) Navigator.pop(context); // Close loading
                                    setState(() {
                                      currentMissingFolders.remove(folderPath);
                                    });
                                    await folderManager.checkFoldersExistence();
                                  }
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                child: const Text("Yeni Path Seç"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  // Loading dialog
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext loadingContext) {
                                      return const Dialog(
                                        child: Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(width: 20),
                                              Text('Deleting folder...'),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                  await folderManager.removeFolder(folderPath);
                                  if (context.mounted && Navigator.canPop(context)) Navigator.pop(context); // Close loading
                                  setState(() {
                                    currentMissingFolders.remove(folderPath);
                                  });
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text("Sil"),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }
}
