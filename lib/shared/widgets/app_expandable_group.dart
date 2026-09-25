import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// A group that needs nothing from anyone right now: present, countable,
/// folded — "Em dia 12".
///
/// Closed, it is one card holding one line: the name, how many, and the fold
/// glyph. Open, the same card grows its rows under that line. Folding
/// something away therefore never changes what it looks like — it is the
/// same card, shorter — and a screen with two folded groups reads as two
/// objects instead of two loose labels floating between cards.
class AppExpandableGroup extends StatefulWidget {
  const AppExpandableGroup({
    super.key,
    required this.title,
    required this.children,
    this.count,
    this.explanation,
    this.initiallyOpen = false,
    this.dividerIndent = AppGroup.iconIndent,
  });

  final String title;

  /// Shown after the title. Only worth it above one: "Em dia 1" is noise
  /// where "Em dia 12" is the reason not to open it.
  final int? count;

  /// One quiet line at the top of the open card — what these rows are.
  final String? explanation;

  final List<Widget> children;
  final bool initiallyOpen;
  final double dividerIndent;

  @override
  State<AppExpandableGroup> createState() => _AppExpandableGroupState();
}

class _AppExpandableGroupState extends State<AppExpandableGroup> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final count = widget.count;

    final header = Semantics(
      button: true,
      expanded: _open,
      label: count == null ? widget.title : '${widget.title}, $count itens',
      excludeSemantics: true,
      onTap: () => setState(() => _open = !_open),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          highlightColor: tones.overlayPressed,
          splashColor: tones.overlayPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget + AppSpacing.s8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.inset,
                vertical: AppSpacing.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: widget.title,
                        children: [
                          if (count != null && count > 1)
                            TextSpan(
                              text: '  $count',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
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
        ),
      ),
    );

    return AppSurface(
      variant: AppSurfaceVariant.grouped,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.medium),
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, thickness: 1, color: tones.divider),
                      if (widget.explanation != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.inset,
                            AppSpacing.s12,
                            AppSpacing.inset,
                            AppSpacing.s4,
                          ),
                          child: Text(
                            widget.explanation!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      for (var i = 0; i < widget.children.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.inset,
                            ),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              indent: widget.dividerIndent,
                              color: tones.divider,
                            ),
                          ),
                        frameGroupRow(widget.children[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
