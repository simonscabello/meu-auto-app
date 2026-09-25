import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

/// The head of a detail screen: what this is, and how it is.
///
/// **No box and no icon.** The title holds the screen by its size alone, and
/// the hierarchy against the blocks below comes from size and space. The app
/// bar already says what kind of thing this is ("Manutenção", "IPVA"); the
/// header says which one — "Troca de óleo do motor", "IPVA 2026" — and, when
/// it has a state, the badge and the sentence that says it in words.
///
/// One shape for a plan, an IPVA, a policy, a service and a fill, so the
/// person knows where to look before reading.
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.status,
    this.statusLabel,
    this.phrase,
  });

  final String title;

  /// One quiet line under the title, when the title alone is not enough — the
  /// insurer under "Seguro", the workshop under a service.
  final String? subtitle;

  /// The state, as a badge. Null for an object with no state — a fill.
  final AppStatus? status;

  /// Replaces the badge's word.
  final String? statusLabel;

  /// The state in words: "Venceu há 12 dias", "Pago com 3 dias de atraso".
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
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
              if (status != null)
                AppStatusChip(status: status!, label: statusLabel),
              if (hasPhrase)
                Text(
                  phrase!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: loud ? visual!.foreground : scheme.onSurfaceVariant,
                    fontWeight: loud ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
