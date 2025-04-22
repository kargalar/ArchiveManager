import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Guide widget showing keyboard shortcuts in the application.
// Provides quick access and ease of use for the user.
class KeyboardShortcutsGuide extends StatelessWidget {
  const KeyboardShortcutsGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keyboard Shortcuts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildShortcutCategory(
          'Navigation',
          [
            _ShortcutInfo(LogicalKeyboardKey.arrowLeft, 'Go left'),
            _ShortcutInfo(LogicalKeyboardKey.arrowRight, 'Go right'),
            _ShortcutInfo(LogicalKeyboardKey.arrowUp, 'Go up'),
            _ShortcutInfo(LogicalKeyboardKey.arrowDown, 'Go down'),
            _ShortcutInfo(LogicalKeyboardKey.enter, 'Fullscreen view'),
            _ShortcutInfo(LogicalKeyboardKey.escape, 'Exit fullscreen'),
          ],
        ),
        SizedBox(height: 15),
        _buildShortcutCategory(
          'Photo Operations',
          [
            _ShortcutInfo(LogicalKeyboardKey.keyF, 'Add/remove from favorites'),
            _ShortcutInfo(LogicalKeyboardKey.delete, 'Delete photo'),
          ],
        ),
        SizedBox(height: 15),
        _buildShortcutCategory(
          'Rating',
          [
            _ShortcutInfo(LogicalKeyboardKey.digit1, 'Give 1 star'),
            _ShortcutInfo(LogicalKeyboardKey.digit2, 'Give 2 stars'),
            _ShortcutInfo(LogicalKeyboardKey.digit3, 'Give 3 stars'),
            _ShortcutInfo(LogicalKeyboardKey.digit4, 'Give 4 stars'),
            _ShortcutInfo(LogicalKeyboardKey.digit5, 'Give 5 stars'),
            _ShortcutInfo(LogicalKeyboardKey.digit6, 'Give 6 stars'),
            _ShortcutInfo(LogicalKeyboardKey.digit7, 'Give 7 stars'),
          ],
        ),
        SizedBox(height: 15),
        _buildShortcutCategory(
          'View',
          [
            _ShortcutInfo(LogicalKeyboardKey.f11, 'Toggle fullscreen mode'),
            _ShortcutInfo(LogicalKeyboardKey.controlLeft, 'Show/hide info panel'),
            _ShortcutInfo(LogicalKeyboardKey.shiftLeft, 'Toggle auto-advance'),
            _ShortcutInfo(null, 'Mouse Wheel: Image zoom'),
            _ShortcutInfo(LogicalKeyboardKey.tab, 'Toggle zen mode'),
          ],
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget _buildShortcutCategory(String title, List<_ShortcutInfo> shortcuts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: shortcuts.map((shortcut) => _buildShortcutItem(shortcut)).toList(),
        ),
      ],
    );
  }

  Widget _buildShortcutItem(_ShortcutInfo shortcut) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shortcut.key != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51), // 0.2 opacity
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  _getKeyLabel(shortcut.key),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Text(
                shortcut.description.split(':')[0],
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              shortcut.key != null ? shortcut.description : shortcut.description.split(':')[1].trim(),
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getKeyLabel(LogicalKeyboardKey? key) {
    if (key == null) return '';

    // Special key labels
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.controlLeft) return 'Ctrl';
    if (key == LogicalKeyboardKey.shiftLeft) return 'Shift';
    if (key == LogicalKeyboardKey.f11) return 'F11';

    // Diğer tuşlar için keyLabel kullan
    return key.keyLabel;
  }
}

class _ShortcutInfo {
  final LogicalKeyboardKey? key;
  final String description;

  _ShortcutInfo(this.key, this.description);
}
