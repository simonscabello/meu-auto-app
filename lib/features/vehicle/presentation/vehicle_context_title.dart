import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_switcher_sheet.dart';

/// The title of a main tab, and which car it is about.
///
/// Início is titled with the car itself. The other three tabs are titled with
/// what they are — Manutenção, Documentos, Histórico — and, as soon as the
/// account has a second car, the car's name goes under the title as the way to
/// switch. Someone who switched on Início and went to Documentos must see
/// whose IPVA this is.
class VehicleContextTitle extends ConsumerWidget {
  const VehicleContextTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    final vehicles = ref.watch(vehiclesProvider).valueOrNull?.vehicles ?? [];
    final selected = ref.watch(selectedVehicleProvider).valueOrNull;
    if (selected == null || vehicles.length < 2) {
      return Text(title);
    }

    return Semantics(
      button: true,
      label: '$title. ${selected.shortName}. Trocar veículo',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => VehicleSwitcherSheet.show(context),
        borderRadius: AppRadius.borderS,
        highlightColor: tones.overlayPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      selected.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way into the account from any main tab: a small outlined disc with
/// the person glyph, at the end of the bar where the owner's other apps keep
/// it.
///
/// Perfil is not a tab. It is visited a few times a year — a name, a
/// password, the theme, the list of cars — while what happened to the car
/// and what it cost is one of the three things the product exists for.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, this.onPressed});

  /// Defaults to opening Perfil.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = AppTones.of(context);
    return Semantics(
      button: true,
      label: 'Perfil e conta',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Perfil e conta',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed ?? () => context.push(AppRoutes.profile),
            highlightColor: tones.overlayPressed,
            child: SizedBox(
              width: AppSpacing.minTapTarget,
              height: AppSpacing.minTapTarget,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: tones.strokeStrong),
                    color: scheme.surfaceContainerLow,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
