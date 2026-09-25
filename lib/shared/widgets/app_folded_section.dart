import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// A group of fields that starts closed.
///
/// Used where the fields inside are real but rarely the reason someone opened
/// the screen — the document numbers, the four the catalogue already filled,
/// the per-item details of a service. Closed is not hidden: the row says what
/// is inside, and it opens in place.
class AppFoldedSection extends StatefulWidget {
  const AppFoldedSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyOpen = false,
    this.icon,
  });

  /// A glyph for what is inside — optional; most folded sections are named
  /// well enough by their title.
  final IconData? icon;

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyOpen;

  @override
  State<AppFoldedSection> createState() => _AppFoldedSectionState();
}

class _AppFoldedSectionState extends State<AppFoldedSection> {
  late bool _open = widget.initiallyOpen;

  @override
  void didUpdateWidget(covariant AppFoldedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A parent that asks for the section to open — a server error on a field
    // inside it — must be obeyed; closing again stays the person's choice.
    if (widget.initiallyOpen && !oldWidget.initiallyOpen) {
      _open = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: widget.subtitle == null
              ? widget.title
              : '${widget.title}. ${widget.subtitle}',
          excludeSemantics: true,
          onTap: () => setState(() => _open = !_open),
          child: AppSurface(
            variant: AppSurfaceVariant.grouped,
            onTap: () => setState(() => _open = !_open),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.inset,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  AppIconWell(icon: widget.icon!),
                  const SizedBox(width: AppSpacing.s12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.titleSmall),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: AppMotion.of(context, AppMotion.short),
                  curve: AppMotion.standard,
                  child: Icon(
                    Icons.expand_more,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.medium),
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  ),
                ),
        ),
      ],
    );
  }
}
