import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
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
/// with no bar colour of its own — and only the [title] changes from tab to
/// tab. It stays in place while the tab scrolls, so the "+" and the car are
/// always one tap away; [AppTabBody] draws the hairline that separates the
/// two once something has scrolled under it.
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
                    // Scaled down, never cut: at a 1.6 text scale "Manuten…"
                    // beside the "+" and the avatar was not a title.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: theme.textTheme.headlineMedium,
                      ),
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

/// The scrolling part of a main tab, under an [AppTabHeader].
///
/// At rest the header and the page are one surface. Once the list has moved,
/// a hairline appears where the two meet — the same cue a Material app bar
/// gives when content scrolls under it — so a row cut in half by the header
/// reads as scrolled away, not as drawn over.
class AppTabBody extends StatefulWidget {
  const AppTabBody({super.key, required this.child});

  final Widget child;

  @override
  State<AppTabBody> createState() => _AppTabBodyState();
}

class _AppTabBodyState extends State<AppTabBody> {
  var _scrolledUnder = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final under = notification.metrics.pixels > 0;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _scrolledUnder ? 1 : 0,
              duration: AppMotion.short,
              child: Divider(height: 1, thickness: 1, color: tones.stroke),
            ),
          ),
        ),
      ],
    );
  }
}
