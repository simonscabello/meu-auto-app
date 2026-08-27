import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/civil_date.dart';

/// How far back a date field lets someone reach. Thirty years covers any car
/// an owner is plausibly still keeping records for.
const _yearsBack = 30;

/// The date picker every "when did this happen" field opens.
///
/// Four screens had byte-identical copies of this — odometer, maintenance
/// form, maintenance edit, calibrar. They share one rule worth stating once:
/// **the future is not selectable.** Every date the app posts is something
/// that already happened, the server rejects a future one, and offering a day
/// that will come back as a 422 is worse than not offering it.
///
/// Returns null when the picker is dismissed, so the caller can leave its
/// state untouched.
Future<CivilDate?> pickPastDate(
  BuildContext context, {
  required CivilDate? initial,
}) async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initial == null
        ? now
        : DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(now.year - _yearsBack),
    lastDate: now,
  );
  if (picked == null) {
    return null;
  }
  return CivilDate(picked.year, picked.month, picked.day);
}
