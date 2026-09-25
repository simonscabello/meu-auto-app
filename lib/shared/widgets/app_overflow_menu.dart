import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// One entry of an [AppOverflowMenu].
@immutable
class AppMenuAction {
  const AppMenuAction({
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  /// Says what happens — "Excluir abastecimento", never "Excluir" alone on a
  /// screen that holds more than one thing that could be deleted.
  final String label;
  final VoidCallback onSelected;

  /// Painted in the error colour. The confirmation comes after, not here.
  final bool destructive;
}

/// The ⋮ at the end of a detail screen's app bar: where the rare and the
/// destructive actions live.
///
/// A detail screen used to end with two full-width buttons — "Editar" and a
/// red "Excluir" — so the most destructive thing on the screen was also one
/// of the two largest. Editing is now the pencil beside this menu, and
/// deleting is one entry inside it, followed by a confirmation.
class AppOverflowMenu extends StatelessWidget {
  const AppOverflowMenu({super.key, required this.actions, this.tooltip});

  final List<AppMenuAction> actions;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      tooltip: tooltip ?? 'Mais opções',
      icon: const Icon(Icons.more_vert),
      position: PopupMenuPosition.under,
      offset: const Offset(0, AppSpacing.s4),
      onSelected: (index) => actions[index].onSelected(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              actions[i].label,
              style: actions[i].destructive
                  ? TextStyle(color: scheme.error)
                  : null,
            ),
          ),
      ],
    );
  }
}
