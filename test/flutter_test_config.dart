import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file: loads the app's real face into the test
/// engine.
///
/// Without it, widget tests lay text out in Ahem, the test font whose every
/// glyph is a full-width square — so an overflow test measured a width that
/// is nothing like Inter's, both ways: false alarms on short labels and
/// silence on long ones. With Inter loaded, a text width in a test is the
/// width a phone draws.
///
/// The icon font is left alone: a glyph is laid out at its box size either
/// way, and its outline does not change any measurement.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inter = FontLoader('Inter');
  for (final weight in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
  }
  await inter.load();
  await testMain();
}
