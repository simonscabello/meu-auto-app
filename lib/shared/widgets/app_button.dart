import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

enum AppButtonVariant {
  /// The one thing to do on the screen. Filled in the accent.
  primary,

  /// An alternative of equal weight. Outlined, on a quiet surface.
  secondary,

  /// Removes something. Tonal red, so it is found without shouting.
  destructive,

  /// A way out or a rarer choice. Text in the accent.
  tertiary,
}

/// Every button in the app.
///
/// One height, one radius and one label size across the four variants, so a
/// screen's actions read as a set. [loading] swaps the label for a spinner
/// without changing the width, which stops the layout jumping while a write
/// is in flight.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.foregroundColor,
    this.icon,
    this.expanded = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;

  /// Overrides the label colour. Used by tertiary actions that must read as
  /// destructive without becoming a filled button.
  final Color? foregroundColor;

  /// A leading glyph. Kept small so the label stays the thing that is read.
  final IconData? icon;

  /// Stretches to the width available. Primary actions at the foot of a
  /// form are; a "Ver histórico" beside them is not.
  final bool expanded;

  /// A shorter button for the inside of a row — "Feito" beside a care item,
  /// "Tem sim" beside an item ruled out. The tap target stays 48dp through
  /// the padded hit area; only the drawn height shrinks.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final handlePress = loading ? null : onPressed;
    final child = _ButtonLabel(label: label, loading: loading, icon: icon);
    const tapTarget = Size(AppSpacing.minTapTarget, AppSpacing.minTapTarget);
    final compactStyle = compact
        ? const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(56, 40)),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            ),
            visualDensity: VisualDensity.compact,
          )
        : null;

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: handlePress,
        style: compactStyle,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: handlePress,
        style: compactStyle,
        child: child,
      ),
      AppButtonVariant.destructive => FilledButton(
        onPressed: handlePress,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
          disabledBackgroundColor: scheme.errorContainer.withValues(alpha: 0.4),
          disabledForegroundColor: scheme.onErrorContainer.withValues(
            alpha: 0.5,
          ),
          overlayColor: scheme.onErrorContainer.withValues(alpha: 0.08),
        ).merge(compactStyle),
        child: child,
      ),
      AppButtonVariant.tertiary => TextButton(
        onPressed: handlePress,
        style: TextButton.styleFrom(
          minimumSize: tapTarget,
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: foregroundColor,
          disabledForegroundColor: foregroundColor?.withValues(alpha: 0.38),
        ),
        child: child,
      ),
    };

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.loading, this.icon});

  final String label;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    final content = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.s8),
              Flexible(child: Text(label)),
            ],
          );
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: loading ? 0 : 1, child: content),
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
