import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final handlePress = loading ? null : onPressed;
    final child = _ButtonLabel(label: label, loading: loading);

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: handlePress,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: handlePress,
        child: child,
      ),
      AppButtonVariant.destructive => FilledButton(
        onPressed: handlePress,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          disabledBackgroundColor: scheme.error.withValues(alpha: 0.38),
          disabledForegroundColor: scheme.onError.withValues(alpha: 0.38),
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
        ),
        child: child,
      ),
    };
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.loading});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: loading ? 0 : 1, child: Text(label)),
        if (loading)
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            ),
          ),
      ],
    );
  }
}
