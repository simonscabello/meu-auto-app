import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_pressable.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// One of the named things a person opens the app to do.
///
/// Every quick action is the same tile — same surface, same well, same
/// label size, same chevron — so two of them side by side have exactly the
/// same weight. Which one is more important is not a question the tile
/// answers; the order does.
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
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontSize: 15,
      color: scheme.onSurface,
    );
    final chevron = Icon(Icons.chevron_right, size: 20, color: scheme.outline);
    final well = AppIconWell(
      icon: icon,
      size: AppIconWellSize.l,
      color: scheme.primary,
    );

    final content = wide
        ? Row(
            children: [
              well,
              const SizedBox(width: AppSpacing.s16),
              Expanded(child: Text(label, style: labelStyle)),
              chevron,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [well, const Spacer(), chevron]),
              const SizedBox(height: AppSpacing.s16),
              Text(
                label,
                style: labelStyle,
                maxLines: 3,
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
          variant: AppSurfaceVariant.raised,
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: content,
        ),
      ),
    );
  }
}
