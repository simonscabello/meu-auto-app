import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottomNavigationBar,
    this.onRefresh,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasAppBar = title != null || titleWidget != null;
    return Scaffold(
      appBar: hasAppBar
          ? AppBar(title: titleWidget ?? Text(title!), actions: actions)
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
              content = RefreshIndicator(onRefresh: onRefresh!, child: content);
            }
            return Align(alignment: Alignment.topCenter, child: content);
          },
        ),
      ),
    );
  }
}
