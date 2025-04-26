// This is a stub implementation of window_manager for web platforms
// It provides empty implementations of the methods used in the app
// to avoid errors when running on web

import 'package:flutter/material.dart';

class WindowManager {
  Future<void> ensureInitialized() async {}
  
  Future<void> setPreventClose(bool preventClose) async {}
  
  Future<void> waitUntilReadyToShow(WindowOptions options, [Function? callback]) async {
    if (callback != null) {
      await callback();
    }
  }
  
  Future<void> show() async {}
  
  Future<void> setFullScreen(bool isFullScreen) async {}
  
  Future<void> setBounds(Rect bounds) async {}
  
  Future<void> center() async {}
  
  Future<void> focus() async {}
  
  Future<Rect> getBounds() async {
    return const Rect.fromLTWH(0, 0, 800, 600);
  }
  
  Future<void> setMinimumSize(Size size) async {}
  
  void addListener(WindowListener listener) {}
  
  void removeListener(WindowListener listener) {}
  
  Future<void> destroy() async {}
}

class WindowOptions {
  final Color? backgroundColor;
  final bool? skipTaskbar;
  final TitleBarStyle? titleBarStyle;

  const WindowOptions({
    this.backgroundColor,
    this.skipTaskbar,
    this.titleBarStyle,
  });
}

enum TitleBarStyle {
  normal,
  hidden,
}

mixin WindowListener {
  void onWindowClose() {}
  void onWindowResized() {}
  void onWindowMoved() {}
}

// Create a singleton instance
final WindowManager windowManager = WindowManager();
