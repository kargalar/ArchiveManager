import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Guide widget showing keyboard shortcuts in the application.
// Provides quick access and ease of use for the user.
class KeyboardShortcutsGuide extends StatefulWidget {
  const KeyboardShortcutsGuide({super.key});

  @override
  State<KeyboardShortcutsGuide> createState() => _KeyboardShortcutsGuideState();
}

class _KeyboardShortcutsGuideState extends State<KeyboardShortcutsGuide> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.keyboard, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                const Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 12),
                _buildShortcutCategory(
                  'Photo Operations',
                  [
                    _ShortcutInfo(LogicalKeyboardKey.keyF, 'Add/remove from favorites'),
                    _ShortcutInfo(LogicalKeyboardKey.delete, 'Delete photo'),
                  ],
                ),
                const SizedBox(height: 12),
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
                    _ShortcutInfo(LogicalKeyboardKey.digit8, 'Give 8 stars'),
                    _ShortcutInfo(LogicalKeyboardKey.digit9, 'Give 9 stars'),
                  ],
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildShortcutCategory(String title, List<_ShortcutInfo> shortcuts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: shortcuts.map((shortcut) => _buildShortcutItem(shortcut)).toList(),
        ),
      ],
    );
  }

  Widget _buildShortcutItem(_ShortcutInfo shortcut) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shortcut.key != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF383838),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
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
                    fontSize: 11,
                  ),
                ),
              )
            else
              Text(
                shortcut.description.split(':')[0],
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              shortcut.key != null ? shortcut.description : shortcut.description.split(':')[1].trim(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
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
    if (key == LogicalKeyboardKey.arrowLeft) return '\u2190';
    if (key == LogicalKeyboardKey.arrowRight) return '\u2192';
    if (key == LogicalKeyboardKey.arrowUp) return '\u2191';
    if (key == LogicalKeyboardKey.arrowDown) return '\u2193';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.controlLeft) return 'Ctrl';
    if (key == LogicalKeyboardKey.shiftLeft) return 'Shift';
    if (key == LogicalKeyboardKey.f11) return 'F11';

    return key.keyLabel;
  }
}

class _ShortcutInfo {
  final LogicalKeyboardKey? key;
  final String description;

  _ShortcutInfo(this.key, this.description);
}
