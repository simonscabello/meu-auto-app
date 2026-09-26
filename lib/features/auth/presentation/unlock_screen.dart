import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/application/login_notice.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/biometric_copy.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/splash_screen.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

/// The background of the biometric prompt, while a stored session is locked.
///
/// **It exists because a sign-in form behind the prompt looks like a bug.**
/// Pauta, where this flow comes from, first opened the prompt over the e-mail
/// and password form, and someone who had just opened the app read it as "I
/// was signed out". Here the background is the splash itself — the same mark
/// in the same place over the same spinner — so opening the app, touching the
/// sensor and landing on Início reads as one sequence.
///
/// The prompt opens by itself. Dismissed, the screen offers the two ways in:
/// the biometric again, or the password, whose screen keeps offering the
/// biometric for as long as the session stays locked.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  /// Starts true: until the prompt is up this is the splash, with no button
  /// that would flash for an instant and vanish under the dialog.
  bool _unlocking = true;

  /// Why the last attempt did not get in, when there is something to say. A
  /// dismissed prompt says nothing — the owner knows what they did.
  String? _problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    final available = await ref.read(deviceBiometricsProvider).isAvailable();
    if (!mounted) return;
    if (!available) {
      // The biometrics were removed after the lock was turned on, so there
      // is nothing to ask for. The password gets in, and signing in with it
      // turns the lock off.
      context.go(AppRoutes.login);
      return;
    }
    await _unlock();
  }

  Future<void> _unlock() async {
    setState(() {
      _unlocking = true;
      _problem = null;
    });
    // Read before the await: when the session turns out to be gone, the
    // router takes this screen down before the answer comes back.
    final problem = ref.read(loginProblemProvider.notifier);
    final result = await ref.read(authControllerProvider.notifier).unlock();
    switch (result) {
      case UnlockResult.unlocked:
        // The router is already on its way to Início; the spinner stays.
        return;
      case UnlockResult.expired:
        // The session is gone and the router is taking the owner to the
        // password. The reason goes with them, or it looks as if the app
        // signed them out on its own.
        problem.state = BiometricCopy.expired;
        return;
      case UnlockResult.notConfirmed:
      case UnlockResult.lockedOut:
      case UnlockResult.unreachable:
        break;
    }
    if (!mounted) return;
    setState(() {
      _unlocking = false;
      _problem = switch (result) {
        UnlockResult.lockedOut => BiometricCopy.lockedOut,
        UnlockResult.unreachable => BiometricCopy.unreachable,
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SplashFrame(
              // Only the height moves: the spinner's slot is as wide as the
              // buttons that replace it, so they grow down from under the
              // mark instead of out of a point.
              below: AnimatedSize(
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.enter,
                alignment: Alignment.topCenter,
                child: _unlocking
                    ? const SizedBox(
                        width: double.infinity,
                        child: Center(child: SplashFrame.spinner),
                      )
                    : _WaysIn(
                        problem: _problem,
                        onBiometric: () => unawaited(_unlock()),
                        onPassword: () => context.go(AppRoutes.login),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the unlock screen offers once the prompt is gone: the biometric
/// again, filled, and the password as the way around it.
class _WaysIn extends StatelessWidget {
  const _WaysIn({
    required this.problem,
    required this.onBiometric,
    required this.onPassword,
  });

  final String? problem;
  final VoidCallback onBiometric;
  final VoidCallback onPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (problem != null)
            AuthFormBanner(message: problem!)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s24),
              child: Text(
                BiometricCopy.unlockAsk,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          AppButton(
            label: BiometricCopy.unlockButton,
            icon: Icons.fingerprint,
            expanded: true,
            onPressed: onBiometric,
          ),
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: BiometricCopy.usePassword,
            variant: AppButtonVariant.tertiary,
            onPressed: onPassword,
          ),
        ],
      ),
    );
  }
}
