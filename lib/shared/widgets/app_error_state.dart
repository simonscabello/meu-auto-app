import 'package:flutter/material.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_centered_scroll.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';

/// Something did not load: what happened, in words the person can act on,
/// and a way to try again.
///
/// Offline is not an error in the person's eyes — nothing is wrong with the
/// app — so it gets a neutral glyph and its own title. Everything else gets
/// the red well, because red is reserved for something that actually failed.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.requestId,
    this.offline = false,
  });

  factory AppErrorState.fromError({
    Key? key,
    required Object error,
    required VoidCallback onRetry,
  }) {
    if (error is ApiFailure) {
      return AppErrorState(
        key: key,
        message: error.message,
        onRetry: onRetry,
        requestId: error.requestId,
        offline: error.code == ApiErrorCode.semConexao,
      );
    }
    return AppErrorState(
      key: key,
      message: 'Algo deu errado. Tente novamente.',
      onRetry: onRetry,
    );
  }

  static const offlineTitle = 'Sem conexão';

  final String message;
  final VoidCallback onRetry;
  final String? requestId;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = requestId?.trim();
    return AppCenteredScroll(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconWell(
              icon: offline ? Icons.wifi_off_outlined : Icons.error_outline,
              size: AppIconWellSize.xl,
              tone: offline ? AppIconWellTone.neutral : AppIconWellTone.status,
              status: AppStatus.vencido,
            ),
            if (offline) ...[
              const SizedBox(height: AppSpacing.s20),
              Text(
                offlineTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.s12),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: offline
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (reference != null && reference.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Referência: $reference',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.s24),
            AppButton(
              label: 'Tentar de novo',
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
