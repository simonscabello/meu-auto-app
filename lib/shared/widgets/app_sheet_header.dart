import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';

/// The top of a bottom sheet: its title, an optional line under it, and a
/// way out.
///
/// Form sheets do not close by dragging. A downward swipe near the top of a
/// sheet full of fields is an easy accident, and it bypassed every guard —
/// `Navigator.pop` does not ask a `PopScope` — so a price and a litre count
/// typed at the pump vanished without a word. The close button asks through
/// [AppDiscardGuard] like the back button does; tapping outside does too.
///
/// Pair it with `enableDrag: false, showDragHandle: false` on the sheet, or
/// open the sheet with `showAppSheet(isForm: true)`, which does that.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.closable = true,
    this.trailing,
  });

  /// A link at the end of the title line — "Histórico" on the mileage sheet.
  /// Takes the close button's place when there is one.
  final Widget? trailing;

  final String title;
  final String? subtitle;

  /// Whether the header carries the close button. A picker that closes by
  /// dragging has a handle instead.
  final bool closable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: closable ? AppSpacing.s12 : 0,
        bottom: AppSpacing.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: closable ? AppSpacing.s8 : 0),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (closable)
            AppIconButton(
              label: 'Fechar',
              icon: Icons.close,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }
}
