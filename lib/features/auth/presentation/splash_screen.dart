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
/// Sits on the same page as everything else, so the hand-off from the native
/// splash is one screen gaining content, not two screens.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.hasError) {
      return AppScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppWordmark(),
                const SizedBox(height: AppSpacing.s24),
                AppErrorState.fromError(
                  error: auth.error!,
                  onRetry: () => ref.invalidate(authControllerProvider),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final status = auth.valueOrNull;
    if (status is AuthLoggedIn) {
      final vehicles = ref.watch(vehiclesProvider);
      if (vehicles.hasError && !(vehicles.valueOrNull?.available ?? false)) {
        return AppScaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppWordmark(),
                  const SizedBox(height: AppSpacing.s24),
                  AppErrorState.fromError(
                    error: vehicles.error!,
                    onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return const AppScaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: _AppName(showSpinner: true),
        ),
      ),
    );
  }
}

class _AppName extends StatelessWidget {
  const _AppName({required this.showSpinner});

  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppWordmark(size: AppWordmarkSize.large),
        if (showSpinner) ...[
          const SizedBox(height: AppSpacing.s32),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ],
    );
  }
}
