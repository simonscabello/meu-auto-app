import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';

/// Makes a surface settle under the finger.
///
/// A tile or a large button shrinks by a couple of percent while pressed and
/// returns when released — the one microinteraction every quick action and
/// hero control shares. It respects "reduce motion", it never fires for a
/// disabled child, and it does not replace the ink: the child keeps its own
/// ripple, this only adds the scale.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _set(bool pressed) {
    if (!_active || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressScale : 1,
        duration: AppMotion.of(context, AppMotion.short),
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
