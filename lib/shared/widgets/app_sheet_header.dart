import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';

/// The top of a bottom sheet that holds a form: its title and a way out.
///
/// Form sheets do not close by dragging. A downward swipe near the top of a
/// sheet full of fields is an easy accident, and it bypassed every guard —
/// `Navigator.pop` does not ask a `PopScope` — so a price and a litre count
/// typed at the pump vanished without a word. The close button asks through
/// [AppDiscardGuard] like the back button does; tapping outside does too.
///
/// Pair it with `enableDrag: false, showDragHandle: false` on the sheet.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
          ),
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
