import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_context_title.dart';
import 'package:meu_auto/shared/widgets/app_wordmark.dart';

/// The top of Início: the mark, the account, and which car this is.
///
/// The car's name is the biggest text on the screen because it is the first
/// question — "which car am I looking at?" — and, with a second car
/// registered, it is also the switcher. The line under it is what tells two
/// of the owner's cars apart: make, year, plate.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.metaParts,
    this.canSwitch = false,
    this.onSwitch,
    this.onAccount,
  });

  /// The nickname, or the model. "Prius", not "Toyota PRIUS 1.8 16V 5p".
  final String name;

  /// Make, year and plate — whichever are known.
  final List<String> metaParts;

  final bool canSwitch;
  final VoidCallback? onSwitch;
  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final meta = metaParts.join('  •  ');

    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 34),
          ),
        ),
        if (canSwitch) ...[
          const SizedBox(width: AppSpacing.s4),
          Icon(Icons.expand_more, size: 28, color: scheme.onSurfaceVariant),
        ],
      ],
    );

    Widget vehicle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        if (meta.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (canSwitch && onSwitch != null) {
      vehicle = Semantics(
        button: true,
        label: 'Trocar veículo. $name',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSwitch,
            borderRadius: AppRadius.borderS,
            highlightColor: tones.overlayPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: vehicle,
            ),
          ),
        ),
      );
    } else {
      vehicle = Semantics(
        header: true,
        label: meta.isEmpty ? name : '$name. $meta',
        excludeSemantics: true,
        child: vehicle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: AppWordmark(size: AppWordmarkSize.small)),
            if (onAccount != null) ProfileButton(onPressed: onAccount),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Align(alignment: Alignment.centerLeft, child: vehicle),
      ],
    );
  }
}
