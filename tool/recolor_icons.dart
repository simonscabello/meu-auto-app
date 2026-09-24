// Re-tints the four launcher/splash PNGs from the teal identity to the
// electric-blue one, keeping every alpha value and every edge exactly as it
// is. Run with:
//
//   flutter test tool/recolor_icons.dart --dart-define=APPLY=true
//
// Without APPLY it only prints the palette of each file. Lives under tool/
// so the ordinary `flutter test` run never touches it.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const apply = bool.fromEnvironment('APPLY');

/// Old → new, per role. Every pixel is expressed as a blend of the old
/// anchors it sits between, and re-expressed as the same blend of the new.
const _mapping = <String, (int, int)>{
  'bg': (0xFF121717, 0xFF060E18),
  'shadow': (0xFF000000, 0xFF000000),
  'tick': (0xFF4C565A, 0xFF3D5A7A),
  'teal': (0xFF7ED4CE, 0xFF22B8FF),
  'tip': (0xFFF0B27A, 0xFFFFC857),
  'tickLight': (0xFF4C565A, 0xFF6E8299),
  'tealLight': (0xFF0F6E6A, 0xFF0A66C2),
  'tipLight': (0xFFB45309, 0xFF8A5A00),
};

const _files = <String, List<String>>{
  'assets/icon/icon.png': ['bg', 'tick', 'teal', 'tip'],
  'assets/icon/icon_foreground.png': ['shadow', 'tick', 'teal', 'tip'],
  'assets/icon/splash_dark.png': ['shadow', 'tick', 'teal', 'tip'],
  'assets/icon/splash_light.png': [
    'shadow',
    'tickLight',
    'tealLight',
    'tipLight',
  ],
};

void main() {
  test('recolour icons', () async {
    for (final entry in _files.entries) {
      final file = File(entry.key);
      final bytes = await file.readAsBytes();
      final image = await _decode(bytes);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final pixels = data.buffer.asUint8List();
      _report(entry.key, pixels);
      if (!apply) continue;

      final anchors = [for (final key in entry.value) _mapping[key]!];
      final out = Uint8List(pixels.length);
      for (var i = 0; i < pixels.length; i += 4) {
        final a = pixels[i + 3];
        if (a == 0) {
          continue;
        }
        final mapped = _remap(pixels[i], pixels[i + 1], pixels[i + 2], anchors);
        out[i] = mapped.$1;
        out[i + 1] = mapped.$2;
        out[i + 2] = mapped.$3;
        out[i + 3] = a;
      }
      final encoded = await _encode(out, image.width, image.height);
      await file.writeAsBytes(encoded, flush: true);
      stdout.writeln('wrote ${entry.key}');
    }
  });
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<Uint8List> _encode(Uint8List rgba, int width, int height) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

/// Finds the two old anchors the pixel lies between, the fraction along that
/// segment, and returns the same fraction along the new segment.
(int, int, int) _remap(int r, int g, int b, List<(int, int)> anchors) {
  if (anchors.length == 1) {
    return _rgb(anchors.single.$2);
  }
  var bestDistance = double.infinity;
  (int, int, int)? best;
  for (var i = 0; i < anchors.length; i++) {
    for (var j = i + 1; j < anchors.length; j++) {
      final a = _rgb(anchors[i].$1);
      final c = _rgb(anchors[j].$1);
      final t = _project(r, g, b, a, c);
      final px = _lerp(a, c, t);
      final distance = _dist2((r, g, b), px);
      if (distance < bestDistance) {
        bestDistance = distance;
        final na = _rgb(anchors[i].$2);
        final nc = _rgb(anchors[j].$2);
        best = _lerp(na, nc, t);
      }
    }
  }
  return best!;
}

double _project(int r, int g, int b, (int, int, int) a, (int, int, int) c) {
  final dx = (c.$1 - a.$1).toDouble();
  final dy = (c.$2 - a.$2).toDouble();
  final dz = (c.$3 - a.$3).toDouble();
  final length = dx * dx + dy * dy + dz * dz;
  if (length == 0) return 0;
  final t = ((r - a.$1) * dx + (g - a.$2) * dy + (b - a.$3) * dz) / length;
  return t.clamp(0.0, 1.0);
}

(int, int, int) _lerp((int, int, int) a, (int, int, int) c, double t) {
  return (
    (a.$1 + (c.$1 - a.$1) * t).round().clamp(0, 255),
    (a.$2 + (c.$2 - a.$2) * t).round().clamp(0, 255),
    (a.$3 + (c.$3 - a.$3) * t).round().clamp(0, 255),
  );
}

double _dist2((int, int, int) p, (int, int, int) q) {
  final dr = (p.$1 - q.$1).toDouble();
  final dg = (p.$2 - q.$2).toDouble();
  final db = (p.$3 - q.$3).toDouble();
  return dr * dr + dg * dg + db * db;
}

(int, int, int) _rgb(int argb) {
  return ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
}

void _report(String name, Uint8List pixels) {
  final counts = <int, int>{};
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] < 8) continue;
    final key = (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final top = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final summary = [
    for (final e in top.take(14))
      '#${e.key.toRadixString(16).padLeft(6, '0').toUpperCase()}:${e.value}',
  ].join(' ');
  stdout.writeln('$name -> $summary');
}
