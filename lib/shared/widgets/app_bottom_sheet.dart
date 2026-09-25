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
    builder: builder,
  );
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
/// long and the sheet has to be tall enough to search inside.
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
    final height = MediaQuery.sizeOf(context).height * heightFactor;
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
