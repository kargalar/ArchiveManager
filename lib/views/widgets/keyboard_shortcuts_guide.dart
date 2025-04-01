import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardShortcutsGuide extends StatelessWidget {
  const KeyboardShortcutsGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Klavye Kısayolları',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildShortcutCategory(
          'Navigasyon',
          [
            _ShortcutInfo(LogicalKeyboardKey.arrowLeft, 'Sola git'),
            _ShortcutInfo(LogicalKeyboardKey.arrowRight, 'Sağa git'),
            _ShortcutInfo(LogicalKeyboardKey.arrowUp, 'Yukarı git'),
            _ShortcutInfo(LogicalKeyboardKey.arrowDown, 'Aşağı git'),
            _ShortcutInfo(LogicalKeyboardKey.enter, 'Tam ekran görüntüleme'),
            _ShortcutInfo(LogicalKeyboardKey.escape, 'Tam ekrandan çık'),
          ],
        ),
        SizedBox(height: 15),
        _buildShortcutCategory(
          'Fotoğraf İşlemleri',
          [
            _ShortcutInfo(LogicalKeyboardKey.keyF, 'Favorilere ekle/çıkar'),
            _ShortcutInfo(LogicalKeyboardKey.delete, 'Fotoğrafı sil'),
          ],
        ),
        SizedBox(height: 15),
        _buildShortcutCategory(
          'Derecelendirme',
          [
            _ShortcutInfo(LogicalKeyboardKey.digit1, '1 yıldız ver'),
            _ShortcutInfo(LogicalKeyboardKey.digit2, '2 yıldız ver'),
            _ShortcutInfo(LogicalKeyboardKey.digit3, '3 yıldız ver'),
            _ShortcutInfo(LogicalKeyboardKey.digit4, '4 yıldız ver'),
            _ShortcutInfo(LogicalKeyboardKey.digit5, '5 yıldız ver'),
            _ShortcutInfo(LogicalKeyboardKey.digit6, '6 yıldız ver'),
            _ShortcutInfo(LogicalKeyboardKey.digit7, '7 yıldız ver'),
          ],
        ),
        SizedBox(height: 15),
        _buildShortcutCategory(
          'Görünüm',
          [
            _ShortcutInfo(LogicalKeyboardKey.controlLeft, 'Bilgi panelini göster/gizle'),
            _ShortcutInfo(LogicalKeyboardKey.shiftLeft, 'Otomatik ilerlemeyi aç/kapat'),
            _ShortcutInfo(null, 'Ctrl + Fare Tekerleği: Görüntü boyutunu değiştir'),
            _ShortcutInfo(LogicalKeyboardKey.tab, 'Zen modunu aç/kapat'),
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
                      color: Colors.black.withOpacity(0.2),
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

    // Özel tuş etiketleri
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.controlLeft) return 'Ctrl';
    if (key == LogicalKeyboardKey.shiftLeft) return 'Shift';

    // Diğer tuşlar için keyLabel kullan
    return key.keyLabel;
  }
}

class _ShortcutInfo {
  final LogicalKeyboardKey? key;
  final String description;

  _ShortcutInfo(this.key, this.description);
}
