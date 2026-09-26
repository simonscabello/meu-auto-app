import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/application/biometric_setting.dart';
import 'package:meu_auto/features/auth/data/biometric_lock_store.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';

import '../../../support/biometric_fakes.dart';

/// The rule that does not bend: **the biometric releases the session already
/// stored on the phone; it never stores or replays a password.**
///
/// ```
/// password sign-in → session stored → the owner turns the lock on
/// next opening:     locked → biometric → /me (refreshing if it must) → app
/// never:            biometric → saved password → /auth/login
/// ```
void main() {
  group('opening the app', () {
    test('a stored session with the lock on stops at the lock, before any '
        'network', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');

      expect(await h.status(), isA<AuthLocked>());
      expect(
        h.server.meCalls,
        0,
        reason: 'the prompt comes before the network',
      );
      expect(h.biometrics.prompts, 0, reason: 'the screen asks, not bootstrap');
    });

    test('without the lock the session opens as it always did', () async {
      final h = await _Harness.create(stored: testTokens());

      expect(await h.status(), isA<AuthLoggedIn>());
    });

    test('a lock with no session behind it opens nothing', () async {
      final h = await _Harness.create(enrolled: 'u1');

      expect(await h.status(), isA<AuthLoggedOut>());
    });
  });

  group('unlocking', () {
    test('a confirmed biometric opens the stored session', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
      await h.status();

      expect(await h.auth.unlock(), UnlockResult.unlocked);
      final status = h.current();
      expect(status, isA<AuthLoggedIn>());
      expect((status as AuthLoggedIn).user.id, 'u1');
      expect((await h.tokens.read())?.refreshToken, 'stored-refresh');
    });

    test(
      'a dismissed prompt stays locked and asks nothing of the server',
      () async {
        final h = await _Harness.create(
          stored: testTokens(),
          enrolled: 'u1',
          biometrics: FakeBiometrics(checks: [BiometricCheck.notConfirmed]),
        );
        await h.status();

        expect(await h.auth.unlock(), UnlockResult.notConfirmed);
        expect(h.current(), isA<AuthLocked>());
        expect(h.server.meCalls, 0);
        expect(await h.tokens.read(), isNotNull);
      },
    );

    test('a lockout says so, and stays locked', () async {
      final h = await _Harness.create(
        stored: testTokens(),
        enrolled: 'u1',
        biometrics: FakeBiometrics(checks: [BiometricCheck.lockedOut]),
      );
      await h.status();

      expect(await h.auth.unlock(), UnlockResult.lockedOut);
      expect(h.current(), isA<AuthLocked>());
    });

    test(
      'no answer from the server keeps the session for the next try',
      () async {
        final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
        await h.status();
        h.server.meAnswer = MeAnswer.offline;

        expect(await h.auth.unlock(), UnlockResult.unreachable);
        expect(h.current(), isA<AuthLocked>());
        expect(await h.tokens.read(), isNotNull, reason: 'it was never spent');

        h.server.meAnswer = MeAnswer.ok;
        expect(await h.auth.unlock(), UnlockResult.unlocked);
      },
    );

    test(
      'a refused session ends, and the lock waits for the same owner',
      () async {
        final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
        await h.status();
        h.server.meAnswer = MeAnswer.unauthorized;

        expect(await h.auth.unlock(), UnlockResult.expired);
        expect(h.current(), isA<AuthLoggedOut>());
        expect(await h.tokens.read(), isNull);
        // The same person signs in again with the password and finds the lock
        // still on; anyone else signing in turns it off.
        expect(await h.lock.enrolledUserId(), 'u1');
      },
    );

    test('a session that belongs to another account never opens', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
      await h.status();
      h.server.me = testUser(id: 'u2', name: 'Bia');

      expect(await h.auth.unlock(), UnlockResult.expired);
      expect(h.current(), isA<AuthLoggedOut>());
      expect(await h.tokens.read(), isNull);
    });
  });

  group('signing in with the password', () {
    test(
      'from the lock, the waiting session is revoked, not overwritten',
      () async {
        final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
        await h.status();

        await h.auth.login(email: 'ana@example.com', password: 'segredo123');
        await pumpEventQueue();

        expect(h.server.revoked, ['stored-refresh']);
        expect((await h.tokens.read())?.refreshToken, 'new-refresh-1');
        expect(h.current(), isA<AuthLoggedIn>());
        expect(await h.lock.enrolledUserId(), 'u1', reason: 'same owner');
      },
    );

    test('another account turns the lock off', () async {
      final h = await _Harness.create(
        stored: testTokens(),
        enrolled: 'u1',
        server: FakeAuthServer(
          signsIn: testUser(id: 'u2', name: 'Bia'),
        ),
      );
      await h.status();

      await h.auth.login(email: 'bia@example.com', password: 'segredo123');

      expect(await h.lock.enrolledUserId(), isNull);
    });

    test('a phone whose biometrics are gone turns the lock off', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
      await h.status();
      h.biometrics.available = false;

      await h.auth.login(email: 'ana@example.com', password: 'segredo123');

      expect(
        await h.lock.enrolledUserId(),
        isNull,
        reason: 'the lock could only ever send the owner to the password',
      );
    });

    test('a signed-out phone has nothing to revoke', () async {
      final h = await _Harness.create();
      await h.status();

      await h.auth.login(email: 'ana@example.com', password: 'segredo123');
      await pumpEventQueue();

      expect(h.server.revoked, isEmpty);
    });

    test('registering from the lock revokes the waiting session too', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
      await h.status();

      await h.auth.register(
        name: 'Ana',
        email: 'ana2@example.com',
        password: 'segredo123',
      );
      await pumpEventQueue();

      expect(h.server.revoked, ['stored-refresh']);
    });

    test(
      'the step before entering runs, and cannot stop the sign-in',
      () async {
        final h = await _Harness.create();
        await h.status();
        var asked = 0;

        await h.auth.login(
          email: 'ana@example.com',
          password: 'segredo123',
          beforeEntering: (user) async {
            asked++;
            expect(
              h.current(),
              isA<AuthLoggedOut>(),
              reason: 'still at the door',
            );
            throw StateError('the dialog went away');
          },
        );

        expect(asked, 1);
        expect(h.current(), isA<AuthLoggedIn>());
        expect(await h.tokens.read(), isNotNull);
      },
    );
  });

  group('the invitation', () {
    test('is offered once per account, where the phone can check', () async {
      final h = await _Harness.create();
      final ana = testUser();

      expect(await h.auth.shouldOfferBiometrics(ana), isTrue);
      await h.auth.markBiometricsOffered(ana);
      expect(await h.auth.shouldOfferBiometrics(ana), isFalse);
      expect(
        await h.auth.shouldOfferBiometrics(testUser(id: 'u2', name: 'Bia')),
        isTrue,
      );
    });

    test('is not offered to the account whose lock is already on', () async {
      final h = await _Harness.create(enrolled: 'u1');

      expect(await h.auth.shouldOfferBiometrics(testUser()), isFalse);
    });

    test('is not offered where there is nothing to check', () async {
      final h = await _Harness.create(
        biometrics: FakeBiometrics(available: false),
      );

      expect(await h.auth.shouldOfferBiometrics(testUser()), isFalse);
    });

    test('turning the lock on waits for the phone to confirm', () async {
      final h = await _Harness.create(
        biometrics: FakeBiometrics(
          checks: [BiometricCheck.notConfirmed, BiometricCheck.confirmed],
        ),
      );

      expect(
        await h.auth.enableBiometrics(testUser()),
        BiometricCheck.notConfirmed,
      );
      expect(await h.lock.enrolledUserId(), isNull);

      expect(
        await h.auth.enableBiometrics(testUser()),
        BiometricCheck.confirmed,
      );
      expect(await h.lock.enrolledUserId(), 'u1');
    });
  });

  group('leaving', () {
    test('"Sair" forgets the lock', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
      await h.status();
      await h.auth.unlock();

      await h.auth.logout();

      expect(await h.lock.enrolledUserId(), isNull);
      expect(h.current(), isA<AuthLoggedOut>());
    });

    test('deleting the account forgets the lock', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
      await h.status();
      await h.auth.unlock();

      await h.auth.deleteAccount(password: 'segredo123');

      expect(await h.lock.enrolledUserId(), isNull);
    });

    test('a password reset keeps it: the same owner signs in next', () async {
      final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
      await h.status();

      await h.auth.clearLocalSession();

      expect(await h.lock.enrolledUserId(), 'u1');
      expect(await h.tokens.read(), isNull);
    });
  });

  group('Perfil', () {
    test('has no switch where the phone cannot check', () async {
      final h = await _Harness.create(
        stored: testTokens(),
        biometrics: FakeBiometrics(available: false),
      );
      await h.status();

      expect(await h.setting(), isNull);
    });

    test(
      'the switch follows the account; turning it off asks nothing',
      () async {
        final h = await _Harness.create(stored: testTokens(), enrolled: 'u1');
        await h.status();
        await h.auth.unlock();
        final promptsBefore = h.biometrics.prompts;

        expect(await h.setting(), isTrue);
        await h.container
            .read(biometricSettingProvider.notifier)
            .set(on: false);

        expect(h.container.read(biometricSettingProvider).valueOrNull, isFalse);
        expect(await h.lock.enrolledUserId(), isNull);
        expect(h.biometrics.prompts, promptsBefore);
      },
    );

    test('turning it on stays off until the phone confirms', () async {
      final h = await _Harness.create(
        stored: testTokens(),
        biometrics: FakeBiometrics(
          checks: [BiometricCheck.notConfirmed, BiometricCheck.confirmed],
        ),
      );
      await h.status();
      expect(await h.setting(), isFalse);
      final notifier = h.container.read(biometricSettingProvider.notifier);

      expect(await notifier.set(on: true), BiometricCheck.notConfirmed);
      expect(h.container.read(biometricSettingProvider).valueOrNull, isFalse);

      expect(await notifier.set(on: true), BiometricCheck.confirmed);
      expect(h.container.read(biometricSettingProvider).valueOrNull, isTrue);
      expect(await h.lock.enrolledUserId(), 'u1');
    });
  });
}

final class _Harness {
  _Harness._(this.tokens, this.lock, this.biometrics, this.server, this.api)
    : container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(api),
          deviceBiometricsProvider.overrideWithValue(biometrics),
          biometricLockStoreProvider.overrideWithValue(lock),
        ],
      );

  static Future<_Harness> create({
    SessionTokens? stored,
    String? enrolled,
    FakeBiometrics? biometrics,
    FakeAuthServer? server,
  }) async {
    final tokens = TokenStorage.memory();
    if (stored != null) await tokens.save(stored);
    final fake = server ?? FakeAuthServer();
    final api = ApiClient(adapter: fake, logPrint: (_) {});
    final h = _Harness._(
      tokens,
      MemoryBiometricLockStore(enrolled: enrolled),
      biometrics ?? FakeBiometrics(),
      fake,
      api,
    );
    addTearDown(h.container.dispose);
    addTearDown(api.close);
    return h;
  }

  final TokenStorage tokens;
  final MemoryBiometricLockStore lock;
  final FakeBiometrics biometrics;
  final FakeAuthServer server;
  final ApiClient api;
  final ProviderContainer container;

  AuthController get auth => container.read(authControllerProvider.notifier);

  Future<AuthStatus> status() => container.read(authControllerProvider.future);

  AuthStatus? current() => container.read(authControllerProvider).valueOrNull;

  Future<bool?> setting() {
    container.listen(biometricSettingProvider, (_, _) {});
    return container.read(biometricSettingProvider.future);
  }
}
