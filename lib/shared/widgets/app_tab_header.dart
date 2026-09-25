import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

/// The top of a main tab: a large title, the car it is about, and the tab's
/// own actions.
///
/// **Every tab opens the same way.** The tabs used to be Material app bars
/// with the title 12dp left of the content under it and the car in small
/// accent type squeezed beneath; changing tab looked like changing app. Now
/// the header is part of the page — on the same gutter as everything below,
/// scrolling with it, so pull-to-refresh starts at the very top — and only
/// the [title] changes from tab to tab.
///
/// The [contextLabel] line is the car. It is in the accent because it is
/// something to press (it opens the switcher) and because it is about the
/// person's own things — the two jobs the accent has in this app.
class AppTabHeader extends StatelessWidget {
  const AppTabHeader({
    super.key,
    required this.title,
    this.contextLabel,
    this.onContextTap,
    this.contextSemanticLabel,
    this.actions = const [],
  });

  final String title;

  /// Which car the tab is about: "Prius · QAF5G33".
  final String? contextLabel;

  /// Opens the vehicle switcher. Null leaves the line as plain text.
  final VoidCallback? onContextTap;

  final String? contextSemanticLabel;

  /// Icon buttons and the account button, at the end of the title's line.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final tappable = onContextTap != null;
    final contextColor = tappable ? scheme.primary : scheme.onSurfaceVariant;

    Widget? contextLine;
    if (contextLabel != null) {
      contextLine = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 16, color: contextColor),
          const SizedBox(width: AppSpacing.s4),
          Flexible(
            child: Text(
              contextLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: contextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (tappable) ...[
            const SizedBox(width: AppSpacing.s4),
            Icon(Icons.unfold_more, size: 18, color: contextColor),
          ],
        ],
      );
      if (tappable) {
        contextLine = Semantics(
          // Its own node: next to a heading it would otherwise merge into
          // one announcement with it.
          container: true,
          button: true,
          label: contextSemanticLabel ?? '$contextLabel. Trocar veículo',
          excludeSemantics: true,
          onTap: onContextTap,
          child: InkWell(
            onTap: onContextTap,
            borderRadius: AppRadius.borderS,
            highlightColor: tones.overlayPressed,
            splashColor: tones.overlayPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTapTarget,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: contextLine,
              ),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s16,
        AppSpacing.page - AppSpacing.targetOverhang,
        AppSpacing.s16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s4),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
                if (contextLine != null) ...[
                  const SizedBox(height: 2),
                  contextLine,
                ],
              ],
            ),
          ),
          for (final action in actions) action,
        ],
      ),
    );
  }
}
