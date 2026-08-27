import 'package:flutter/material.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                offline ? Icons.wifi_off : Icons.error_outline,
                size: 32,
                color: offline
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
              if (offline) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  offlineTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.s12),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
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
              AppButton(label: 'Tentar de novo', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
