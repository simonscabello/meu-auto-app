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

  /// The vehicle does not have this component.
  ///
  /// It arrives only when a request asks for it — the plan list a screen reads
  /// leaves these out entirely. That is the point: a car that does not use a
  /// timing belt shows no timing belt card, disabled or otherwise.
  naoSeAplica,
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
    MaintenanceStatus.naoSeAplica => 'nao_se_aplica',
    MaintenanceStatus.desconhecido => '',
  };
}

/// How an item is maintained on this vehicle.
///
/// The server decides this, always. The app reads it to choose words — a tyre
/// that has run 50.000 km is worth checking, not "vencido" — and never to
/// decide whether something applies.
enum MaintenanceStrategy {
  /// Replace every X km or Y months.
  periodic,

  /// Look at it during a service. There may be no replacement at all.
  inspection,

  /// Replace when worn. An interval here is a horizon, not a deadline.
  conditionBased,

  /// The component exists and has no periodic rule.
  noSchedule,

  /// The vehicle does not have the component.
  notApplicable,

  desconhecido;

  static MaintenanceStrategy fromWire(String? raw) =>
      parseEnum(raw, MaintenanceStrategy.values, fallback: desconhecido);

  String get wire => switch (this) {
    MaintenanceStrategy.periodic => 'periodic',
    MaintenanceStrategy.inspection => 'inspection',
    MaintenanceStrategy.conditionBased => 'condition_based',
    MaintenanceStrategy.noSchedule => 'no_schedule',
    MaintenanceStrategy.notApplicable => 'not_applicable',
    MaintenanceStrategy.desconhecido => '',
  };
}

/// What the owner said about the past, when there is no record.
///
/// `unknown` and `never` are different answers and the interface must keep them
/// apart: "não lembro" is a gap in memory, "nunca foi feito" is a fact about
/// the car. Neither creates a service record.
enum MaintenanceHistoryStatus {
  notAsked,
  unknown,
  never,
  desconhecido;

  static MaintenanceHistoryStatus fromWire(String? raw) =>
      parseEnum(raw, MaintenanceHistoryStatus.values, fallback: desconhecido);

  String get wire => switch (this) {
    MaintenanceHistoryStatus.notAsked => 'not_asked',
    MaintenanceHistoryStatus.unknown => 'unknown',
    MaintenanceHistoryStatus.never => 'never',
    MaintenanceHistoryStatus.desconhecido => '',
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
    required this.strategy,
    required this.historyStatus,
    this.notes,
  });

  final String id;
  final String maintenanceItemId;
  final int? intervalKm;
  final int? intervalMonths;
  final int? intervalDays;
  final int alertKm;
  final int alertDays;
  final MaintenancePlanOrigin origin;
  final MaintenanceStrategy strategy;
  final MaintenanceHistoryStatus historyStatus;
  final String? notes;

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
      strategy: MaintenanceStrategy.fromWire(json['strategy'] as String?),
      historyStatus: MaintenanceHistoryStatus.fromWire(
        json['history_status'] as String?,
      ),
      notes: json['notes'] as String?,
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
    required this.strategy,
    required this.historyStatus,
    this.notes,
    this.historyQuestion,
    this.historyPriority = 0,
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
  final MaintenanceStrategy strategy;
  final MaintenanceHistoryStatus historyStatus;
  final String? notes;

  /// The pt-BR question to ask when this item has no baseline, written by the
  /// server. It is on the wire so the app does not carry a map from technical
  /// slug to question — which is how every car ended up being asked about a
  /// timing belt.
  final String? historyQuestion;

  /// How much the question matters, highest first. Presentation ordering that
  /// belongs to the catalogue rather than to a list of slugs inside the app.
  final int historyPriority;

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
      defaultStrategy: strategy,
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
      strategy: MaintenanceStrategy.fromWire(json['strategy'] as String?),
      historyStatus: MaintenanceHistoryStatus.fromWire(
        json['history_status'] as String?,
      ),
      notes: json['notes'] as String?,
      historyQuestion: json['history_question'] as String?,
      historyPriority: json['history_priority'] as int? ?? 0,
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
