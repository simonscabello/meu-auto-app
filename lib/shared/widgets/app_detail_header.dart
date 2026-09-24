import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

/// The head of a detail screen: what this is, and how it is.
///
/// A large well with the object's glyph, the title, and — when the object
/// has a state — the status pill and the sentence that says it in words.
/// One shape for a plan, an IPVA, a policy and a fill, so the person knows
/// where to look before reading.
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.status,
    this.phrase,
  });

  final IconData icon;
  final String title;

  /// One quiet line under the title, when the title alone is not enough.
  final String? subtitle;

  /// The state, as a pill. Null for an object with no state — a fill.
  final AppStatus? status;

  /// The state in words: "venceu há 12 dias", "pago com 3 dias de atraso".
  final String? phrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loud = status?.isLoud ?? false;
    final visual = status == null
        ? null
        : statusColors(status!, theme.brightness);
    final hasPhrase = phrase != null && phrase!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconWell(
            icon: icon,
            size: AppIconWellSize.l,
            tone: loud ? AppIconWellTone.status : AppIconWellTone.neutral,
            status: status,
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.headlineSmall),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (status != null || hasPhrase) ...[
                  const SizedBox(height: AppSpacing.s12),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s12,
                    runSpacing: AppSpacing.s8,
                    children: [
                      if (status != null) AppStatusChip(status: status!),
                      if (hasPhrase)
                        Text(
                          phrase!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: loud
                                ? visual!.foreground
                                : scheme.onSurfaceVariant,
                            fontWeight: loud
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
