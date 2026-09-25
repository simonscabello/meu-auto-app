import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_context_title.dart';
import 'package:meu_auto/shared/widgets/app_plate_chip.dart';

/// The top of Início: which car this is, and the account.
///
/// The car's name is the largest text on the screen because it is the first
/// question — "which car am I looking at?" — and it is also the way to change
/// car: the whole block opens the switcher, which lists the cars and offers
/// to add one. The line under it is what tells two cars apart — make and
/// year — with the plate drawn as a plate beside them.
///
/// There is no product mark here. The app's name on its own first screen
/// told the owner nothing they did not know when they opened it; the car is
/// the identity of this screen.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.metaParts,
    this.plate,
    this.canSwitch = false,
    this.onSwitch,
    this.onAccount,
  });

  /// The nickname, or the model. "Prius", not "Toyota PRIUS 1.8 16V 5p".
  final String name;

  /// Make and year — whichever are known. The plate goes in [plate].
  final List<String> metaParts;

  final String? plate;

  /// Whether the account has another car to switch to. The block opens the
  /// switcher either way — with one car it is where the second is added.
  final bool canSwitch;

  final VoidCallback? onSwitch;
  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final meta = metaParts.join(' · ');
    final plateText = plate?.trim();
    final hasPlate = plateText != null && plateText.isNotEmpty;

    Widget vehicle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge,
              ),
            ),
            if (onSwitch != null) ...[
              const SizedBox(width: AppSpacing.s4),
              Icon(Icons.unfold_more, size: 22, color: scheme.onSurfaceVariant),
            ],
          ],
        ),
        if (meta.isNotEmpty || hasPlate) ...[
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            children: [
              if (meta.isNotEmpty)
                Text(
                  meta,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (hasPlate) AppPlateChip(plate: plateText),
            ],
          ),
        ],
      ],
    );

    final spoken = [
      name,
      if (meta.isNotEmpty) meta,
      if (hasPlate) 'placa $plateText',
    ].join('. ');

    if (onSwitch != null) {
      vehicle = Semantics(
        button: true,
        label: canSwitch ? '$spoken. Trocar veículo' : '$spoken. Veículos',
        excludeSemantics: true,
        onTap: onSwitch,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSwitch,
            borderRadius: AppRadius.borderS,
            highlightColor: tones.overlayPressed,
            splashColor: tones.overlayPressed,
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
        label: spoken,
        excludeSemantics: true,
        child: vehicle,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: vehicle),
        ),
        const SizedBox(width: AppSpacing.s8),
        Transform.translate(
          // The disc's 48dp target overhangs the gutter so the drawn circle
          // lines up with the edge of the cards below it.
          offset: const Offset(ProfileButton.overhang, 0),
          child: ProfileButton(onPressed: onAccount),
        ),
      ],
    );
  }
}
