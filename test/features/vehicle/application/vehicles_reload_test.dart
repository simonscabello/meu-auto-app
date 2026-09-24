import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/data/selected_vehicle_store.dart';

import '../../../support/fixtures.dart';

/// A reload that fails must not take the vehicle away from every tab.
///
/// In Riverpod 2 `AsyncValue.value` rethrows when an error carries no
/// previous value, and `reload()` used to replace the list with exactly that —
/// so a pull-to-refresh without signal, or the quiet reload after saving a
/// fill, turned Início, Cuidados and Documentos into an error at once.
void main() {
  test('a failed reload keeps the vehicle every tab is built on', () async {
    final adapter = _FlakyVehiclesAdapter();
    final client = ApiClient(adapter: adapter);
    addTearDown(client.close);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authControllerProvider.overrideWith(_LoggedIn.new),
        selectedVehicleStoreProvider.overrideWithValue(_MemoryStore()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedVehicleProvider, (_, _) {});

    await container.read(vehiclesProvider.future);
    await container.read(selectedVehicleIdProvider.future);
    final before = container.read(selectedVehicleProvider);
    expect(before.valueOrNull?.id, '22222222-2222-7222-8222-222222222222');

    adapter.offline = true;
    await container.read(vehiclesProvider.notifier).reload();

    final list = container.read(vehiclesProvider);
    expect(list.hasError, isTrue, reason: 'the failure is still reported');
    expect(list.valueOrNull?.vehicles, isNotEmpty);

    final after = container.read(selectedVehicleProvider);
    expect(after.hasError, isFalse);
    expect(after.valueOrNull?.id, before.valueOrNull?.id);
    // The read the screens do while building must not throw.
    expect(
      () => container.read(selectedVehicleProvider).valueOrNull,
      returnsNormally,
    );
  });

  test(
    'with no list ever loaded, the error is reported, not a vehicle',
    () async {
      final adapter = _FlakyVehiclesAdapter()..offline = true;
      final client = ApiClient(adapter: adapter);
      addTearDown(client.close);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authControllerProvider.overrideWith(_LoggedIn.new),
          selectedVehicleStoreProvider.overrideWithValue(_MemoryStore()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(selectedVehicleProvider, (_, _) {});

      await expectLater(
        container.read(vehiclesProvider.future),
        throwsA(anything),
      );
      final selected = container.read(selectedVehicleProvider);
      expect(selected.hasError, isTrue);
      expect(selected.valueOrNull, isNull);
    },
  );
}

final class _LoggedIn extends AuthController {
  @override
  Future<AuthStatus> build() async => AuthLoggedIn(
    User(
      id: 'u1',
      name: 'Ana',
      email: 'ana@example.com',
      createdAt: DateTime(2026),
    ),
  );
}

final class _MemoryStore implements SelectedVehicleStore {
  String? _id;

  @override
  Future<String?> read() async => _id;

  @override
  Future<void> write(String? id) async => _id = id;
}

final class _FlakyVehiclesAdapter implements HttpClientAdapter {
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sem sinal',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(loadFixture('vehicles_list.json')),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
