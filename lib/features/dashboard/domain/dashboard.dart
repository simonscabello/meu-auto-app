import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';

enum AlertKind {
  manutencao,
  cuidado,
  garantia,
  ipva,
  licenciamento,
  seguro,
  desconhecido;

  static AlertKind fromWire(String? raw) =>
      parseEnum(raw, AlertKind.values, fallback: desconhecido);
}

enum AlertSeverity {
  vencido,
  venceEmBreve,
  desconhecido;

  static AlertSeverity fromWire(String? raw) =>
      parseEnum(raw, AlertSeverity.values, fallback: desconhecido);
}

enum AlertReferenceType {
  maintenancePlan,
  maintenanceRecord,
  obligation,
  seguro,
  desconhecido;

  static AlertReferenceType fromWire(String? raw) =>
      parseEnum(raw, AlertReferenceType.values, fallback: desconhecido);
}

final class Alert {
  const Alert({
    required this.kind,
    required this.severity,
    required this.title,
    this.subtitle,
    this.dueOn,
    this.dueAtKm,
    this.remainingDays,
    this.remainingKm,
    required this.referenceType,
    required this.referenceId,
  });

  final AlertKind kind;
  final AlertSeverity severity;
  final String title;
  final String? subtitle;
  final CivilDate? dueOn;
  final int? dueAtKm;
  final int? remainingDays;
  final int? remainingKm;
  final AlertReferenceType referenceType;
  final String referenceId;

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      kind: AlertKind.fromWire(json['kind'] as String?),
      severity: AlertSeverity.fromWire(json['severity'] as String?),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      dueOn: CivilDate.tryParse(json['due_on'] as String?),
      dueAtKm: json['due_at_km'] as int?,
      remainingDays: json['remaining_days'] as int?,
      remainingKm: json['remaining_km'] as int?,
      referenceType: AlertReferenceType.fromWire(
        json['reference_type'] as String?,
      ),
      referenceId: json['reference_id'] as String,
    );
  }
}

final class DashboardVehicle {
  const DashboardVehicle({
    required this.id,
    required this.brand,
    required this.model,
    this.version,
    this.nickname,
    this.plate,
  });

  final String id;
  final String brand;
  final String model;
  final String? version;
  final String? nickname;
  final String? plate;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
    return '$brand $model';
  }

  factory DashboardVehicle.fromJson(Map<String, dynamic> json) {
    return DashboardVehicle(
      id: json['id'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      version: json['version'] as String?,
      nickname: json['nickname'] as String?,
      plate: json['plate'] as String?,
    );
  }
}

final class DashboardOdometer {
  const DashboardOdometer({required this.currentKm, this.recordedOn});

  final int currentKm;
  final CivilDate? recordedOn;

  factory DashboardOdometer.fromJson(Map<String, dynamic> json) {
    return DashboardOdometer(
      currentKm: json['current_km'] as int,
      recordedOn: CivilDate.tryParse(json['recorded_on'] as String?),
    );
  }
}

final class DashboardAlerts {
  const DashboardAlerts({
    required this.overdue,
    required this.dueSoon,
    required this.needsBaseline,
    required this.items,
  });

  final int overdue;
  final int dueSoon;
  final int needsBaseline;
  final List<Alert> items;

  factory DashboardAlerts.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return DashboardAlerts(
      overdue: json['overdue'] as int,
      dueSoon: json['due_soon'] as int,
      needsBaseline: json['needs_baseline'] as int,
      items: [
        if (rawItems is List)
          for (final item in rawItems)
            if (item is Map) Alert.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

/// Just enough for the main screen to decide whether to show one discreet card.
///
/// Counts, not content: the questions themselves live on the profile endpoint. A
/// dashboard that carried them would grow every time a question is added, and
/// the card only ever needs to know there is one.
final class DashboardProfile {
  const DashboardProfile({
    required this.status,
    required this.powertrainKnown,
    required this.openQuestions,
  });

  final MaintenanceProfileStatus status;
  final bool powertrainKnown;
  final int openQuestions;

  factory DashboardProfile.fromJson(Map<String, dynamic> json) {
    return DashboardProfile(
      status: MaintenanceProfileStatus.fromWire(json['status'] as String?),
      powertrainKnown: json['powertrain_known'] as bool? ?? false,
      openQuestions: json['open_questions'] as int? ?? 0,
    );
  }

  /// What an older server, or one that could not answer, looks like: nothing to
  /// say, so the card does not appear.
  static const empty = DashboardProfile(
    status: MaintenanceProfileStatus.ready,
    powertrainKnown: true,
    openQuestions: 0,
  );
}

final class DashboardCosts {
  const DashboardCosts({
    required this.periodMonths,
    required this.since,
    required this.maintenanceCents,
    required this.obligationsCents,
    required this.seguroCents,
    required this.trackedCents,
    required this.trackedCategories,
  });

  final int periodMonths;
  final CivilDate since;
  final Money maintenanceCents;
  final Money obligationsCents;
  final Money seguroCents;
  final Money trackedCents;
  final List<String> trackedCategories;

  factory DashboardCosts.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['tracked_categories'];
    return DashboardCosts(
      periodMonths: json['period_months'] as int,
      since: CivilDate.parse(json['since'] as String),
      maintenanceCents: Money.fromCents(json['maintenance_cents'] as int),
      obligationsCents: Money.fromCents(json['obligations_cents'] as int),
      seguroCents: Money.fromCents(json['seguro_cents'] as int),
      trackedCents: Money.fromCents(json['tracked_cents'] as int),
      trackedCategories: [
        if (rawCategories is List)
          for (final item in rawCategories)
            if (item is String) item,
      ],
    );
  }
}

final class Dashboard {
  const Dashboard({
    required this.vehicle,
    required this.odometer,
    required this.alerts,
    required this.profile,
    required this.costs,
  });

  final DashboardVehicle vehicle;
  final DashboardOdometer odometer;
  final DashboardAlerts alerts;
  final DashboardProfile profile;
  final DashboardCosts costs;

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['profile'];
    return Dashboard(
      vehicle: DashboardVehicle.fromJson(_asMap(json['vehicle'])),
      odometer: DashboardOdometer.fromJson(_asMap(json['odometer'])),
      alerts: DashboardAlerts.fromJson(_asMap(json['alerts'])),
      // A server that predates the profile block still serves this screen. The
      // fallback says "nothing to ask", so the card simply does not appear.
      profile: rawProfile is Map
          ? DashboardProfile.fromJson(Map<String, dynamic>.from(rawProfile))
          : DashboardProfile.empty,
      costs: DashboardCosts.fromJson(_asMap(json['costs'])),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  return Map<String, dynamic>.from(value as Map);
}
