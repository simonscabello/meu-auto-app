import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';

/// What kind of catalogue entry this is.
///
/// `maintenance` is a service that belongs on the history a buyer would read.
/// `care` is a recurring habit (tyre pressure, a wash) that uses the same
/// due engine with a short interval. The two share a table so one record
/// form covers both; the app shows them in separate groups.
enum MaintenanceItemKind {
  maintenance,
  care,
  desconhecido;

  static MaintenanceItemKind fromWire(String? raw) =>
      parseEnum(raw, MaintenanceItemKind.values, fallback: desconhecido);

  String get sectionTitle => switch (this) {
    MaintenanceItemKind.care => 'Cuidados do dia a dia',
    MaintenanceItemKind.maintenance ||
    MaintenanceItemKind.desconhecido => 'Manutenção',
  };

  /// The value the API accepts. Unknown is never sent.
  String? get wire => switch (this) {
    MaintenanceItemKind.maintenance => 'maintenance',
    MaintenanceItemKind.care => 'care',
    MaintenanceItemKind.desconhecido => null,
  };
}

/// An entry in the maintenance catalogue: the 26 seeded ones, plus any the
/// owner created for something the catalogue does not name.
final class MaintenanceItem {
  const MaintenanceItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.kind,
    required this.vehicleType,
    required this.isCustom,
    required this.defaultStrategy,
    this.defaultIntervalKm,
    this.defaultIntervalMonths,
    this.defaultIntervalDays,
  });

  final String id;
  final String slug;
  final String name;
  final MaintenanceItemKind kind;
  final String vehicleType;
  final bool isCustom;

  /// How this item is maintained as a concept. The plan for a given vehicle may
  /// say something else — including that the vehicle does not have it.
  final MaintenanceStrategy defaultStrategy;

  final int? defaultIntervalKm;
  final int? defaultIntervalMonths;
  final int? defaultIntervalDays;

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceItem(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      kind: MaintenanceItemKind.fromWire(json['kind'] as String?),
      vehicleType: json['vehicle_type'] as String? ?? 'car',
      isCustom: json['is_custom'] as bool? ?? false,
      defaultStrategy: MaintenanceStrategy.fromWire(
        json['default_strategy'] as String?,
      ),
      defaultIntervalKm: json['default_interval_km'] as int?,
      defaultIntervalMonths: json['default_interval_months'] as int?,
      defaultIntervalDays: json['default_interval_days'] as int?,
    );
  }
}
