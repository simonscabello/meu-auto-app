import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_switcher_sheet.dart';
import 'package:meu_auto/shared/widgets/app_tab_header.dart';

/// The header of a main tab other than Início: the tab's name, the car it is
/// about, the tab's own actions and the account.
///
/// Início is titled with the car itself. The other three tabs are titled with
/// what they are — Manutenção, Documentos, Histórico — and carry the car on
/// the line under it, always: someone who switched on Início and went to
/// Documentos must see whose IPVA this is, and with one car the line is still
/// the way to add a second.
class VehicleTabHeader extends ConsumerWidget {
  const VehicleTabHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;

  /// The tab's own icon buttons, before the account button.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider).valueOrNull;
    return AppTabHeader(
      title: title,
      contextLabel: selected == null ? null : vehicleContextLabel(selected),
      onContextTap: selected == null
          ? null
          : () => VehicleSwitcherSheet.show(context),
      contextSemanticLabel: selected == null
          ? null
          : 'Veículo: ${selected.shortName}. Trocar veículo',
      actions: [...actions, const ProfileButton()],
    );
  }
}

/// "Prius · QAF5G33" — the name and, when there is one, the plate: the two
/// things that tell the owner's cars apart at a glance.
String vehicleContextLabel(Vehicle vehicle) {
  final plate = vehicle.plate?.trim();
  if (plate == null || plate.isEmpty) return vehicle.headlineName;
  return '${vehicle.headlineName} · $plate';
}

/// The way into the account from any main tab: the owner's initial in a
/// small disc, at the end of the header where their other apps keep it.
///
/// Perfil is not a tab. It is visited a few times a year — a name, a
/// password, the theme, the list of cars — while what happened to the car
/// and what it cost is one of the three things the product exists for.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key, this.onPressed});

  /// Defaults to opening Perfil.
  final VoidCallback? onPressed;

  static const double _disc = 36;

  /// How far the 48dp target reaches past the drawn disc on each side. A
  /// header shifts the button by this much so the disc, not the target,
  /// lines up with the gutter.
  static const double overhang = (AppSpacing.minTapTarget - _disc) / 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final name = auth is AuthLoggedIn ? auth.user.name.trim() : '';
    final initial = name.isEmpty ? null : name.characters.first.toUpperCase();

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
                  width: _disc,
                  height: _disc,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.secondaryContainer,
                  ),
                  child: initial == null
                      ? Icon(
                          Icons.person_outline,
                          size: 20,
                          color: scheme.onSecondaryContainer,
                        )
                      : Text(
                          initial,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
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
