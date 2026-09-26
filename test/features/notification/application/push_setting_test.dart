import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/push/push_device.dart';
import 'package:meu_auto/core/push/push_registration.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/notification/application/push_setting.dart';

import '../../../support/push_fakes.dart';

/// Perfil's "Avisos no celular": whether there is a row at all, what it says,
/// and what flipping it does.
void main() {
  test('no row where the phone cannot be reminded', () async {
    for (final device in [
      FakePushDevice(supported: false),
      FakePushDevice(firebase: false),
    ]) {
      final h = _Harness(device);
      expect(await h.setting(), isNull);
    }
  });

  test('on, and Android allowing it, is plain on', () async {
    final h = _Harness(FakePushDevice(permitted: true));

    final setting = await h.setting();

    expect(setting?.enabled, isTrue);
    expect(setting?.blocked, isFalse);
  });

  test('on while Android refuses is said to be blocked', () async {
    final h = _Harness(FakePushDevice(permitted: false));

    final setting = await h.setting();

    expect(setting?.enabled, isTrue);
    expect(setting?.blocked, isTrue);
  });

  test('turning it on asks Android when it has not allowed yet', () async {
    final device = FakePushDevice(permitted: false);
    final h = _Harness(device);
    h.optOut.optedOut.add('u1');
    expect((await h.setting())?.enabled, isFalse);

    await h.container.read(pushSettingProvider.notifier).set(on: true);

    expect(device.permissionRequests, 1);
    final setting = h.container.read(pushSettingProvider).valueOrNull;
    expect(setting?.enabled, isTrue);
    expect(setting?.blocked, isFalse);
    expect(h.server.registrations, hasLength(1));
  });

  test('turning it off forgets the phone and asks nothing', () async {
    final device = FakePushDevice(permitted: true);
    final h = _Harness(device);
    await h.setting();

    await h.container.read(pushSettingProvider.notifier).set(on: false);

    expect(device.permissionRequests, 0);
    expect(h.server.forgets, hasLength(1));
    expect(h.container.read(pushSettingProvider).valueOrNull?.enabled, isFalse);
  });
}

final class _Harness {
  _Harness(this.device) {
    final api = ApiClient(adapter: server, logPrint: (_) {});
    addTearDown(api.close);
    container = ProviderContainer(
      overrides: [
        pushDeviceProvider.overrideWithValue(device),
        pushOptOutStoreProvider.overrideWithValue(optOut),
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_SignedIn.new),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakePushDevice device;
  final server = DeviceApi();
  final optOut = MemoryPushOptOut();
  late final ProviderContainer container;

  Future<PushSetting?> setting() async {
    container.listen(pushSettingProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    return container.read(pushSettingProvider.future);
  }
}

final class _SignedIn extends AuthController {
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
