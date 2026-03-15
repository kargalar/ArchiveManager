import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/quick_move_destination.dart';
import '../../managers/quick_move_manager.dart';
import '../../managers/tag_manager.dart';
import '../../utils/keyboard_key_label.dart';
import 'tag_dialogs.dart';

class AddQuickMoveDialog extends StatefulWidget {
  const AddQuickMoveDialog({super.key});
  @override
  State<AddQuickMoveDialog> createState() => _AddQuickMoveDialogState();
}

class _AddQuickMoveDialogState extends State<AddQuickMoveDialog> {
  final TextEditingController nameController = TextEditingController();
  Color selectedColor = Colors.blue;
  LogicalKeyboardKey? selectedShortcutKey;
  String? selectedPath;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _showShortcutPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Press a key', style: TextStyle(fontSize: 16)),
        content: KeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              setState(() => selectedShortcutKey = event.logicalKey);
              Navigator.pop(context);
            }
          },
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Press any key to set as shortcut',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() => selectedPath = path);
    }
  }

  void _handleCreate() {
    if (nameController.text.isEmpty || selectedShortcutKey == null || selectedPath == null) return;

    final quickMoveManager = context.read<QuickMoveManager>();
    final tagManager = context.read<TagManager>();

    final existingDest = quickMoveManager.getDestinationByShortcutKey(selectedShortcutKey!);
    if (existingDest != null) {
      _showDuplicateWarning('quick move destination "${existingDest.name}"');
      return;
    }

    final existingTag = tagManager.getTagByShortcutKey(selectedShortcutKey!);
    if (existingTag != null) {
      _showDuplicateWarning('tag "${existingTag.name}"');
      return;
    }

    final dest = QuickMoveDestination(
      name: nameController.text,
      path: selectedPath!,
      color: selectedColor,
      shortcutKey: selectedShortcutKey!,
    );
    quickMoveManager.addDestination(dest);
    Navigator.pop(context);
  }

  void _showDuplicateWarning(String usedBy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Duplicate Shortcut Key', style: TextStyle(fontSize: 16)),
        content: Text(
          'The shortcut key "${selectedShortcutKey!.keyLabel.toUpperCase()}" is already used by the $usedBy. Please choose a different shortcut key.',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white54),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drive_file_move, color: Colors.blue, size: 18),
                  const SizedBox(width: 10),
                  const Text('Add Quick Move Destination', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 18, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(fontSize: 13, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF252525),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF383838)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF383838)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Target folder picker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open, size: 15, color: Colors.white54),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedPath ?? 'No folder selected',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selectedPath != null ? Colors.white : Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          child: TextButton(
                            onPressed: _pickDirectory,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Browse'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kPredefinedColors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Shortcut key picker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard, size: 15, color: Colors.white54),
                        const SizedBox(width: 10),
                        const Text('Shortcut:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF444444)),
                          ),
                          child: Text(
                            selectedShortcutKey?.displayLabel ?? 'None',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 28,
                          child: TextButton(
                            onPressed: _showShortcutPicker,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: Text(selectedShortcutKey == null ? 'Set' : 'Change'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.white54),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditQuickMoveDialog extends StatefulWidget {
  final QuickMoveDestination destination;
  const EditQuickMoveDialog({super.key, required this.destination});
  @override
  State<EditQuickMoveDialog> createState() => _EditQuickMoveDialogState();
}

class _EditQuickMoveDialogState extends State<EditQuickMoveDialog> {
  late TextEditingController nameController;
  late Color selectedColor;
  late LogicalKeyboardKey selectedShortcutKey;
  late String selectedPath;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.destination.name);
    selectedColor = widget.destination.color;
    selectedShortcutKey = widget.destination.shortcutKey;
    selectedPath = widget.destination.path;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _showShortcutPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Press a key', style: TextStyle(fontSize: 16)),
        content: KeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              setState(() => selectedShortcutKey = event.logicalKey);
              Navigator.pop(context);
            }
          },
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Press any key to set as shortcut',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() => selectedPath = path);
    }
  }

  void _handleSave() {
    if (nameController.text.trim().isEmpty) return;

    final quickMoveManager = Provider.of<QuickMoveManager>(context, listen: false);
    final tagManager = Provider.of<TagManager>(context, listen: false);

    final existingDest = quickMoveManager.getDestinationByShortcutKey(selectedShortcutKey, excludeId: widget.destination.id);
    if (existingDest != null) {
      _showDuplicateWarning('quick move destination "${existingDest.name}"');
      return;
    }

    final existingTag = tagManager.getTagByShortcutKey(selectedShortcutKey);
    if (existingTag != null) {
      _showDuplicateWarning('tag "${existingTag.name}"');
      return;
    }

    quickMoveManager.updateDestination(
      widget.destination,
      nameController.text.trim(),
      selectedPath,
      selectedColor,
      selectedShortcutKey,
    );
    Navigator.pop(context);
  }

  void _showDuplicateWarning(String usedBy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Duplicate Shortcut Key', style: TextStyle(fontSize: 16)),
        content: Text(
          'The shortcut key "${selectedShortcutKey.keyLabel.toUpperCase()}" is already used by the $usedBy. Please choose a different shortcut key.',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white54),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drive_file_move, color: Colors.blue, size: 18),
                  const SizedBox(width: 10),
                  const Text('Edit Quick Move Destination', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 18, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(fontSize: 13, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF252525),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF383838)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF383838)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Target folder picker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open, size: 15, color: Colors.white54),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedPath,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          child: TextButton(
                            onPressed: _pickDirectory,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Browse'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kPredefinedColors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Shortcut key picker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard, size: 15, color: Colors.white54),
                        const SizedBox(width: 10),
                        const Text('Shortcut:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF444444)),
                          ),
                          child: Text(
                            selectedShortcutKey.displayLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 28,
                          child: TextButton(
                            onPressed: _showShortcutPicker,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Change'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.white54),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
