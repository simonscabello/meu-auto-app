import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// A message about the whole form, above its fields.
///
/// For what a single field cannot say — the server refused the request, the
/// connection dropped, the e-mail is already taken. A tinted band with the
/// red glyph, so it is found at a glance; it is the only red block the app
/// draws.
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
        liveRegion: true,
        child: AppSurface(
          variant: AppSurfaceVariant.grouped,
          color: scheme.errorContainer,
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.s8),
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
