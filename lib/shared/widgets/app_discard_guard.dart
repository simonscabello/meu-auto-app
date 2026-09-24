import 'package:flutter/material.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';

/// Asks before back, the iOS edge swipe or the Android back button throws
/// away what someone typed.
///
/// The screens had a `PopScope(canPop: !_isDirty)` of their own, and it almost
/// never fired: `canPop` is read when the widget builds, and typing into a
/// text field does not rebuild the screen. A workshop name, a cost or an
/// insurer typed and then a back swipe went without a word. This widget
/// listens to the fields itself and rebuilds only the `PopScope` when they
/// change, so [isDirty] is asked at the moment it matters.
///
/// [listenable] is every controller whose text counts — `Listenable.merge`
/// them. State held outside a controller (a picked date, a chosen item) is
/// covered by the screen's own `setState`, which rebuilds this widget too.
class AppDiscardGuard extends StatelessWidget {
  const AppDiscardGuard({
    super.key,
    required this.listenable,
    required this.isDirty,
    required this.child,
    this.busy = false,
    this.title = 'Descartar o que você preencheu?',
    this.message = 'O que foi digitado aqui será perdido.',
  });

  final Listenable listenable;
  final bool Function() isDirty;
  final Widget child;

  /// A save in flight: leaving is blocked outright rather than asked about,
  /// because the answer to "descartar?" cannot stop a request already sent.
  final bool busy;

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      child: child,
      builder: (context, child) => PopScope(
        canPop: !busy && !isDirty(),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || busy) return;
          final discard = await confirmAction(
            context,
            title: title,
            message: message,
            cancelLabel: 'Continuar editando',
            confirmLabel: 'Descartar',
            destructive: true,
          );
          if (discard && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: child!,
      ),
    );
  }
}
