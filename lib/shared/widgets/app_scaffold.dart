import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_background.dart';

/// Every screen's frame: the page background, an optional app bar, the body
/// held to a readable width, and pull-to-refresh when the screen can reload.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.bottomNavigationBar,
    this.onRefresh,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottomNavigationBar;
  final Future<void> Function()? onRefresh;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAppBar = title != null || titleWidget != null;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: hasAppBar
            ? AppBar(
                leading: leading,
                title: titleWidget ?? Text(title!),
                actions: actions == null
                    ? null
                    : [...actions!, const SizedBox(width: AppSpacing.s8)],
              )
            : null,
        bottomNavigationBar: bottomNavigationBar,
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
      ),
    );
  }
}
