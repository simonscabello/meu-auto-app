import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.status});

  final AppStatus status;

  @override
  Widget build(BuildContext context) {
    final visual = statusColors(status, Theme.of(context).brightness);
    return Chip(
      avatar: Icon(visual.icon, size: 18, color: visual.foreground),
      label: Text(visual.label),
      backgroundColor: visual.background,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: visual.foreground),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
