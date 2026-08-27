import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the consistency sweep: no loose TextButtons, no unmasked money/km
/// fields, no "Ops" or excited copy.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  String posix(File file) => file.path.replaceAll(r'\', '/');

  const textButtonAllowlist = {
    'lib/shared/widgets/app_button.dart',
    'lib/shared/widgets/app_confirm.dart',
    'lib/features/odometer/presentation/odometer_rollback_dialog.dart',
  };

  const maskAllowlist = {
    'lib/core/domain/formatters.dart',
    'lib/shared/widgets/app_number_field.dart',
  };

  const iconButtonAllowlist = {
    'lib/shared/widgets/app_icon_button.dart',
    'lib/features/auth/presentation/auth_password_field.dart',
  };

  test('TextButton( in lib lives only inside AlertDialog helpers', () {
    for (final file in dartFiles) {
      final path = posix(file);
      if (textButtonAllowlist.any(path.endsWith)) continue;
      final source = file.readAsStringSync();
      expect(
        source.contains('TextButton('),
        isFalse,
        reason: '$path still builds a loose TextButton',
      );
    }
  });

  test('money writes go through AppMoneyField', () {
    for (final file in dartFiles) {
      final path = posix(file);
      if (maskAllowlist.any(path.endsWith)) continue;
      final source = file.readAsStringSync();
      final writesMoney =
          source.contains('centsFromMoneyField') ||
          source.contains('moneyController(');
      if (!writesMoney) continue;
      expect(
        source.contains('AppMoneyField'),
        isTrue,
        reason: '$path reads money without the mask',
      );
    }
  });

  test('mileage writes go through AppKmField', () {
    for (final file in dartFiles) {
      final path = posix(file);
      if (maskAllowlist.any(path.endsWith)) continue;
      final source = file.readAsStringSync();
      final writesKm =
          source.contains('kmFromField') || source.contains('kmController(');
      if (!writesKm) continue;
      expect(
        source.contains('AppKmField'),
        isTrue,
        reason: '$path reads km without the mask',
      );
    }
  });

  test('user-facing strings have no Ops and no exclamation', () {
    // Single-quoted literals on one line. Interpolation (`${x!}`) is Dart,
    // not copy — strip it before looking for a shout.
    final literal = RegExp(r"'([^'\\\n]|\\.)*'");
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        final quoted = match.group(0)!;
        final copy = quoted
            .substring(1, quoted.length - 1)
            .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
            .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '');
        expect(
          copy.contains(RegExp(r'Ops', caseSensitive: false)),
          isFalse,
          reason: '${posix(file)} still says $quoted',
        );
        expect(
          copy.contains('!'),
          isFalse,
          reason: '${posix(file)} still shouts $quoted',
        );
      }
    }
  });

  test('icon-only IconButton uses AppIconButton or has Semantics', () {
    final looseIcon = RegExp(r'(?<!App)IconButton\(');
    for (final file in dartFiles) {
      final path = posix(file);
      if (iconButtonAllowlist.any(path.endsWith)) continue;
      final source = file.readAsStringSync();
      expect(
        looseIcon.hasMatch(source),
        isFalse,
        reason: '$path has an icon-only button without AppIconButton',
      );
    }
  });
}
