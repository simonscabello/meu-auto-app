import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/data/biometric_lock_store.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/biometric_copy.dart';
import 'package:meu_auto/features/auth/presentation/login_screen.dart';

import '../../../support/biometric_fakes.dart';

/// The invitation comes once per account, right after a password sign-in —
/// while the sign-in screen is still there to ask — and only where the phone
/// can check a biometric.
void main() {
  testWidgets('after a password sign-in the invitation appears, and '
      'accepting asks the phone', (tester) async {
    final app = await _pumpLogin(tester);

    await _signIn(tester);

    expect(find.text(BiometricCopy.offerTitle), findsOneWidget);
    await tester.tap(find.text(BiometricCopy.offerAccept));
    await _frames(tester);

    expect(app.biometrics.prompts, 1);
    expect(await app.lock.enrolledUserId(), 'u1');
    expect(app.status(), isA<AuthLoggedIn>());
  });

  testWidgets('declining asks nothing, and is not asked again', (tester) async {
    final app = await _pumpLogin(tester);

    await _signIn(tester);
    await tester.tap(find.text(BiometricCopy.offerDecline));
    await _frames(tester);

    expect(app.biometrics.prompts, 0);
    expect(await app.lock.enrolledUserId(), isNull);
    expect(await app.lock.offeredUserId(), 'u1');
    expect(app.status(), isA<AuthLoggedIn>());
  });

  testWidgets('an account already invited signs in without a question', (
    tester,
  ) async {
    final app = await _pumpLogin(tester, offered: 'u1');

    await _signIn(tester);

    expect(find.text(BiometricCopy.offerTitle), findsNothing);
    expect(app.status(), isA<AuthLoggedIn>());
  });

  testWidgets('no invitation where the phone cannot check a biometric', (
    tester,
  ) async {
    final app = await _pumpLogin(tester, available: false);

    await _signIn(tester);

    expect(find.text(BiometricCopy.offerTitle), findsNothing);
    expect(app.status(), isA<AuthLoggedIn>());
  });

  testWidgets('a prompt that fails after accepting says where to try again', (
    tester,
  ) async {
    final app = await _pumpLogin(tester, checks: [BiometricCheck.notConfirmed]);

    await _signIn(tester);
    await tester.tap(find.text(BiometricCopy.offerAccept));
    await _frames(tester);

    expect(find.text(BiometricCopy.notConfirmedLater), findsOneWidget);
    expect(await app.lock.enrolledUserId(), isNull);
    expect(
      app.status(),
      isA<AuthLoggedIn>(),
      reason: 'the owner still gets in',
    );
  });

  testWidgets('signed out, the sign-in offers no biometric: there is no '
      'session for it to open', (tester) async {
    await _pumpLogin(tester);

    expect(find.text(BiometricCopy.unlockButton), findsNothing);
  });
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'E-mail'),
    'ana@example.com',
  );
  await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'segredo123');
  await tester.tap(find.text('Entrar'));
  await _frames(tester);
}

/// After a successful sign-in the button keeps its spinner — in the app the
/// router has moved on by then — so nothing here ever settles.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final class _Login {
  _Login(this.container, this.biometrics, this.lock);

  final ProviderContainer container;
  final FakeBiometrics biometrics;
  final MemoryBiometricLockStore lock;

  AuthStatus? status() => container.read(authControllerProvider).valueOrNull;
}

Future<_Login> _pumpLogin(
  WidgetTester tester, {
  bool available = true,
  List<BiometricCheck> checks = const [BiometricCheck.confirmed],
  String? offered,
}) async {
  final biometrics = FakeBiometrics(available: available, checks: checks);
  final lock = MemoryBiometricLockStore(offered: offered);
  final api = ApiClient(adapter: FakeAuthServer(), logPrint: (_) {});
  addTearDown(api.close);
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
      apiClientProvider.overrideWithValue(api),
      deviceBiometricsProvider.overrideWithValue(biometrics),
      biometricLockStoreProvider.overrideWithValue(lock),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return _Login(container, biometrics, lock);
}
