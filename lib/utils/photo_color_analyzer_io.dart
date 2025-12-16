import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../models/photo.dart';

class PhotoColorAnalyzer {
  static Future<int> computeColorCategoryCode(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return -1;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return -1;

      // Decode small to keep memory low.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (byteData == null) return -1;

          final rgba = byteData.buffer.asUint8List();
          if (rgba.isEmpty) return -1;

          int rSum = 0;
          int gSum = 0;
          int bSum = 0;
          int count = 0;

          // Sample every N pixels to reduce work.
          // rawRgba => 4 bytes per pixel.
          const int stridePixels = 2;
          final int width = image.width;
          final int height = image.height;
          for (int y = 0; y < height; y += stridePixels) {
            for (int x = 0; x < width; x += stridePixels) {
              final int idx = (y * width + x) * 4;
              if (idx + 2 >= rgba.length) continue;
              final int a = rgba[idx + 3];
              if (a < 10) continue; // ignore almost-transparent
              rSum += rgba[idx];
              gSum += rgba[idx + 1];
              bSum += rgba[idx + 2];
              count++;
            }
          }

          if (count == 0) return -1;

          final double r = rSum / count;
          final double g = gSum / count;
          final double b = bSum / count;

          final _Hsv hsv = _rgbToHsv(r, g, b);
          final category = _classify(hsv);
          return category.code;
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return -1;
    }
  }

  static PhotoColorCategory _classify(_Hsv hsv) {
    // Grayscale/black/white detection.
    // hsv.v: 0..1, hsv.s: 0..1
    if (hsv.v <= 0.12) {
      return PhotoColorCategory.black;
    }
    if (hsv.s <= 0.12) {
      if (hsv.v >= 0.88) return PhotoColorCategory.white;
      return PhotoColorCategory.gray;
    }

    final double h = hsv.h; // 0..360

    // Brown: low-ish value and orange-ish hue.
    if (h >= 15 && h <= 45 && hsv.v <= 0.55) {
      return PhotoColorCategory.brown;
    }

    // Hue buckets.
    if (h < 15 || h >= 345) return PhotoColorCategory.red;
    if (h < 35) return PhotoColorCategory.orange;
    if (h < 65) return PhotoColorCategory.yellow;
    if (h < 170) return PhotoColorCategory.green;
    if (h < 250) return PhotoColorCategory.blue;
    if (h < 290) return PhotoColorCategory.purple;

    // 290..345
    // If high value => pink, else purple.
    if (hsv.v >= 0.65) return PhotoColorCategory.pink;
    return PhotoColorCategory.purple;
  }

  static _Hsv _rgbToHsv(double r255, double g255, double b255) {
    final double r = (r255 / 255.0).clamp(0.0, 1.0);
    final double g = (g255 / 255.0).clamp(0.0, 1.0);
    final double b = (b255 / 255.0).clamp(0.0, 1.0);

    final double maxC = math.max(r, math.max(g, b));
    final double minC = math.min(r, math.min(g, b));
    final double delta = maxC - minC;

    double h;
    if (delta == 0) {
      h = 0;
    } else if (maxC == r) {
      h = 60 * (((g - b) / delta) % 6);
    } else if (maxC == g) {
      h = 60 * (((b - r) / delta) + 2);
    } else {
      h = 60 * (((r - g) / delta) + 4);
    }
    if (h < 0) h += 360;

    final double s = maxC == 0 ? 0 : (delta / maxC);
    final double v = maxC;

    return _Hsv(h: h, s: s, v: v);
  }
}

class _Hsv {
  final double h;
  final double s;
  final double v;
  const _Hsv({required this.h, required this.s, required this.v});
}
