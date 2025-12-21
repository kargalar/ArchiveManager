import 'package:flutter/services.dart';

extension KeyboardKeyLabelX on LogicalKeyboardKey {
  /// Display-friendly label for shortcut keys.
  ///
  /// On some platforms `keyLabel` for numpad digits becomes "Numpad 1".
  /// For UI consistency, we show plain digits for numpad 0-9.
  String get displayLabel {
    if (this == LogicalKeyboardKey.numpad0) return '0';
    if (this == LogicalKeyboardKey.numpad1) return '1';
    if (this == LogicalKeyboardKey.numpad2) return '2';
    if (this == LogicalKeyboardKey.numpad3) return '3';
    if (this == LogicalKeyboardKey.numpad4) return '4';
    if (this == LogicalKeyboardKey.numpad5) return '5';
    if (this == LogicalKeyboardKey.numpad6) return '6';
    if (this == LogicalKeyboardKey.numpad7) return '7';
    if (this == LogicalKeyboardKey.numpad8) return '8';
    if (this == LogicalKeyboardKey.numpad9) return '9';
    return keyLabel;
  }
}
