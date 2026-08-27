import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'civil_date.dart';

bool _ptBrReady = false;

/// Loads pt-BR symbols for [DateFormat]. Safe to call more than once.
///
/// Call this once from `main()` before `runApp`. Formatters that need month
/// names also call it defensively, so tests and isolated use do not depend
/// on startup order. Number formatters take `pt_BR` in the constructor and
/// do not need this.
void ensurePtBrFormatting() {
  if (_ptBrReady) return;
  unawaited(initializeDateFormatting('pt_BR'));
  Intl.defaultLocale = 'pt_BR';
  _ptBrReady = true;
}

final _integer = NumberFormat('#,##0', 'pt_BR');

String formatKm(int km) => '${formatKmNumber(km)} km';

String formatKmNumber(int km) => _integer.format(km);

String formatCivilDate(CivilDate date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatCivilDateLong(CivilDate date) {
  final month = _monthName(date);
  return '${date.day} de $month de ${date.year}';
}

String formatCivilMonthHeader(CivilDate date) {
  final month = _monthName(date);
  final capitalized = '${month[0].toUpperCase()}${month.substring(1)}';
  return '$capitalized de ${date.year}';
}

/// Timestamps are real instants. Converting to local time here is correct.
String formatInstant(DateTime instant) {
  ensurePtBrFormatting();
  return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(instant.toLocal());
}

String _monthName(CivilDate date) {
  ensurePtBrFormatting();
  // Local DateTime from already-split Y/M/D — not parse-then-toLocal.
  final anchor = DateTime(date.year, date.month, date.day);
  return DateFormat('MMMM', 'pt_BR').format(anchor);
}

/// Every digit in [raw], in order. The bridge between a masked field and the
/// integer behind it: `'R$ 4.200,00'` is `'420000'`, `'98.450'` is `'98450'`.
String digitsOnly(String raw) {
  final buffer = StringBuffer();
  for (final unit in raw.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) buffer.writeCharCode(unit);
  }
  return buffer.toString();
}

/// Cents behind a money field, masked or not.
///
/// The field shows `R$ 420,00`; the wire takes `42000`. Reading the digits
/// back means the mask can change without the write changing with it, and an
/// unmasked value typed by a test still parses.
int? centsFromMoneyField(String raw) {
  final digits = digitsOnly(raw);
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Kilometres behind a mileage field, masked or not: `'98.450'` is `98450`.
int? kmFromField(String raw) {
  final digits = digitsOnly(raw);
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}
