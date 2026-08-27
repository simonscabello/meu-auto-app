import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/core/domain/money.dart';

enum ConsumptionStatus {
  ok,
  insufficientData,
  partialFill,
  unavailable,
  desconhecido;

  static ConsumptionStatus fromWire(String? raw) =>
      parseEnum(raw, ConsumptionStatus.values, fallback: desconhecido);
}

enum AbastecimentoFuel {
  gasolina,
  etanol,
  diesel,
  gnv,
  desconhecido;

  static AbastecimentoFuel fromWire(String? raw) =>
      parseEnum(raw, AbastecimentoFuel.values, fallback: desconhecido);

  String get wire => name;
}

/// What this vehicle accepts at a pump. Derived on the server from `fuel_type`.
final class RefuelingCapability {
  const RefuelingCapability({
    required this.supported,
    required this.fuelTypes,
  });

  /// An older payload, or a parse that found nothing: keep the entry visible
  /// rather than inventing that the car is electric.
  static const unspecified = RefuelingCapability(
    supported: true,
    fuelTypes: [],
  );

  static const unsupported = RefuelingCapability(
    supported: false,
    fuelTypes: [],
  );

  final bool supported;
  final List<AbastecimentoFuel> fuelTypes;

  factory RefuelingCapability.fromJson(Object? raw) {
    if (raw is! Map) return unspecified;
    final json = Map<String, dynamic>.from(raw);
    final types = json['fuel_types'];
    return RefuelingCapability(
      supported: json['supported'] as bool? ?? false,
      fuelTypes: [
        if (types is List)
          for (final item in types)
            if (item is String) AbastecimentoFuel.fromWire(item),
      ],
    );
  }

  List<AbastecimentoFuel> get offeredFuels => [
    for (final fuel in fuelTypes)
      if (fuel != AbastecimentoFuel.desconhecido) fuel,
  ];
}

final class Consumption {
  const Consumption({this.value, required this.unit, required this.status});

  /// km/L as the server sent it, two decimals. Null whenever [status] is not
  /// [ConsumptionStatus.ok]. The app never fills this in.
  final double? value;
  final String unit;
  final ConsumptionStatus status;

  factory Consumption.fromJson(Map<String, dynamic> json) {
    return Consumption(
      value: _asDouble(json['value']),
      unit: json['unit'] as String? ?? 'km_per_liter',
      status: ConsumptionStatus.fromWire(json['status'] as String?),
    );
  }
}

final class Abastecimento {
  const Abastecimento({
    required this.id,
    required this.vehicleId,
    required this.occurredOn,
    required this.mileageKm,
    required this.volumeMl,
    required this.totalCostCents,
    required this.pricePerLiterCents,
    required this.fuel,
    required this.fullTank,
    this.stationName,
    this.notes,
    required this.consumption,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vehicleId;
  final CivilDate occurredOn;
  final int mileageKm;
  final int volumeMl;
  final Money totalCostCents;
  final Money pricePerLiterCents;
  final AbastecimentoFuel fuel;
  final bool fullTank;
  final String? stationName;
  final String? notes;
  final Consumption consumption;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Abastecimento.fromJson(Map<String, dynamic> json) {
    return Abastecimento(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      occurredOn: CivilDate.parse(json['occurred_on'] as String),
      mileageKm: json['mileage_km'] as int,
      volumeMl: json['volume_ml'] as int,
      totalCostCents: Money.fromCents(json['total_cost_cents'] as int),
      pricePerLiterCents: Money.fromCents(json['price_per_liter_cents'] as int),
      fuel: AbastecimentoFuel.fromWire(json['fuel'] as String?),
      fullTank: json['full_tank'] as bool,
      stationName: json['station_name'] as String?,
      notes: json['notes'] as String?,
      consumption: Consumption.fromJson(
        Map<String, dynamic>.from(json['consumption'] as Map),
      ),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

/// The dashboard's reduced last-fill block. Same consumption the list uses.
final class LastAbastecimento {
  const LastAbastecimento({
    required this.id,
    required this.occurredOn,
    required this.totalCostCents,
    required this.volumeMl,
    required this.pricePerLiterCents,
    required this.fuel,
    required this.consumption,
  });

  final String id;
  final CivilDate occurredOn;
  final Money totalCostCents;
  final int volumeMl;
  final Money pricePerLiterCents;
  final AbastecimentoFuel fuel;
  final Consumption consumption;

  factory LastAbastecimento.fromJson(Map<String, dynamic> json) {
    return LastAbastecimento(
      id: json['id'] as String,
      occurredOn: CivilDate.parse(json['occurred_on'] as String),
      totalCostCents: Money.fromCents(json['total_cost_cents'] as int),
      volumeMl: json['volume_ml'] as int,
      pricePerLiterCents: Money.fromCents(json['price_per_liter_cents'] as int),
      fuel: AbastecimentoFuel.fromWire(json['fuel'] as String?),
      consumption: Consumption.fromJson(
        Map<String, dynamic>.from(json['consumption'] as Map),
      ),
    );
  }
}

/// The fuel the form should start on. Never invents a type the server did not
/// list — it only chooses among [offered].
AbastecimentoFuel? defaultAbastecimentoFuel({
  required List<AbastecimentoFuel> offered,
  AbastecimentoFuel? lastUsed,
}) {
  if (offered.isEmpty) return null;
  if (offered.length == 1) return offered.single;
  if (lastUsed != null && offered.contains(lastUsed)) return lastUsed;
  return offered.first;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}
