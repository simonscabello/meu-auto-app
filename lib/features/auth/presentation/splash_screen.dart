import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_wordmark.dart';

/// The mark while the session resolves.
///
/// A plain page — the same flat tone as every other screen, no gradient, no
/// light — with the name set in type at its centre, so the hand-off from the
/// native splash is one screen gaining content, not two screens. When the
/// session or the car list cannot be read, the mark stays and the error
/// takes the place of the spinner.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.hasError) {
      return AppScaffold(
        body: SplashFrame(
          below: AppErrorState.fromError(
            error: auth.error!,
            onRetry: () => ref.invalidate(authControllerProvider),
          ),
        ),
      );
    }

    final status = auth.valueOrNull;
    if (status is AuthLoggedIn) {
      final vehicles = ref.watch(vehiclesProvider);
      if (vehicles.hasError && !(vehicles.valueOrNull?.available ?? false)) {
        return AppScaffold(
          body: SplashFrame(
            below: AppErrorState.fromError(
              error: vehicles.error!,
              onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
            ),
          ),
        );
      }
    }

    return const AppScaffold(body: SplashFrame(below: SplashFrame.spinner));
  }
}

/// The mark at the centre of an empty page, and whatever waits under it.
///
/// Shared with the unlock screen, which must be indistinguishable from this
/// one while the biometric prompt is on its way: the same mark, in the same
/// place, over the same spinner.
class SplashFrame extends StatelessWidget {
  const SplashFrame({super.key, required this.below});

  /// The spinner while waiting, the error when waiting failed, or — on the
  /// unlock screen — the ways in.
  final Widget below;

  static const spinner = SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppWordmark(size: AppWordmarkSize.large),
            const SizedBox(height: AppSpacing.s32),
            below,
          ],
        ),
      ),
    );
  }
}
