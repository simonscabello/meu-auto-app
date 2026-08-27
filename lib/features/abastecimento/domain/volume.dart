import 'package:meu_auto/core/domain/formatters.dart';

/// Litres typed in pt-BR (`34,7`) to the integer millilitres the wire takes.
///
/// Integer arithmetic only: `34,7 * 1000` as a double is not 34700 on every
/// platform. A fourth decimal rounds half away from zero.
int? volumeMlFromLitersText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  var separator = -1;
  for (var i = 0; i < trimmed.length; i++) {
    final unit = trimmed.codeUnitAt(i);
    if (unit == 0x2C || unit == 0x2E) separator = i;
  }

  final wholeRaw = separator < 0 ? trimmed : trimmed.substring(0, separator);
  final fracRaw = separator < 0 ? '' : trimmed.substring(separator + 1);

  final wholeDigits = digitsOnly(wholeRaw);
  final fracDigits = digitsOnly(fracRaw);
  if (wholeDigits.isEmpty && fracDigits.isEmpty) return null;

  final whole = int.parse(wholeDigits.isEmpty ? '0' : wholeDigits);

  if (fracDigits.length <= 3) {
    return whole * 1000 + int.parse(fracDigits.padRight(3, '0'));
  }

  var millilitres = int.parse(fracDigits.substring(0, 3));
  if (fracDigits.codeUnitAt(3) >= 0x35) millilitres += 1;
  return whole * 1000 + millilitres;
}

/// The reverse of [volumeMlFromLitersText], trailing zeros stripped.
String litersTextFromVolumeMl(int volumeMl) {
  final whole = volumeMl ~/ 1000;
  final frac = volumeMl.abs() % 1000;
  if (frac == 0) return '$whole';

  var fracText = frac.toString().padLeft(3, '0');
  while (fracText.endsWith('0')) {
    fracText = fracText.substring(0, fracText.length - 1);
  }
  final sign = volumeMl < 0 ? '-' : '';
  return '$sign$whole,$fracText';
}
