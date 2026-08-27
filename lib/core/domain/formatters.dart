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
