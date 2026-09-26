import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/push/push_device.dart';
import 'package:meu_auto/core/push/push_registration.dart';
import 'package:meu_auto/core/router/app_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/notification/domain/push_tap.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Watched by the root widget, so it lives as long as the app does.
final pushCoordinatorProvider = Provider<PushCoordinator>((ref) {
  final coordinator = PushCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Ties this phone to the signed-in account, and a tapped reminder to the
/// screen it is about.
///
/// Apart from [PushDevice] on purpose: the device side is plumbing; this is
/// the product — register at sign-in, and on a tap, **switch to the car the
/// reminder is about before opening anything**, because every screen it can
/// open is about the selected car.
class PushCoordinator {
  PushCoordinator(this._ref) {
    _ref.listen<AsyncValue<AuthStatus>>(authControllerProvider, (
      previous,
      next,
    ) {
      final status = next.valueOrNull;
      if (status is AuthLoggedIn) {
        final wasIn = previous?.valueOrNull is AuthLoggedIn;
        if (!wasIn || _userId != status.user.id) {
          _userId = status.user.id;
          unawaited(_onSignedIn(status.user.id));
        }
        unawaited(_deliverPending());
      } else if (status != null) {
        _userId = null;
      }
    }, fireImmediately: true);
    _ref.listen<AsyncValue<VehicleListState>>(
      vehiclesProvider,
      (_, _) => unawaited(_deliverPending()),
    );
  }

  static const permissionAskedKey = 'push_permission_asked';

  final Ref _ref;

  String? _userId;
  PushTap? _pending;
  bool _listening = false;
  bool _delivering = false;
  bool _askedThisRun = false;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<Map<String, String>>? _tapSubscription;

  PushDevice get _device => _ref.read(pushDeviceProvider);
  PushRegistration get _registration => _ref.read(pushRegistrationProvider);

  Future<void> _onSignedIn(String userId) async {
    if (!_device.isSupported) return;
    await _device.init();
    if (!_device.isReady) return;

    await _registration.register(userId);

    if (_listening) return;
    _listening = true;
    _refreshSubscription = _device.onTokenRefresh.listen((token) {
      final current = _userId;
      if (current != null) unawaited(_registration.send(current, token));
    });
    _tapSubscription = _device.onTap.listen(_onTap);

    // The reminder that opened the app from closed. Read only now: before the
    // session exists — or behind the biometric lock — there is no car to
    // switch to and nowhere to go.
    final initial = await _device.initialTap();
    if (initial != null) _onTap(initial);
  }

  void _onTap(Map<String, String> data) {
    final tap = PushTap.fromData(data);
    if (tap == null) return;
    _pending = tap;
    unawaited(_deliverPending());
  }

  /// Opens the pending tap once the app is really in: signed in, past the
  /// lock, with the car list loaded. Earlier, the router is still on the
  /// splash or the lock, and the screen would open behind them or not at all.
  Future<void> _deliverPending() async {
    final tap = _pending;
    if (tap == null || _delivering) return;
    if (_ref.read(authControllerProvider).valueOrNull is! AuthLoggedIn) return;
    final list = _ref.read(vehiclesProvider).valueOrNull;
    if (list == null || !list.available) return;

    _pending = null;
    _delivering = true;
    try {
      final router = _ref.read(appRouterProvider);
      // A reminder about a car no longer on the account — deleted, or from a
      // previous owner of this phone — opens Início, never another car.
      if (!list.vehicles.any((vehicle) => vehicle.id == tap.vehicleId)) {
        router.go(AppRoutes.home);
        return;
      }
      await _ref.read(selectedVehicleIdProvider.notifier).select(tap.vehicleId);
      // The reminder exists because something fell due: whatever the tabs
      // cached is already old.
      invalidateVehicleDerivedWith(_ref.invalidate, tap.vehicleId);

      // Início underneath, so back from the item lands on the car's home
      // instead of leaving the app.
      router.go(AppRoutes.home);
      await WidgetsBinding.instance.endOfFrame;
      unawaited(router.push<void>(tap.route));
    } finally {
      _delivering = false;
    }
  }

  /// Android 13+'s question, asked once per installation, the first time
  /// Início has shown the car — never on first boot, and never to someone
  /// who turned the reminders off in Perfil.
  Future<void> askPermissionOnce() async {
    if (_askedThisRun) return;
    _askedThisRun = true;

    final userId = _userId;
    if (userId == null || !_device.isSupported) return;
    await _device.init();
    if (!_device.isReady) return;
    if (!await _registration.isEnabled(userId)) return;
    if (await _device.hasPermission()) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(permissionAskedKey) ?? false) return;
    await prefs.setBool(permissionAskedKey, true);
    await _device.requestPermission();
  }

  void dispose() {
    _refreshSubscription?.cancel();
    _tapSubscription?.cancel();
  }
}
