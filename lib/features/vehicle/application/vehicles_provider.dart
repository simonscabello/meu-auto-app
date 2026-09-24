import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/vehicle/data/selected_vehicle_store.dart';
import 'package:meu_auto/features/vehicle/data/vehicle_repository.dart';
import 'package:meu_auto/features/vehicle/domain/selected_vehicle.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(api: ref.watch(apiClientProvider));
});

final selectedVehicleStoreProvider = Provider<SelectedVehicleStore>((ref) {
  return SharedPreferencesSelectedVehicleStore();
});

final selectedVehicleIdProvider =
    AsyncNotifierProvider<SelectedVehicleIdController, String?>(
      SelectedVehicleIdController.new,
    );

class SelectedVehicleIdController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.watch(selectedVehicleStoreProvider).read();
  }

  Future<void> select(String? id) async {
    await ref.read(selectedVehicleStoreProvider).write(id);
    state = AsyncData(id);
  }
}

final class VehicleListState {
  const VehicleListState.unavailable() : vehicles = const [], available = false;

  const VehicleListState.loaded(this.vehicles) : available = true;

  final List<Vehicle> vehicles;
  final bool available;
}

final vehiclesProvider =
    AsyncNotifierProvider<VehiclesController, VehicleListState>(
      VehiclesController.new,
    );

class VehiclesController extends AsyncNotifier<VehicleListState> {
  @override
  Future<VehicleListState> build() async {
    final status = ref.watch(authControllerProvider).valueOrNull;
    if (status is! AuthLoggedIn) {
      return const VehicleListState.unavailable();
    }
    final vehicles = await ref.read(vehicleRepositoryProvider).list();
    return VehicleListState.loaded(vehicles);
  }

  Future<void> reload() async {
    final status = ref.read(authControllerProvider).valueOrNull;
    if (status is! AuthLoggedIn) {
      state = const AsyncData(VehicleListState.unavailable());
      return;
    }
    final result = await AsyncValue.guard(() async {
      final vehicles = await ref.read(vehicleRepositoryProvider).list();
      return VehicleListState.loaded(vehicles);
    });
    // A reload that fails keeps the list it already had. Every tab is built on this
    // list, and replacing it with a bare error turned a pull-to-refresh without signal —
    // or the quiet reload after saving a fill — into Início, Cuidados and Documentos all
    // failing at once. The error is still carried, for whoever asked for the reload.
    state = result.hasError && state.hasValue
        ? result.copyWithPrevious(state)
        : result;
  }

  Future<Vehicle> create({
    required String id,
    required String brand,
    required String model,
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
    final created = await ref
        .read(vehicleRepositoryProvider)
        .create(
          id: id,
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
        );
    await ref.read(selectedVehicleIdProvider.notifier).select(created.id);
    final current = state.valueOrNull?.vehicles ?? [];
    state = AsyncData(
      VehicleListState.loaded([
        for (final vehicle in current)
          if (vehicle.id != created.id) vehicle,
        created,
      ]),
    );
    return created;
  }

  Future<Vehicle> updateVehicle({
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
    final updated = await ref
        .read(vehicleRepositoryProvider)
        .update(
          id: id,
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
        );
    final current = state.valueOrNull?.vehicles ?? [];
    state = AsyncData(
      VehicleListState.loaded([
        for (final vehicle in current)
          if (vehicle.id == id) updated else vehicle,
      ]),
    );
    return updated;
  }

  /// Replaces a vehicle in the list from a payload the server already sent,
  /// without a round trip.
  ///
  /// Several endpoints return the updated vehicle alongside their own result —
  /// the odometer write does, and maintenance records will — precisely so the
  /// client does not have to ask for it again.
  void applyUpdated(Vehicle vehicle) {
    final current = state.valueOrNull;
    if (current == null || !current.available) {
      return;
    }
    state = AsyncData(
      VehicleListState.loaded([
        for (final existing in current.vehicles)
          if (existing.id == vehicle.id) vehicle else existing,
      ]),
    );
  }

  Future<void> delete(String id) async {
    await ref.read(vehicleRepositoryProvider).delete(id);
    final remaining = <Vehicle>[
      for (final vehicle in state.valueOrNull?.vehicles ?? const <Vehicle>[])
        if (vehicle.id != id) vehicle,
    ];
    state = AsyncData(VehicleListState.loaded(remaining));
    final storedId = await ref.read(selectedVehicleIdProvider.future);
    final resolved = resolveSelectedVehicleId(
      vehicleIds: remaining.map((vehicle) => vehicle.id),
      storedId: storedId,
    );
    await ref.read(selectedVehicleIdProvider.notifier).select(resolved);
  }
}

/// The vehicle every tab is about.
///
/// Built from whatever list is known, including one a failed reload kept: a
/// vehicle that was on screen a second ago does not stop existing because the
/// network did. Only when there has never been a list does this report the
/// error — the first load, which the splash screen handles.
final selectedVehicleProvider = Provider<AsyncValue<Vehicle?>>((ref) {
  final listAsync = ref.watch(vehiclesProvider);
  final storedAsync = ref.watch(selectedVehicleIdProvider);

  final list = listAsync.valueOrNull;
  if (list == null) {
    if (listAsync.hasError) {
      return AsyncError(listAsync.error!, listAsync.stackTrace!);
    }
    return const AsyncLoading();
  }
  if (!list.available) {
    return const AsyncLoading();
  }
  if (storedAsync.isLoading && !storedAsync.hasValue) {
    return const AsyncLoading();
  }
  final id = resolveSelectedVehicleId(
    vehicleIds: list.vehicles.map((vehicle) => vehicle.id),
    storedId: storedAsync.valueOrNull,
  );
  if (id == null) {
    return const AsyncData(null);
  }
  for (final vehicle in list.vehicles) {
    if (vehicle.id == id) {
      return AsyncData(vehicle);
    }
  }
  return const AsyncData(null);
});
