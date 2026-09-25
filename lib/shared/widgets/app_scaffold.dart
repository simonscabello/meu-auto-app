import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// Every screen's frame: the page, an optional app bar, the body held to a
/// readable width, and pull-to-refresh when the screen can reload.
///
/// Two shapes. A **pushed** screen (a detail, a form) has an app bar with a
/// back arrow and a short title — "Manutenção", "IPVA 2026" — and opens its
/// body with what the object is. A **tab** has no app bar at all: its header
/// is an `AppTabHeader` at the top of the body, so the big title, the car it
/// is about and the account button scroll with the content and pull-to-
/// refresh starts from the very top.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.onRefresh,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAppBar = title != null || titleWidget != null;
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: hasAppBar
          ? AppBar(
              leading: leading,
              // The title starts where the back arrow ends, and the page's
              // content starts at the gutter: without a leading widget the
              // title takes the gutter itself.
              titleSpacing: leading == null && !_canPop(context)
                  ? AppSpacing.page
                  : 0,
              title: titleWidget ?? Text(title!),
              actions: actions == null
                  ? null
                  : [...actions!, const SizedBox(width: AppSpacing.s8)],
            )
          : null,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: !hasAppBar,
        bottom: bottomNavigationBar == null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > AppSpacing.maxContentWidth
                ? AppSpacing.maxContentWidth
                : constraints.maxWidth;
            Widget content = SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: body,
            );
            if (onRefresh != null) {
              content = RefreshIndicator(
                onRefresh: onRefresh!,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHigh,
                child: content,
              );
            }
            return Align(alignment: Alignment.topCenter, child: content);
          },
        ),
      ),
    );
  }

  static bool _canPop(BuildContext context) =>
      ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
}
