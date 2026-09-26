import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// Opens a bottom sheet the way every sheet in the app opens.
///
/// Two kinds exist and the difference is one flag. A *picker* — choose a
/// vehicle, choose a record type — closes by dragging and shows a handle. A
/// *form* does not: a swipe near the top of a sheet full of fields is an
/// easy accident, and a drag-to-close bypasses every discard guard. Form
/// sheets close through [AppSheetHeader], which asks first.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isForm = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Over the whole app, tab bar included: a sheet opened from a tab used to
    // slide up between the page and the bar, which stayed lit and tappable
    // beside the scrim.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: !isForm,
    enableDrag: !isForm,
    builder: (sheetContext) => _SystemBarInset(child: builder(sheetContext)),
  );
}

/// Keeps a sheet's last widget above the phone's navigation bar.
///
/// `useSafeArea` guards only the top and the sides of a modal sheet; the
/// bottom is left to the content. With the app drawn edge to edge (target
/// SDK 35+), the three-button bar covered whatever a sheet ended with, and
/// on "Editar abastecimento" that was "Salvar". The inset is applied here,
/// inside the sheet's own surface so its colour runs behind the bar, and
/// removed from the [MediaQuery] below so nothing inside pads for it twice.
/// With the keyboard up the padding is already zero: the keyboard's inset
/// covers the bar, and [AppSheetBody] lifts above that.
///
/// It keeps one shape whatever the inset, and that is load-bearing. The
/// padding reaches zero partway up the keyboard's slide, and returning the
/// child bare at zero changed the tree above the whole form: Flutter built
/// the sheet again from scratch, the field lost its focus and the keyboard
/// went straight back down, so no sheet could be typed into on a phone with
/// a navigation bar. `sheet_insets_test` walks the keyboard up and down.
class _SystemBarInset extends StatelessWidget {
  const _SystemBarInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: child,
      ),
    );
  }
}

/// The interior of a sheet that fits its content: side gutters, room for the
/// keyboard, and a scroll once the content stops fitting.
///
/// Every sheet used to pad itself, and they disagreed by four to eight
/// pixels in every direction. One shape here means a sheet is recognisable
/// as a Meu Auto sheet before a word is read.
class AppSheetBody extends StatelessWidget {
  const AppSheetBody({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.page,
        right: AppSpacing.page,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        ),
      ),
    );
  }
}

/// The interior of a sheet that holds a list: a fixed height, a header, and
/// a body that scrolls on its own.
///
/// For the pickers — catalogue items, brands, models — where the list is
/// long and the sheet has to be tall enough to search inside. The height is
/// a share of what is left once the system bars are taken out, so the frame
/// plus the navigation-bar inset never asks for more than the screen.
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    required this.child,
    this.heightFactor = 0.86,
  });

  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height =
        (media.size.height - media.viewPadding.vertical) * heightFactor;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.s16,
        ),
        child: child,
      ),
    );
  }
}
