import 'package:flutter/material.dart';

/// The owner in a disc: their photo when there is one, their initial when
/// there is not.
///
/// The initial is the default and the fallback, never a placeholder that
/// looks broken: it shows while the photo loads, when the signed URL has
/// expired, and when there is no signal. No screen depends on the photo.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    required this.size,
    this.photoUrl,
  });

  final String name;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? null
        : trimmed.characters.first.toUpperCase();

    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.secondaryContainer,
      ),
      child: initial == null
          ? Icon(
              Icons.person_outline,
              size: size * 0.5,
              color: scheme.onSecondaryContainer,
            )
          : Text(
              initial,
              style:
                  (size >= 56
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.titleSmall)
                      ?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
            ),
    );

    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;

    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          // Decoded at the size it is drawn, not at the upload's 1024px.
          cacheWidth: pixels,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, loadedSync) =>
              frame == null && !loadedSync ? fallback : child,
          errorBuilder: (context, error, stack) => fallback,
        ),
      ),
    );
  }
}
