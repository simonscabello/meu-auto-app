import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
// The catalogue exists to produce a value the vehicle write accepts, so the
// fuel it reports is the vehicle module's enum rather than a second copy of it.
// The arrow only points this way: nothing under features/vehicle/domain knows
// this file exists.
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

/// The vehicle catalogue: brands, models and model years, mirrored by the
/// server from the FIPE table.
///
/// It replaces four free-text fields on the registration form with three
/// pickers. Nothing here is required to register a vehicle — the catalogue may
/// not have the car and the source may be down, so typing it by hand stays a
/// first-class path.
///
/// The server never exposes its supplier's ids, so neither does this file.
/// Every id here is a Meu Auto uuid.

/// One entry in the first picker.
final class VehicleBrand {
  const VehicleBrand({
    required this.id,
    required this.vehicleType,
    required this.name,
  });

  final String id;
  final VehicleType vehicleType;

  /// As the source writes it — `VW - VolksWagen`, not `Volkswagen`.
  final String name;

  factory VehicleBrand.fromJson(Map<String, dynamic> json) {
    return VehicleBrand(
      id: json['id'] as String,
      vehicleType: VehicleType.fromWire(json['vehicle_type'] as String?),
      name: json['name'] as String,
    );
  }
}

/// One entry in the second picker.
final class VehicleCatalogModel {
  const VehicleCatalogModel({
    required this.id,
    required this.brandId,
    required this.name,
  });

  final String id;
  final String brandId;

  /// Model and version in one string — `PRIUS 1.8 16V 5p Aut. (Híbrido)`. The
  /// source does not separate them, so neither does the app: splitting would
  /// be a guess, and it is the whole string an owner recognises anyway.
  final String name;

  factory VehicleCatalogModel.fromJson(Map<String, dynamic> json) {
    return VehicleCatalogModel(
      id: json['id'] as String,
      brandId: json['brand_id'] as String,
      name: json['name'] as String,
    );
  }
}

/// One entry in the third picker.
final class VehicleModelYear {
  const VehicleModelYear({
    required this.id,
    required this.modelId,
    required this.name,
    this.year,
    this.fuelLabel,
    this.fuelType,
  });

  final String id;
  final String modelId;

  /// `2017 Híbrido`.
  final String name;

  /// Null on the source's zero-kilometre entry, which is a price bucket for a
  /// new vehicle rather than a model year.
  final int? year;

  /// The source's word, for display.
  final String? fuelLabel;

  /// The same fuel in the vocabulary the vehicle form uses. Sent straight back
  /// on the POST — the app owns no translation table.
  ///
  /// Null when the source used a word the server has no equivalent for; the
  /// owner then picks the fuel themselves, as they did before the catalogue
  /// existed.
  final FuelType? fuelType;

  /// What the picker shows. Falls back to the source's own label for the
  /// zero-kilometre entry, whose `name` starts with the pseudo-year 32000.
  String get displayLabel {
    final fuel = fuelLabel?.trim();
    if (year == null) {
      return fuel == null || fuel.isEmpty ? 'Zero km' : 'Zero km · $fuel';
    }
    if (fuel == null || fuel.isEmpty) {
      return '$year';
    }
    return '$year · $fuel';
  }

  factory VehicleModelYear.fromJson(Map<String, dynamic> json) {
    return VehicleModelYear(
      id: json['id'] as String,
      modelId: json['model_id'] as String,
      name: json['name'] as String,
      year: json['year'] as int?,
      fuelLabel: json['fuel_label'] as String?,
      fuelType: FuelType.fromWireOrNull(json['fuel_type'] as String?),
    );
  }
}

/// A FIPE valuation, with the month it refers to.
final class FipePrice {
  const FipePrice({
    required this.price,
    required this.referenceMonth,
    required this.collectedAt,
  });

  final Money price;

  /// The first day of the month the valuation refers to. The day is always 1 —
  /// it is a month, and the day is only what makes it sortable.
  final CivilDate referenceMonth;

  /// When the server fetched it, which is not the same as what it refers to.
  /// It is on the wire because a price can be stale: with the source
  /// unreachable, the last known value is served rather than none.
  final DateTime collectedAt;

  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// `agosto de 2026`. Presentation of a value the server sent, not a
  /// computation — there is no date arithmetic here.
  String get referenceLabel {
    final month = referenceMonth.month;
    if (month < 1 || month > 12) {
      return '${referenceMonth.year}';
    }
    return '${_months[month - 1]} de ${referenceMonth.year}';
  }

  static FipePrice? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final cents = json['price_cents'];
    final reference = CivilDate.tryParse(json['reference_month'] as String?);
    final collected = json['collected_at'] as String?;
    if (cents is! int || reference == null || collected == null) {
      return null;
    }
    return FipePrice(
      price: Money.fromCents(cents),
      referenceMonth: reference,
      collectedAt: DateTime.parse(collected).toLocal(),
    );
  }
}

/// The last screen before a vehicle is registered: everything the form needs,
/// plus the valuation when there is one.
final class VehicleModelYearDetail {
  const VehicleModelYearDetail({
    required this.id,
    required this.modelId,
    required this.name,
    required this.brand,
    required this.model,
    this.year,
    this.fuelLabel,
    this.fuelType,
    this.fipeCode,
    this.fipePrice,
  });

  final String id;
  final String modelId;
  final String name;
  final int? year;
  final String? fuelLabel;
  final FuelType? fuelType;

  /// Null until the server has obtained a valuation for this vehicle at least
  /// once — the source only reveals the code on the detail route.
  final String? fipeCode;

  final VehicleBrand brand;
  final VehicleCatalogModel model;

  /// **Null is not an error.** When the source cannot be reached and nothing
  /// was stored before, everything else still arrives and registration works;
  /// only the valuation is missing.
  final FipePrice? fipePrice;

  factory VehicleModelYearDetail.fromJson(Map<String, dynamic> json) {
    return VehicleModelYearDetail(
      id: json['id'] as String,
      modelId: json['model_id'] as String,
      name: json['name'] as String,
      year: json['year'] as int?,
      fuelLabel: json['fuel_label'] as String?,
      fuelType: FuelType.fromWireOrNull(json['fuel_type'] as String?),
      fipeCode: json['fipe_code'] as String?,
      brand: VehicleBrand.fromJson(
        Map<String, dynamic>.from(json['brand'] as Map),
      ),
      model: VehicleCatalogModel.fromJson(
        Map<String, dynamic>.from(json['model'] as Map),
      ),
      fipePrice: FipePrice.fromJsonOrNull(json['fipe_price']),
    );
  }
}

/// What the picker hands back to the form.
///
/// Deliberately a snapshot plus one id. The three text fields are what the
/// owner saw and confirmed and are what the vehicle stores; only
/// [modelYearId] travels as an id, and the server derives the brand and model
/// links from it — so there is no way to submit a model that belongs to a
/// different brand.
final class VehicleCatalogSelection {
  const VehicleCatalogSelection({
    required this.modelYearId,
    required this.brandName,
    required this.modelName,
    this.modelYear,
    this.fuelType,
    this.fipeCode,
    this.fipePrice,
  });

  final String modelYearId;
  final String brandName;
  final String modelName;
  final int? modelYear;
  final FuelType? fuelType;
  final String? fipeCode;
  final FipePrice? fipePrice;

  factory VehicleCatalogSelection.fromDetail(VehicleModelYearDetail detail) {
    return VehicleCatalogSelection(
      modelYearId: detail.id,
      brandName: detail.brand.name,
      modelName: detail.model.name,
      modelYear: detail.year,
      fuelType: detail.fuelType,
      fipeCode: detail.fipeCode,
      fipePrice: detail.fipePrice,
    );
  }
}
