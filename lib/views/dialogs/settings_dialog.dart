// Widget that displays the settings dialog
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
