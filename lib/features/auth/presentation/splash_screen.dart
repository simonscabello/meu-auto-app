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
      return _SplashFrame(
        below: AppErrorState.fromError(
          error: auth.error!,
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
      );
    }

    final status = auth.valueOrNull;
    if (status is AuthLoggedIn) {
      final vehicles = ref.watch(vehiclesProvider);
      if (vehicles.hasError && !(vehicles.valueOrNull?.available ?? false)) {
        return _SplashFrame(
          below: AppErrorState.fromError(
            error: vehicles.error!,
            onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
          ),
        );
      }
    }

    return const _SplashFrame(
      below: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _SplashFrame extends StatelessWidget {
  const _SplashFrame({required this.below});

  /// The spinner while waiting, or the error when waiting failed.
  final Widget below;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
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
      ),
    );
  }
}
