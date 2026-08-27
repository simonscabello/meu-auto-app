import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

class AuthFormBanner extends StatelessWidget {
  const AuthFormBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
