// Builds assets/icon/splash_android12_light.png: the light splash mark at the
// size and position of the adaptive-icon layer, for the Android 12+ splash in
// the light theme. Run with:
//
//   flutter test tool/android12_light_splash.dart
//
// Why a fifth file: Android 12+ crops the splash icon to the central ~66.7%,
// so it takes icon_foreground.png (the mark at 58.2%) rather than the 70%
// splash_light.png. But icon_foreground.png carries the dark glow of the
// original art, which disappears on the dark icon and reads as a dirty
// shadow on #F2F4F7. This file is splash_light.png — clean art, no glow —
// scaled so its mark is exactly as wide as the one in icon_foreground.png and
// centred where that one is.
//
// The scaling is done on premultiplied colour by the engine, so the edges
// keep their blue and gain no grey fringe; nothing here thresholds or
// "cleans" alpha. After a palette change, run tool/recolor_icons.dart first
// (it re-tints splash_light.png and this file alike) or simply run this again.
// Lives under tool/ so the ordinary `flutter test` run never touches it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _source = 'assets/icon/splash_light.png';
const _reference = 'assets/icon/icon_foreground.png';
const _target = 'assets/icon/splash_android12_light.png';

void main() {
  test('build the Android 12 light splash', () async {
    final source = await _decode(_source);
    final reference = await _decode(_reference);

    // The source mark: everything reasonably opaque (the art has no glow).
    final from = await _bounds(source, (r, g, b, a) => a >= 128);
    // The reference mark: opaque and not part of the dark glow.
    final to = await _bounds(reference, (r, g, b, a) {
      final m = r > g ? (r > b ? r : b) : (g > b ? g : b);
      return a >= 128 && m > 40;
    });

    final scale = to.width / from.width;
    final dx = to.center.dx - from.center.dx * scale;
    final dy = to.center.dy - from.center.dy * scale;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.translate(dx, dy);
    canvas.scale(scale);
    canvas.drawImage(
      source,
      ui.Offset.zero,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final out = await picture.toImage(reference.width, reference.height);
    final png = await out.toByteData(format: ui.ImageByteFormat.png);
    await File(_target).writeAsBytes(png!.buffer.asUint8List(), flush: true);

    final result = await _bounds(out, (r, g, b, a) => a >= 128);
    stdout.writeln(
      'scale ${scale.toStringAsFixed(4)}; '
      'reference mark ${_describe(to)}; written mark ${_describe(result)}',
    );
  });
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  return (await codec.getNextFrame()).image;
}

Future<ui.Rect> _bounds(
  ui.Image image,
  bool Function(int r, int g, int b, int a) keep,
) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  var x0 = image.width, y0 = image.height, x1 = -1, y1 = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final i = (y * image.width + x) * 4;
      if (!keep(px[i], px[i + 1], px[i + 2], px[i + 3])) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  return ui.Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0);
}

String _describe(ui.Rect r) =>
    '${r.width.round()}x${r.height.round()} at '
    '${r.center.dx.toStringAsFixed(1)},${r.center.dy.toStringAsFixed(1)}';
