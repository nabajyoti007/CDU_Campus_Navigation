import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/place_category.dart';

/// Draws the map marker for each place category as a PNG, so the map can show
/// it. Facilities look like the PDF map's icons (white symbol on a blue
/// square); named places get a coloured circle.
class PlaceIcons {
  /// Pixel size of the generated images (shown smaller on the map).
  static const int size = 96;

  static String imageName(String category) => 'poi-$category';

  static Future<Map<String, Uint8List>> render() async {
    final out = <String, Uint8List>{};
    for (final c in PlaceCategory.all) {
      out[imageName(c.id)] = await _draw(c);
    }
    return out;
  }

  static Future<Uint8List> _draw(PlaceCategory c) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = size.toDouble();
    const inset = 6.0;
    final rect = Rect.fromLTWH(inset, inset, s - 2 * inset, s - 2 * inset);

    // soft shadow, then a white ring, then the coloured marker
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final white = Paint()..color = Colors.white;
    final fill = Paint()..color = c.colour;
    if (c.round) {
      canvas.drawCircle(rect.center.translate(0, 2), rect.width / 2, shadow);
      canvas.drawCircle(rect.center, rect.width / 2, white);
      canvas.drawCircle(rect.center, rect.width / 2 - 5, fill);
    } else {
      final r = RRect.fromRectAndRadius(rect, const Radius.circular(14));
      canvas.drawRRect(r.shift(const Offset(0, 2)), shadow);
      canvas.drawRRect(r, white);
      canvas.drawRRect(r.deflate(5), fill);
    }

    final icon = c.icon;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: s * 0.52,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((s - tp.width) / 2, (s - tp.height) / 2));

    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
