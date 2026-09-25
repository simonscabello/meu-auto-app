import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_colors.dart';

/// The icon and splash backgrounds are written into `pubspec.yaml` for the
/// generators, as hex, where nothing ties them to the theme. After the move
/// to graphite they still said the old navy until someone looked — so the
/// native launch and the first Flutter frame were two different blacks.
/// See docs/IDENTIDADE-VISUAL.md.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  String hexOf(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  List<String> valuesOf(String key) => [
    for (final match in RegExp(
      '^\\s*$key:\\s*"(#[0-9A-Fa-f]{6})"',
      multiLine: true,
    ).allMatches(pubspec))
      match.group(1)!.toUpperCase(),
  ];

  test('the dark icon and splash backgrounds are the dark page', () {
    final page = hexOf(AppColors.dark.surface);
    expect(valuesOf('adaptive_icon_background'), [page]);
    expect(valuesOf('color_dark'), everyElement(page));
    expect(valuesOf('icon_background_color_dark'), [page]);
  });

  test('the light splash background is the light page', () {
    final page = hexOf(AppColors.light.surface);
    expect(valuesOf('color'), isNotEmpty);
    expect(valuesOf('color'), everyElement(page));
    expect(valuesOf('icon_background_color'), [page]);
  });

  // icon_foreground.png carries the dark glow of the original art: invisible
  // on the dark icon, a dirty shadow on the light splash. The Android 12+
  // light splash has its own file for that reason, and it must stay clean.
  test('the Android 12 light splash carries no dark halo', () async {
    final android12 = RegExp(
      r'android_12:[\s\S]*?\s+image:\s*"([^"]+)"',
    ).firstMatch(pubspec);
    expect(android12, isNotNull);
    final path = android12!.group(1)!;
    expect(path, isNot(contains('icon_foreground')));

    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    final image = (await codec.getNextFrame()).image;
    final px = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    var mark = 0;
    var dark = 0;
    for (var i = 0; i < px.length; i += 4) {
      final a = px[i + 3];
      final brightest = [
        px[i],
        px[i + 1],
        px[i + 2],
      ].reduce((x, y) => x > y ? x : y);
      if (a >= 128 && brightest > 40) mark++;
      if (a > 32 && brightest < 60) dark++;
    }
    // Anti-aliased edges leave a few dark pixels (about 5% of the mark);
    // the glow of icon_foreground.png measures about 80% of it.
    expect(mark, greaterThan(0));
    expect(dark / mark, lessThan(0.1));
  });
}
