import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/router/app_router.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/biometric_copy.dart';
import 'package:meu_auto/features/auth/presentation/unlock_screen.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_wordmark.dart';

import '../../../support/biometric_fakes.dart';

/// With a stored session and the lock on, the background of the prompt is
/// the unlock screen — the splash, in effect — and not the sign-in form,
/// which made it look as if the app had signed the owner out.
void main() {
  testWidgets('a locked session opens the unlock screen and asks at once', (
    tester,
  ) async {
    final app = await _pumpApp(tester, [UnlockResult.notConfirmed]);

    expect(app.auth.unlocks, 1);
    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.byType(AppWordmark), findsOneWidget);
    // No form behind the prompt.
    expect(find.widgetWithText(TextField, 'E-mail'), findsNothing);
    // Dismissed, the two ways in appear.
    expect(find.text(BiometricCopy.unlockAsk), findsOneWidget);
    final biometric = tester.widget<AppButton>(
      find.widgetWithText(AppButton, BiometricCopy.unlockButton),
    );
    expect(biometric.variant, AppButtonVariant.primary);
    expect(
      tester
          .widget<AppButton>(
            find.widgetWithText(AppButton, BiometricCopy.usePassword),
          )
          .variant,
      AppButtonVariant.tertiary,
    );
  });

  testWidgets('while the prompt is up, it is the splash: same mark, same '
      'place, nothing to tap', (tester) async {
    final hold = Completer<void>();
    final app = await _pumpApp(
      tester,
      [UnlockResult.notConfirmed],
      hold: hold,
      settle: false,
    );
    // The first frame is the splash, while the session is being read.
    final onSplash = tester.getRect(find.byType(AppWordmark));

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(app.auth.unlocks, 1);
    expect(tester.getRect(find.byType(AppWordmark)), onSplash);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);

    hold.complete();
    await tester.pumpAndSettle();
    expect(find.text(BiometricCopy.unlockButton), findsOneWidget);
  });

  testWidgets('the biometric button asks again', (tester) async {
    final app = await _pumpApp(tester, [UnlockResult.notConfirmed]);

    await tester.tap(find.text(BiometricCopy.unlockButton));
    await tester.pumpAndSettle();

    expect(app.auth.unlocks, 2);
  });

  testWidgets('"Usar e-mail e senha" opens the sign-in without asking again, '
      'and the sign-in keeps offering the biometric', (tester) async {
    final app = await _pumpApp(tester, [UnlockResult.notConfirmed]);

    await tester.tap(find.text(BiometricCopy.usePassword));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(app.auth.unlocks, 1);
    final biometric = tester.widget<AppButton>(
      find.widgetWithText(AppButton, BiometricCopy.unlockButton),
    );
    // "Entrar" stays the one filled button on the sign-in screen.
    expect(biometric.variant, AppButtonVariant.secondary);
  });

  testWidgets('no answer from the server: it says so and stays', (
    tester,
  ) async {
    await _pumpApp(tester, [UnlockResult.unreachable]);

    expect(find.text(BiometricCopy.unreachable), findsOneWidget);
    expect(find.text(BiometricCopy.unlockAsk), findsNothing);
    expect(find.widgetWithText(TextField, 'E-mail'), findsNothing);
  });

  testWidgets('a lockout says why the button would do nothing', (tester) async {
    await _pumpApp(tester, [UnlockResult.lockedOut]);

    expect(find.text(BiometricCopy.lockedOut), findsOneWidget);
  });

  testWidgets('an expired session goes to the sign-in, with the reason', (
    tester,
  ) async {
    await _pumpApp(tester, [UnlockResult.expired]);

    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(find.text(BiometricCopy.expired), findsOneWidget);
    // Signed out now: there is no session left for the biometric to open.
    expect(find.text(BiometricCopy.unlockButton), findsNothing);
  });

  testWidgets('with the biometrics gone, it goes to the password and asks '
      'nothing', (tester) async {
    final app = await _pumpApp(tester, [
      UnlockResult.notConfirmed,
    ], available: false);

    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(app.auth.unlocks, 0);
    expect(find.text(BiometricCopy.unlockButton), findsNothing);
  });

  testWidgets('a successful unlock never flashes the buttons on its way out', (
    tester,
  ) async {
    await _pumpApp(tester, [UnlockResult.unlocked], settle: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

final class _App {
  _App(this.auth);

  final _LockedAuthController auth;
}

Future<_App> _pumpApp(
  WidgetTester tester,
  List<UnlockResult> results, {
  bool available = true,
  Completer<void>? hold,
  bool settle = true,
}) async {
  final auth = _LockedAuthController(results, hold: hold);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        deviceBiometricsProvider.overrideWithValue(
          FakeBiometrics(available: available),
        ),
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: ref.watch(appRouterProvider),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return _App(auth);
}

/// Locked from the start, and answering unlock attempts from a script — as
/// the real controller does, a refused session signs out.
final class _LockedAuthController extends AuthController {
  _LockedAuthController(List<UnlockResult> results, {this.hold})
    : _results = [...results];

  final List<UnlockResult> _results;
  final Completer<void>? hold;
  int unlocks = 0;

  @override
  Future<AuthStatus> build() async => const AuthLocked();

  @override
  Future<UnlockResult> unlock() async {
    unlocks++;
    final gate = hold;
    if (gate != null) await gate.future;
    final result = _results.length > 1 ? _results.removeAt(0) : _results.single;
    if (result == UnlockResult.expired) {
      state = const AsyncData(AuthLoggedOut());
    }
    return result;
  }
}
