import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';

enum MaintenancePlanOrigin {
  suggested,
  user,
  desconhecido;

  static MaintenancePlanOrigin fromWire(String? raw) =>
      parseEnum(raw, MaintenancePlanOrigin.values, fallback: desconhecido);
}

enum MaintenanceStatus {
  vencido,
  venceEmBreve,
  emDia,
  semBaseline,
  semPeriodicidade,
  desconhecido;

  static MaintenanceStatus fromWire(String? raw) =>
      parseEnum(raw, MaintenanceStatus.values, fallback: desconhecido);

  /// The value `maintenanceStatusPhrase` and `AppStatus.fromWire` expect.
  String get wire => switch (this) {
    MaintenanceStatus.vencido => 'vencido',
    MaintenanceStatus.venceEmBreve => 'vence_em_breve',
    MaintenanceStatus.emDia => 'em_dia',
    MaintenanceStatus.semBaseline => 'sem_baseline',
    MaintenanceStatus.semPeriodicidade => 'sem_periodicidade',
    MaintenanceStatus.desconhecido => '',
  };
}

/// The plan as returned by create and update: the rule, without computed due.
final class MaintenancePlanSummary {
  const MaintenancePlanSummary({
    required this.id,
    required this.maintenanceItemId,
    this.intervalKm,
    this.intervalMonths,
    this.intervalDays,
    required this.alertKm,
    required this.alertDays,
    required this.origin,
  });

  final String id;
  final String maintenanceItemId;
  final int? intervalKm;
  final int? intervalMonths;
  final int? intervalDays;
  final int alertKm;
  final int alertDays;
  final MaintenancePlanOrigin origin;

  factory MaintenancePlanSummary.fromJson(Map<String, dynamic> json) {
    return MaintenancePlanSummary(
      id: json['id'] as String,
      maintenanceItemId: json['maintenance_item_id'] as String,
      intervalKm: json['interval_km'] as int?,
      intervalMonths: json['interval_months'] as int?,
      intervalDays: json['interval_days'] as int?,
      alertKm: json['alert_km'] as int,
      alertDays: json['alert_days'] as int,
      origin: MaintenancePlanOrigin.fromWire(json['origin'] as String?),
    );
  }
}

/// A recurrence rule for one catalogue item on one vehicle, with due state
/// already computed by the server.
final class MaintenancePlan {
  const MaintenancePlan({
    required this.id,
    required this.maintenanceItemId,
    required this.itemSlug,
    required this.itemName,
    required this.itemKind,
    this.intervalKm,
    this.intervalMonths,
    this.intervalDays,
    required this.alertKm,
    required this.alertDays,
    required this.origin,
    required this.status,
    this.dueAtKm,
    this.dueOn,
    this.remainingKm,
    this.remainingDays,
    this.lastOccurredOn,
    this.lastMileageKm,
  });

  final String id;
  final String maintenanceItemId;
  final String itemSlug;
  final String itemName;
  final MaintenanceItemKind itemKind;
  final int? intervalKm;
  final int? intervalMonths;
  final int? intervalDays;
  final int alertKm;
  final int alertDays;
  final MaintenancePlanOrigin origin;
  final MaintenanceStatus status;
  final int? dueAtKm;
  final CivilDate? dueOn;
  final int? remainingKm;
  final int? remainingDays;
  final CivilDate? lastOccurredOn;
  final int? lastMileageKm;

  /// Enough of the catalogue row to open the record form with this item chosen.
  MaintenanceItem toCatalogueItem() {
    return MaintenanceItem(
      id: maintenanceItemId,
      slug: itemSlug,
      name: itemName,
      kind: itemKind,
      vehicleType: 'car',
      isCustom: false,
    );
  }

  factory MaintenancePlan.fromJson(Map<String, dynamic> json) {
    return MaintenancePlan(
      id: json['id'] as String,
      maintenanceItemId: json['maintenance_item_id'] as String,
      itemSlug: json['item_slug'] as String,
      itemName: json['item_name'] as String,
      itemKind: MaintenanceItemKind.fromWire(json['item_kind'] as String?),
      intervalKm: json['interval_km'] as int?,
      intervalMonths: json['interval_months'] as int?,
      intervalDays: json['interval_days'] as int?,
      alertKm: json['alert_km'] as int,
      alertDays: json['alert_days'] as int,
      origin: MaintenancePlanOrigin.fromWire(json['origin'] as String?),
      status: MaintenanceStatus.fromWire(json['status'] as String?),
      dueAtKm: json['due_at_km'] as int?,
      dueOn: CivilDate.tryParse(json['due_on'] as String?),
      remainingKm: json['remaining_km'] as int?,
      remainingDays: json['remaining_days'] as int?,
      lastOccurredOn: CivilDate.tryParse(json['last_occurred_on'] as String?),
      lastMileageKm: json['last_mileage_km'] as int?,
    );
  }
}
