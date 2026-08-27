import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

final class VehicleRepository {
  VehicleRepository({required this.api, String Function()? newId})
    : _newId = newId ?? newClientId;

  final ApiClient api;
  final String Function() _newId;

  Future<List<Vehicle>> list() async {
    final body = await api.get(ApiPaths.vehicles);
    return listOf(body, Vehicle.fromJson);
  }

  Future<Vehicle> get(String id) async {
    final body = await api.get(ApiPaths.vehicle(id));
    return Vehicle.fromJson(body);
  }

  Future<Vehicle> create({
    required String brand,
    required String model,
    String? id,
    String? version,
    int? manufactureYear,
    int? modelYear,
    String? plate,
    String? renavam,
    String? chassis,
    FuelType? fuelType,
    String? color,
    String? nickname,
    String? catalogModelYearId,
    String? fipeCode,
    int? currentMileageKm,
  }) async {
    final body = await api.post(
      ApiPaths.vehicles,
      body: _body(
        id: id ?? _newId(),
        brand: brand,
        model: model,
        version: version,
        manufactureYear: manufactureYear,
        modelYear: modelYear,
        plate: plate,
        renavam: renavam,
        chassis: chassis,
        fuelType: fuelType,
        color: color,
        nickname: nickname,
        catalogModelYearId: catalogModelYearId,
        fipeCode: fipeCode,
        currentMileageKm: currentMileageKm,
      ),
    );
    return Vehicle.fromJson(body);
  }

  Future<Vehicle> update({
    required String id,
    String? brand,
    String? model,
    String? version,
    int? manufactureYear,
    int? modelYear,
    String? plate,
    String? renavam,
    String? chassis,
    FuelType? fuelType,
    String? color,
    String? nickname,
    String? catalogModelYearId,
    String? fipeCode,
  }) async {
    final body = await api.patch(
      ApiPaths.vehicle(id),
      body: _body(
        brand: brand,
        model: model,
        version: version,
        manufactureYear: manufactureYear,
        modelYear: modelYear,
        plate: plate,
        renavam: renavam,
        chassis: chassis,
        fuelType: fuelType,
        color: color,
        nickname: nickname,
        catalogModelYearId: catalogModelYearId,
        fipeCode: fipeCode,
      ),
    );
    return Vehicle.fromJson(body);
  }

  Future<void> delete(String id) async {
    await api.delete(ApiPaths.vehicle(id));
  }

  Map<String, dynamic> _body({
    String? id,
    String? brand,
    String? model,
    String? version,
    int? manufactureYear,
    int? modelYear,
    String? plate,
    String? renavam,
    String? chassis,
    FuelType? fuelType,
    String? color,
    String? nickname,
    String? catalogModelYearId,
    String? fipeCode,
    int? currentMileageKm,
  }) {
    final plateValue = _plate(plate);
    final fuelValue = fuelType == null || fuelType == FuelType.desconhecido
        ? null
        : fuelType.name;
    return {
      'id': ?id,
      'brand': ?_text(brand),
      'model': ?_text(model),
      'version': ?_text(version),
      'manufacture_year': ?manufactureYear,
      'model_year': ?modelYear,
      'plate': ?plateValue,
      'renavam': ?_text(renavam),
      'chassis': ?_chassis(chassis),
      'fuel_type': ?fuelValue,
      'color': ?_text(color),
      'nickname': ?_text(nickname),
      // The only catalogue id the app ever sends. The brand and the model are
      // derived server-side from it, so a model that belongs to another brand
      // is not expressible from here.
      'catalog_model_year_id': ?_text(catalogModelYearId),
      'fipe_code': ?_text(fipeCode),
      'current_mileage_km': ?currentMileageKm,
    };
  }
}

String? _text(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? _plate(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = normalizePlate(value);
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _chassis(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.toUpperCase();
}
