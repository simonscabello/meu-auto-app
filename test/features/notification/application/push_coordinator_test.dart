import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/push/push_device.dart';
import 'package:meu_auto/core/push/push_registration.dart';
import 'package:meu_auto/core/router/app_router.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/notification/application/push_coordinator.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/data/selected_vehicle_store.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/push_fakes.dart';

/// The product side of push: the phone is registered at sign-in, and a tapped
/// reminder switches to its car before opening anything — every screen it can
/// open is about the selected car.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('registers this phone when the owner signs in', (tester) async {
    final app = await _App.pump(tester);

    app.auth.signIn();
    await tester.pumpAndSettle();

    expect(app.server.registrations.single.body['token'], 'token-1');
  });

  testWidgets('a tapped reminder switches to its car, then opens the item '
      'over Início', (tester) async {
    final app = await _App.pump(tester, signedIn: true);

    app.device.taps.add({
      'kind': 'reminder',
      'vehicle_id': 'v2',
      'reference_type': 'obligation',
      'reference_id': 'o1',
    });
    await tester.pumpAndSettle();

    expect(app.selected.id, 'v2');
    expect(find.text('obrigação o1'), findsOneWidget);
    // Back from the item lands on the car's Início, not outside the app.
    expect(app.router.canPop(), isTrue);
    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('início'), findsOneWidget);
  });

  testWidgets('the reminder that opened the app waits for the lock to open', (
    tester,
  ) async {
    final app = await _App.pump(tester, locked: true);
    app.device.initial = {'kind': 'reminder', 'vehicle_id': 'v2'};
    await tester.pumpAndSettle();

    expect(find.text('início'), findsOneWidget);
    expect(app.selected.id, isNull);

    app.auth.signIn();
    await tester.pumpAndSettle();

    // Several items: the car's list of alerts.
    expect(app.selected.id, 'v2');
    expect(find.text('avisos'), findsOneWidget);
  });

  testWidgets('a reminder about a car no longer on the account opens Início', (
    tester,
  ) async {
    final app = await _App.pump(tester, signedIn: true);

    app.device.taps.add({
      'kind': 'reminder',
      'vehicle_id': 'sold',
      'reference_type': 'obligation',
      'reference_id': 'o1',
    });
    await tester.pumpAndSettle();

    expect(find.text('início'), findsOneWidget);
    expect(app.selected.id, isNull);
  });

  testWidgets('a rotated token goes to the server for whoever is signed in', (
    tester,
  ) async {
    final app = await _App.pump(tester, signedIn: true);

    app.device.refreshes.add('token-2');
    await tester.pumpAndSettle();
    expect(
      app.server.registrations.map((r) => r.body['token']),
      contains('token-2'),
    );

    app.auth.signOut();
    await tester.pumpAndSettle();
    app.device.refreshes.add('token-3');
    await tester.pumpAndSettle();
    expect(
      app.server.registrations.map((r) => r.body['token']),
      isNot(contains('token-3')),
    );
  });

  testWidgets('Android is asked once, and never by someone who turned the '
      'reminders off', (tester) async {
    final app = await _App.pump(tester, signedIn: true);
    final coordinator = app.container.read(pushCoordinatorProvider);

    await coordinator.askPermissionOnce();
    await coordinator.askPermissionOnce();
    expect(app.device.permissionRequests, 1);

    final other = await _App.pump(tester, signedIn: true);
    other.optOut.optedOut.add('u1');
    await other.container.read(pushCoordinatorProvider).askPermissionOnce();
    expect(other.device.permissionRequests, 0);
  });

  testWidgets('a phone that already allows notifications is not asked', (
    tester,
  ) async {
    final app = await _App.pump(tester, signedIn: true, permitted: true);

    await app.container.read(pushCoordinatorProvider).askPermissionOnce();

    expect(app.device.permissionRequests, 0);
  });
}

final class _App {
  _App(
    this.container,
    this.router,
    this.device,
    this.server,
    this.optOut,
    this.selected,
  );

  final ProviderContainer container;
  final GoRouter router;
  final FakePushDevice device;
  final DeviceApi server;
  final MemoryPushOptOut optOut;
  final _MemorySelection selected;

  _ScriptedAuth get auth =>
      container.read(authControllerProvider.notifier) as _ScriptedAuth;

  static Future<_App> pump(
    WidgetTester tester, {
    bool signedIn = false,
    bool locked = false,
    bool permitted = false,
  }) async {
    final device = FakePushDevice(permitted: permitted);
    final server = DeviceApi();
    final optOut = MemoryPushOptOut();
    final selected = _MemorySelection();
    final api = ApiClient(adapter: server, logPrint: (_) {});
    addTearDown(api.close);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('início')),
        GoRoute(path: '/avisos', builder: (_, _) => const Text('avisos')),
        GoRoute(
          path: '/obrigacoes/:id',
          builder: (_, state) =>
              Text('obrigação ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    final initial = signedIn
        ? AuthLoggedIn(_user)
        : locked
        ? const AuthLocked()
        : const AuthLoggedOut();

    final container = ProviderContainer(
      overrides: [
        pushDeviceProvider.overrideWithValue(device),
        pushOptOutStoreProvider.overrideWithValue(optOut),
        apiClientProvider.overrideWithValue(api),
        appRouterProvider.overrideWithValue(router),
        authControllerProvider.overrideWith(() => _ScriptedAuth(initial)),
        vehiclesProvider.overrideWith(_TwoCars.new),
        selectedVehicleStoreProvider.overrideWithValue(selected),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(pushCoordinatorProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _App(container, router, device, server, optOut, selected);
  }
}

final _user = User(
  id: 'u1',
  name: 'Ana',
  email: 'ana@example.com',
  createdAt: DateTime(2026),
);

final class _ScriptedAuth extends AuthController {
  _ScriptedAuth(this._initial);

  final AuthStatus _initial;

  @override
  Future<AuthStatus> build() async => _initial;

  void signIn() => state = AsyncData(AuthLoggedIn(_user));

  void signOut() => state = const AsyncData(AuthLoggedOut());
}

final class _TwoCars extends VehiclesController {
  @override
  Future<VehicleListState> build() async =>
      VehicleListState.loaded([_car('v1', 'Uno'), _car('v2', 'Fit')]);
}

Vehicle _car(String id, String model) => Vehicle(
  id: id,
  vehicleType: VehicleType.car,
  brand: 'Marca',
  model: model,
  currentMileageKm: 10000,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final class _MemorySelection implements SelectedVehicleStore {
  String? id;

  @override
  Future<String?> read() async => id;

  @override
  Future<void> write(String? id) async => this.id = id;
}
