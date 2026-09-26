// Builds ic_notification.png, the small icon Android puts in the status bar and
// at the head of every push reminder, at every density. Run with:
//
//   flutter test tool/notification_icon.dart
//
// Android draws only the ALPHA of this icon and tints it, so every colour in
// it is thrown away — and a full-colour PNG, the launcher icon for instance,
// comes out as a white square. This is the mark's silhouette, white on
// transparent: splash_light.png (clean art, no glow — the adaptive layer's
// dark glow would fatten the shape), cropped to the mark's own edges and set
// in Material's grid, a 20dp glyph in a 24dp box.
//
// The manifest names it as FCM's default icon, and PushService draws the
// reminders that arrive with the app open with it. Run again only if the
// mark itself changes; a palette change does not touch a silhouette. Lives
// under tool/ so the ordinary `flutter test` run never touches it.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _source = 'assets/icon/splash_light.png';

/// dp → px at each density Android ships a drawable for.
const _densities = {
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

/// The glyph's share of the box: 20dp of 24dp, Material's live area.
const _glyphShare = 20 / 24;

void main() {
  test('build the notification icon', () async {
    final source = await _decode(_source);
    final mark = await _bounds(source, (a) => a >= 16);
    final side = math.max(mark.width, mark.height);

    for (final MapEntry(key: density, value: size) in _densities.entries) {
      final scale = size * _glyphShare / side;
      final width = mark.width * scale;
      final height = mark.height * scale;
      final destination = ui.Rect.fromLTWH(
        (size - width) / 2,
        (size - height) / 2,
        width,
        height,
      );

      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        source,
        mark,
        destination,
        ui.Paint()
          ..filterQuality = ui.FilterQuality.high
          // Keep the source's alpha, replace its colour with white.
          ..colorFilter = const ui.ColorFilter.mode(
            ui.Color(0xFFFFFFFF),
            ui.BlendMode.srcIn,
          ),
      );
      final image = await recorder.endRecording().toImage(size, size);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'android/app/src/main/res/drawable-$density/ic_notification.png',
      );
      await file.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
      stdout.writeln('$density: ${size}x$size → ${file.path}');
    }
  });
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  return (await codec.getNextFrame()).image;
}

Future<ui.Rect> _bounds(ui.Image image, bool Function(int alpha) keep) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  var x0 = image.width, y0 = image.height, x1 = -1, y1 = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (!keep(px[(y * image.width + x) * 4 + 3])) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  return ui.Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0);
}
