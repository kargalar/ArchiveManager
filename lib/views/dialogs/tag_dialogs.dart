// Widgets containing tag addition and editing dialogs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/tag.dart';
import '../../managers/tag_manager.dart';

class AddTagDialog extends StatefulWidget {
  const AddTagDialog({super.key});
  @override
  State<AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
  final TextEditingController nameController = TextEditingController();
  Color selectedColor = Colors.blue;
  LogicalKeyboardKey? selectedShortcutKey;
  final List<Color> predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add New Tag', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tag Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('Select Color:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 4, mainAxisSpacing: 4),
                  itemCount: predefinedColors.length,
                  itemBuilder: (context, index) {
                    final color = predefinedColors[index];
                    return InkWell(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: selectedColor == color ? Colors.white : Colors.grey, width: selectedColor == color ? 2 : 1),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Shortcut Key: '),
                  const SizedBox(width: 8),
                  Text(selectedShortcutKey?.keyLabel ?? 'None'),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Press a key'),
                          content: KeyboardListener(
                            focusNode: FocusNode()..requestFocus(),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent) {
                                setState(() => selectedShortcutKey = event.logicalKey);
                                Navigator.pop(context);
                              }
                            },
                            child: const SizedBox(height: 100, child: Center(child: Text('Press any key to set as shortcut'))),
                          ),
                        ),
                      );
                    },
                    child: const Text('Set Shortcut'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty && selectedShortcutKey != null) {
                        final tag = Tag(name: nameController.text, color: selectedColor, shortcutKey: selectedShortcutKey!);
                        context.read<TagManager>().addTag(tag);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditTagDialog extends StatefulWidget {
  final Tag tag;
  const EditTagDialog({super.key, required this.tag});
  @override
  State<EditTagDialog> createState() => _EditTagDialogState();
}

class _EditTagDialogState extends State<EditTagDialog> {
  late TextEditingController nameController;
  late Color selectedColor;
  late LogicalKeyboardKey selectedShortcutKey;
  final List<Color> predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];
  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.tag.name);
    selectedColor = widget.tag.color;
    selectedShortcutKey = widget.tag.shortcutKey;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Tag', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tag Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('Select Color:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 4, mainAxisSpacing: 4),
                  itemCount: predefinedColors.length,
                  itemBuilder: (context, index) {
                    final color = predefinedColors[index];
                    return InkWell(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: selectedColor == color ? Colors.white : Colors.grey, width: selectedColor == color ? 2 : 1),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Shortcut Key: '),
                  const SizedBox(width: 8),
                  Text(selectedShortcutKey.keyLabel),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Press a key'),
                          content: KeyboardListener(
                            focusNode: FocusNode()..requestFocus(),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent) {
                                setState(() => selectedShortcutKey = event.logicalKey);
                                Navigator.pop(context);
                              }
                            },
                            child: const SizedBox(height: 100, child: Center(child: Text('Press any key to set as shortcut'))),
                          ),
                        ),
                      );
                    },
                    child: const Text('Change Shortcut'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.trim().isNotEmpty) {
                        final tagManager = Provider.of<TagManager>(context, listen: false);
                        tagManager.updateTag(widget.tag, nameController.text.trim(), selectedColor, selectedShortcutKey);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
