import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';

enum VehicleType {
  car,
  desconhecido;

  static VehicleType fromWire(String? raw) =>
      parseEnum(raw, VehicleType.values, fallback: desconhecido);
}

enum FuelType {
  flex,
  gasolina,
  etanol,
  diesel,
  gnv,
  eletrico,
  hibrido,
  desconhecido;

  /// Null and `desconhecido` are different answers: null is "the owner never
  /// said", `desconhecido` is "the server named a fuel this build does not
  /// know yet". Only the first should read as an empty field on screen.
  static FuelType? fromWireOrNull(String? raw) {
    if (raw == null) return null;
    return parseEnum(raw, FuelType.values, fallback: desconhecido);
  }

  String get label => switch (this) {
    FuelType.flex => 'Flex',
    FuelType.gasolina => 'Gasolina',
    FuelType.etanol => 'Etanol',
    FuelType.diesel => 'Diesel',
    FuelType.gnv => 'GNV',
    FuelType.eletrico => 'Elétrico',
    FuelType.hibrido => 'Híbrido',
    FuelType.desconhecido => 'Desconhecido',
  };
}

/// Strips separators and uppercases, matching the server so a plate it would
/// accept is not rejected here.
String normalizePlate(String raw) {
  final buffer = StringBuffer();
  for (final unit in raw.toUpperCase().codeUnits) {
    final isLetter = unit >= 65 && unit <= 90;
    final isDigit = unit >= 48 && unit <= 57;
    if (isLetter || isDigit) {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

final class Vehicle {
  const Vehicle({
    required this.id,
    required this.vehicleType,
    required this.brand,
    required this.model,
    this.version,
    this.manufactureYear,
    this.modelYear,
    this.plate,
    this.renavam,
    this.chassis,
    this.fuelType,
    this.color,
    this.nickname,
    this.fipeCode,
    this.catalogBrandId,
    this.catalogModelId,
    this.catalogModelYearId,
    required this.currentMileageKm,
    this.currentMileageAt,
    this.refueling = RefuelingCapability.unspecified,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final VehicleType vehicleType;
  final String brand;
  final String model;
  final String? version;
  final int? manufactureYear;
  final int? modelYear;
  final String? plate;
  final String? renavam;
  final String? chassis;
  final FuelType? fuelType;
  final String? color;
  final String? nickname;

  /// The FIPE code as it was when the vehicle was registered.
  ///
  /// Was always null while the contract had it in responses and in no request.
  /// It is now filled whenever the owner picked from the catalogue, and it is
  /// a snapshot: the source rewrites its own descriptions, and a service
  /// history that rewrites itself with them is worth less at resale.
  final String? fipeCode;

  /// Which catalogue entry this vehicle was registered from, or null when it
  /// was typed by hand.
  ///
  /// Nullable and always will be — a hand-typed vehicle is a first-class
  /// vehicle. The app sends only [catalogModelYearId] on a write; the server
  /// derives the other two, which is what makes an inconsistent brand/model
  /// pair impossible to express.
  final String? catalogBrandId;
  final String? catalogModelId;
  final String? catalogModelYearId;

  /// Whether this vehicle came from the catalogue. Used to pre-open the picker
  /// on the right entry when editing.
  bool get isFromCatalog => catalogModelYearId != null;

  final int currentMileageKm;
  final CivilDate? currentMileageAt;

  /// What this vehicle accepts at a pump. The server decides; the app never
  /// infers ethanol from flex.
  final RefuelingCapability refueling;

  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
    return '$brand $model';
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      vehicleType: VehicleType.fromWire(json['vehicle_type'] as String?),
      brand: json['brand'] as String,
      model: json['model'] as String,
      version: json['version'] as String?,
      manufactureYear: json['manufacture_year'] as int?,
      modelYear: json['model_year'] as int?,
      plate: json['plate'] as String?,
      renavam: json['renavam'] as String?,
      chassis: json['chassis'] as String?,
      fuelType: FuelType.fromWireOrNull(json['fuel_type'] as String?),
      color: json['color'] as String?,
      nickname: json['nickname'] as String?,
      fipeCode: json['fipe_code'] as String?,
      catalogBrandId: json['catalog_brand_id'] as String?,
      catalogModelId: json['catalog_model_id'] as String?,
      catalogModelYearId: json['catalog_model_year_id'] as String?,
      currentMileageKm: json['current_mileage_km'] as int,
      currentMileageAt: CivilDate.tryParse(
        json['current_mileage_at'] as String?,
      ),
      refueling: RefuelingCapability.fromJson(json['refueling']),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
