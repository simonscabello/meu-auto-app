import 'dart:io';

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
}
