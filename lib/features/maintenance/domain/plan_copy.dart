import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/phrases.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';

String planStatusPhrase(MaintenancePlan plan) {
  return maintenanceStatusPhrase(
    plan.status.wire,
    remainingKm: plan.remainingKm,
    remainingDays: plan.remainingDays,
  );
}

/// Joins the interval dimensions the plan actually has.
///
/// Null means the dimension does not apply — it is omitted, never written as
/// zero. Nothing here computes a due date; it only spells out stored fields.
String? intervalPhrase({int? km, int? months, int? days}) {
  final parts = <String>[];
  if (km != null) {
    parts.add(formatKm(km));
  }
  if (months != null) {
    parts.add(months == 1 ? '1 mês' : '$months meses');
  }
  if (days != null) {
    parts.add(days == 1 ? '1 dia' : '$days dias');
  }
  if (parts.isEmpty) return null;
  return 'a cada ${_joinOu(parts)}';
}

/// The next due, using only the dimensions the server filled in.
String? dueNextPhrase({int? dueAtKm, CivilDate? dueOn}) {
  final parts = <String>[];
  if (dueAtKm != null) {
    parts.add('aos ${formatKm(dueAtKm)}');
  }
  if (dueOn != null) {
    parts.add('em ${formatCivilDate(dueOn)}');
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

String? lastDonePhrase({CivilDate? occurredOn, int? mileageKm}) {
  final parts = <String>[];
  if (occurredOn != null) {
    parts.add(formatCivilDate(occurredOn));
  }
  if (mileageKm != null) {
    parts.add(formatKm(mileageKm));
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Distance between two mileages the API already returned. Display only.
String? mileageSincePreviousPhrase(int newerKm, int olderKm) {
  final delta = newerKm - olderKm;
  if (delta == 0) return null;
  if (delta > 0) return '${formatKm(delta)} desde a anterior';
  return '${formatKm(-delta)} a menos que a anterior';
}

List<MaintenanceRecord> historyOfItem(
  List<MaintenanceRecord> records,
  String maintenanceItemId,
) {
  return [
    for (final record in records)
      if (_coversItem(record, maintenanceItemId)) record,
  ];
}

bool _coversItem(MaintenanceRecord record, String maintenanceItemId) {
  for (final item in record.items) {
    if (item.maintenanceItemId == maintenanceItemId) return true;
  }
  return false;
}

String _joinOu(List<String> parts) {
  if (parts.length == 1) return parts.first;
  if (parts.length == 2) return '${parts[0]} ou ${parts[1]}';
  final leading = parts.sublist(0, parts.length - 1).join(', ');
  return '$leading ou ${parts.last}';
}
