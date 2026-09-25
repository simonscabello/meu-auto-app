import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// A message about the whole form, above its fields.
///
/// For what a single field cannot say — the server refused the request, the
/// connection dropped, the e-mail is already taken. A soft band in the error
/// tone, shaped like the fields under it: no edge, no stripe down the side,
/// only the fill and the glyph, so it is found at a glance without shouting.
///
/// It is a live region: a screen reader announces it the moment it appears
/// or its message changes, prefixed with "Erro" so it is not mistaken for a
/// hint.
class AuthFormBanner extends StatelessWidget {
  const AuthFormBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Erro: $message',
        excludeSemantics: true,
        child: AppSurface(
          variant: AppSurfaceVariant.sunken,
          color: scheme.errorContainer,
          borderRadius: AppRadius.borderControl,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inset,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: scheme.error),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
