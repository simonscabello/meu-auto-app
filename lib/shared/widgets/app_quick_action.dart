import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_pressable.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// One of the named things a person opens the app to do.
///
/// Every quick action is the same tile — same card, same glyph in the accent,
/// same label — so two of them side by side weigh exactly the same. Which one
/// matters more is not a question the tile answers.
///
/// It is a card and not a button on purpose: a filled accent button would
/// make one of the two the screen's main action, and a text link would make
/// both look optional. It is short — the old tile was 135dp tall with a
/// circled icon and a chevron, and two of them outweighed the mileage above
/// them.
///
/// [wide] lays the tile out as one row, for when it stands alone.
class AppQuickAction extends StatelessWidget {
  const AppQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final well = AppIconWell(
      icon: icon,
      size: AppIconWellSize.l,
      tone: AppIconWellTone.accent,
    );

    final content = wide
        ? Row(
            children: [
              well,
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: Text(label, style: labelStyle)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              well,
              const SizedBox(height: AppSpacing.s12),
              Text(
                label,
                style: labelStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        child: AppSurface(
          variant: AppSurfaceVariant.grouped,
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.inset,
            AppSpacing.inset,
            AppSpacing.inset,
            AppSpacing.s16,
          ),
          child: content,
        ),
      ),
    );
  }
}
