import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/catalog/data/vehicle_catalog_repository.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';

final vehicleCatalogRepositoryProvider = Provider<VehicleCatalogRepository>((
  ref,
) {
  return VehicleCatalogRepository(api: ref.watch(apiClientProvider));
});

/// The brand list. Cached for the session, like the maintenance catalogue: it
/// changes rarely, the picker opens often, and going back a step must not cost
/// a round trip.
final vehicleBrandsProvider = FutureProvider<List<VehicleBrand>>((ref) {
  return ref.watch(vehicleCatalogRepositoryProvider).brands();
});

/// Keyed by brand, so stepping back to the brand list and forward into the
/// same brand again is instant — the same reason the read models are keyed by
/// vehicle.
final vehicleModelsProvider =
    FutureProvider.family<List<VehicleCatalogModel>, String>((ref, brandId) {
      return ref.watch(vehicleCatalogRepositoryProvider).models(brandId);
    });

final vehicleModelYearsProvider =
    FutureProvider.family<List<VehicleModelYear>, String>((ref, modelId) {
      return ref.watch(vehicleCatalogRepositoryProvider).years(modelId);
    });

/// The detail, including the valuation.
///
/// NOT cached across a picker session on purpose: unlike the three lists, the
/// price it carries is the one thing in the catalogue that genuinely changes,
/// and the server already decides when to refresh it. Keeping this a family
/// provider means a second look at the same vehicle is cheap without the app
/// pinning a stale number of its own.
final vehicleModelYearDetailProvider =
    FutureProvider.family<VehicleModelYearDetail, String>((ref, modelYearId) {
      return ref.watch(vehicleCatalogRepositoryProvider).detail(modelYearId);
    });
