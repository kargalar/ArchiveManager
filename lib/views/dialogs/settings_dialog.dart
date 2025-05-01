// Widget that displays the settings dialog
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../managers/settings_manager.dart';
import '../../managers/tag_manager.dart';
import '../widgets/keyboard_shortcuts_guide.dart';
import 'tag_dialogs.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const KeyboardShortcutsGuide(),
                      const SizedBox(height: 24),
                      const Text('Photos per Row', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Consumer<SettingsManager>(
                        builder: (context, settingsManager, child) {
                          return Column(
                            children: [
                              Slider(
                                value: settingsManager.photosPerRow.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: settingsManager.photosPerRow.toString(),
                                onChanged: (value) {
                                  settingsManager.setPhotosPerRow(value.toInt());
                                },
                              ),
                              Text('${settingsManager.photosPerRow} photos'),
                            ],
                          );
                        },
                      ),
                      Row(
                        children: [
                          const Text('Tag Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Tag'),
                            onPressed: () => showDialog(context: context, builder: (_) => const AddTagDialog()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Consumer<TagManager>(
                        builder: (context, tagManager, child) {
                          final tags = tagManager.tags;
                          return tags.isEmpty
                              ? const Text('No tags created yet')
                              : Column(
                                  children: tags
                                      .map(
                                        (tag) => Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                              leading: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: tag.color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              title: Text(tag.name),
                                              subtitle: Text('Shortcut: ${tag.shortcutKey.keyLabel}'),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit),
                                                    onPressed: () => showDialog(context: context, builder: (_) => EditTagDialog(tag: tag)),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete),
                                                    onPressed: () {
                                                      tagManager.deleteTag(tag);
                                                    },
                                                  ),
                                                ],
                                              )),
                                        ),
                                      )
                                      .toList(),
                                );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      const Text('Reset Application', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 12),
                      const Text(
                        'Warning: This will delete all your data including folders, photos, tags, and settings. This action cannot be undone.',
                        style: TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      Consumer<SettingsManager>(
                        builder: (context, settingsManager, child) {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.delete_forever, color: Colors.white),
                            label: const Text('Reset All Data', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {
                              // Onay dialog'u göster
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Reset All Data?'),
                                  content: const Text(
                                    'This will delete all your data including folders, photos, tags, and settings. '
                                    'The application will close after reset and you will need to restart it. '
                                    'This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () async {
                                        // Tüm verileri sıfırla
                                        final result = await settingsManager.resetAllData();
                                        if (result) {
                                          // Uygulamayı kapat
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Reset Complete'),
                                                content: const Text(
                                                  'All data has been reset. The application will now close. '
                                                  'Please restart the application.',
                                                ),
                                                actions: [
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      // Uygulamayı kapat
                                                      exit(0);
                                                    },
                                                    child: const Text('Close Application'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        } else {
                                          // Hata mesajı göster
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Failed to reset data. Please try again.'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Reset', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
