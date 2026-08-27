import 'package:flutter/material.dart';

/// Icon-only control that always exposes a spoken label.
///
/// [tooltip] is the long-press hint; [Semantics] is what a screen reader
/// announces. [excludeSemantics] keeps the two from being read twice.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      ),
    );
  }
}
