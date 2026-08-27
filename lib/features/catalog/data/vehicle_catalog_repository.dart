import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';

/// Reads the vehicle catalogue. Four GETs and nothing else — the catalogue is
/// reference data and the app never writes to it.
///
/// The server mirrors the source into its own database, so a hit here is
/// usually a database read on its side, not a call to a third party. That is
/// why these can be asked for freely and cached with a plain `FutureProvider`.
final class VehicleCatalogRepository {
  VehicleCatalogRepository({required this.api});

  final ApiClient api;

  /// `vehicleType` defaults to the server's own default (`car`) when omitted.
  /// The app has no reason to send it today — motorcycles are not in scope on
  /// either side — but the parameter is here because the query exists and
  /// leaving it out would mean editing this file rather than a call site.
  Future<List<VehicleBrand>> brands({String? vehicleType}) async {
    final body = await api.get(
      ApiPaths.vehicleBrands,
      query: {'vehicle_type': ?vehicleType},
    );
    return listOf(body, VehicleBrand.fromJson);
  }

  Future<List<VehicleCatalogModel>> models(String brandId) async {
    final body = await api.get(ApiPaths.vehicleBrandModels(brandId));
    return listOf(body, VehicleCatalogModel.fromJson);
  }

  Future<List<VehicleModelYear>> years(String modelId) async {
    final body = await api.get(ApiPaths.vehicleModelYears(modelId));
    return listOf(body, VehicleModelYear.fromJson);
  }

  /// The chosen vehicle with its FIPE code and valuation.
  ///
  /// This one can answer `200` with `fipe_price: null`. That is the contract
  /// working, not a degraded response to retry — see [VehicleModelYearDetail].
  Future<VehicleModelYearDetail> detail(String modelYearId) async {
    final body = await api.get(ApiPaths.vehicleModelYear(modelYearId));
    return VehicleModelYearDetail.fromJson(body);
  }
}
